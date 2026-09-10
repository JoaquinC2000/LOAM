package com.example.trabajo1

import android.Manifest
import android.content.ContentValues
import android.content.pm.PackageManager
import android.graphics.Outline
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.view.View
import android.view.ViewOutlineProvider
import android.widget.TextView
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.annotation.RequiresPermission
import androidx.appcompat.app.AppCompatActivity
import androidx.camera.core.CameraSelector
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.video.MediaStoreOutputOptions
import androidx.camera.video.Quality
import androidx.camera.video.QualitySelector
import androidx.camera.video.Recorder
import androidx.camera.video.Recording
import androidx.camera.video.VideoCapture
import androidx.camera.video.VideoRecordEvent
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat

class GrabacionVideoActivity : AppCompatActivity() {

    private lateinit var vistaPrevia: PreviewView
    private lateinit var textoTitulo: TextView
    private lateinit var textoEstado: TextView
    private lateinit var botonGrabar: View
    private lateinit var indicadorGrabando: View
    private lateinit var textoTiempoGrabando: TextView

    private var tipoCamara = "frontal"
    private var grabando = false
    private var videoCapture: VideoCapture<Recorder>? = null
    private var grabacionActiva: Recording? = null

    // --- Cronómetro del indicador de grabación ---
    private val manejadorTiempo = Handler(Looper.getMainLooper())
    private var tiempoInicioGrabacion = 0L
    private val actualizadorTiempo = object : Runnable {
        override fun run() {
            val segundosTranscurridos = (System.currentTimeMillis() - tiempoInicioGrabacion) / 1000
            val minutos = segundosTranscurridos / 60
            val segundos = segundosTranscurridos % 60
            textoTiempoGrabando.text = String.format("%02d:%02d", minutos, segundos)
            manejadorTiempo.postDelayed(this, 1000)
        }
    }

    private val solicitarPermisos = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { resultados ->
        if (resultados.values.all { it }) {
            iniciarCamara()
        } else {
            Toast.makeText(this, "Necesitamos permiso de cámara y micrófono para grabar", Toast.LENGTH_LONG).show()
            finish()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_video)

        tipoCamara = intent.getStringExtra("tipoCamara") ?: "frontal"

        vistaPrevia = findViewById(R.id.vistaPreviaCamara)
        textoTitulo = findViewById(R.id.textoTituloGrabacion)
        textoEstado = findViewById(R.id.textoEstadoGrabacion)
        botonGrabar = findViewById(R.id.botonGrabar)
        indicadorGrabando = findViewById(R.id.indicadorGrabando)
        textoTiempoGrabando = findViewById(R.id.textoTiempoGrabando)

        textoTitulo.text = if (tipoCamara == "selfie") "Video selfie" else "Video frontal"

        redondearVistaPrevia()

        findViewById<View>(R.id.botonVolverGrabacion).setOnClickListener { finish() }
        botonGrabar.setOnClickListener { alternarGrabacion() }

        verificarPermisosYArrancar()
    }

    private fun redondearVistaPrevia() {
        val radioEnPx = 24 * resources.displayMetrics.density // 24dp convertidos a píxeles
        vistaPrevia.outlineProvider = object : ViewOutlineProvider() {
            override fun getOutline(view: View, outline: Outline) {
                outline.setRoundRect(0, 0, view.width, view.height, radioEnPx)
            }
        }
        vistaPrevia.clipToOutline = true
        vistaPrevia.implementationMode = PreviewView.ImplementationMode.COMPATIBLE
    }

    private fun verificarPermisosYArrancar() {
        val permisos = arrayOf(Manifest.permission.CAMERA, Manifest.permission.RECORD_AUDIO)
        val faltaAlguno = permisos.any {
            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
        }
        if (faltaAlguno) solicitarPermisos.launch(permisos) else iniciarCamara()
    }

    private fun iniciarCamara() {
        val proveedorFuturo = ProcessCameraProvider.getInstance(this)
        proveedorFuturo.addListener({
            val proveedorCamara = proveedorFuturo.get()

            val vistaPreviaUseCase = Preview.Builder().build().also {
                it.setSurfaceProvider(vistaPrevia.surfaceProvider)
            }

            val grabador = Recorder.Builder()
                .setQualitySelector(QualitySelector.from(Quality.HD))
                .build()
            videoCapture = VideoCapture.withOutput(grabador)

            val selectorCamara = if (tipoCamara == "selfie") {
                CameraSelector.DEFAULT_FRONT_CAMERA
            } else {
                CameraSelector.DEFAULT_BACK_CAMERA
            }

            try {
                proveedorCamara.unbindAll()
                proveedorCamara.bindToLifecycle(this, selectorCamara, vistaPreviaUseCase, videoCapture)
            } catch (error: Exception) {
                error.printStackTrace()
                Toast.makeText(this, "Error al iniciar la cámara: ${error.message}", Toast.LENGTH_LONG).show()
            }
        }, ContextCompat.getMainExecutor(this))
    }

    @RequiresPermission(Manifest.permission.RECORD_AUDIO)
    private fun alternarGrabacion() {
        val capture = videoCapture ?: return

        if (!grabando) {
            val nombreArchivo = "Trabajo1_${tipoCamara}_${System.currentTimeMillis()}.mp4"
            val valores = ContentValues().apply {
                put(MediaStore.Video.Media.DISPLAY_NAME, nombreArchivo)
                put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
            }
            val opcionesSalida = MediaStoreOutputOptions.Builder(
                contentResolver, MediaStore.Video.Media.EXTERNAL_CONTENT_URI
            ).setContentValues(valores).build()

            textoEstado.visibility = View.GONE

            grabacionActiva = capture.output.prepareRecording(this, opcionesSalida)
                .withAudioEnabled()
                .start(ContextCompat.getMainExecutor(this)) { evento ->
                    if (evento is VideoRecordEvent.Finalize) {
                        textoEstado.text = if (!evento.hasError()) {
                            "✓ Video guardado en la galería"
                        } else {
                            "Error al guardar (código ${evento.error})"
                        }
                        textoEstado.visibility = View.VISIBLE
                    }
                }

            grabando = true
            botonGrabar.setBackgroundResource(R.drawable.bg_boton_detener_circular)

            tiempoInicioGrabacion = System.currentTimeMillis()
            textoTiempoGrabando.text = "00:00"
            indicadorGrabando.visibility = View.VISIBLE
            manejadorTiempo.post(actualizadorTiempo)

        } else {
            detenerGrabacion()
        }
    }

    private fun detenerGrabacion() {
        grabacionActiva?.stop()
        grabacionActiva = null
        grabando = false
        botonGrabar.setBackgroundResource(R.drawable.bg_boton_grabar_circular)

        manejadorTiempo.removeCallbacks(actualizadorTiempo)
        indicadorGrabando.visibility = View.GONE
    }

    override fun onPause() {
        super.onPause()
        if (grabando) detenerGrabacion()
    }
}