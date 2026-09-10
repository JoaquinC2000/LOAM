package com.example.trabajo1

import android.Manifest
import android.content.ContentValues
import android.content.pm.PackageManager
import android.media.MediaRecorder
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.view.View
import android.widget.TextView
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat

class GrabacionAudioActivity : AppCompatActivity() {

    private lateinit var textoEstado: TextView
    private lateinit var textoTiempo: TextView
    private lateinit var botonGrabar: View
    private lateinit var indicadorGrabando: View

    private var grabando = false
    private var mediaRecorder: MediaRecorder? = null
    private var uriArchivoActual: Uri? = null

    private val manejadorTiempo = Handler(Looper.getMainLooper())
    private var tiempoInicioGrabacion = 0L
    private val actualizadorTiempo = object : Runnable {
        override fun run() {
            val segundos = (System.currentTimeMillis() - tiempoInicioGrabacion) / 1000
            textoTiempo.text = String.format("%02d:%02d", segundos / 60, segundos % 60)
            manejadorTiempo.postDelayed(this, 1000)
        }
    }

    private val solicitarPermiso = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { concedido ->
        if (!concedido) {
            Toast.makeText(this, "Necesitamos el permiso de micrófono para grabar", Toast.LENGTH_LONG).show()
            finish()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_audio)

        textoEstado = findViewById(R.id.textoEstadoAudio)
        textoTiempo = findViewById(R.id.textoTiempoAudio)
        botonGrabar = findViewById(R.id.botonGrabarAudio)
        indicadorGrabando = findViewById(R.id.indicadorGrabandoAudio)

        findViewById<View>(R.id.botonVolverAudio).setOnClickListener { finish() }
        botonGrabar.setOnClickListener { alternarGrabacion() }

        val tienePermiso = ContextCompat.checkSelfPermission(
            this, Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED
        if (!tienePermiso) solicitarPermiso.launch(Manifest.permission.RECORD_AUDIO)
    }

    private fun alternarGrabacion() {
        if (!grabando) iniciarGrabacion() else detenerGrabacion()
    }

    private fun iniciarGrabacion() {
        val tienePermiso = ContextCompat.checkSelfPermission(
            this, Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED
        if (!tienePermiso) {
            solicitarPermiso.launch(Manifest.permission.RECORD_AUDIO)
            return
        }

        val nombreArchivo = "Trabajo1_audio_${System.currentTimeMillis()}.m4a"
        val valores = ContentValues().apply {
            put(MediaStore.Audio.Media.DISPLAY_NAME, nombreArchivo)
            put(MediaStore.Audio.Media.MIME_TYPE, "audio/mp4")
            put(MediaStore.Audio.Media.RELATIVE_PATH, Environment.DIRECTORY_MUSIC + "/Trabajo1")
        }
        val uri = contentResolver.insert(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, valores)
        if (uri == null) {
            mostrarEstado("No se pudo crear el archivo de audio")
            return
        }
        uriArchivoActual = uri

        try {

            val descriptor = contentResolver.openFileDescriptor(uri, "rw") ?: return

            mediaRecorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                MediaRecorder(this)
            } else {
                @Suppress("DEPRECATION")
                MediaRecorder()
            }

            mediaRecorder?.apply {
                setAudioSource(MediaRecorder.AudioSource.MIC)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setOutputFile(descriptor.fileDescriptor)
                prepare()
                start()
            }
            descriptor.close()

            grabando = true
            textoEstado.visibility = View.GONE
            botonGrabar.setBackgroundResource(R.drawable.bg_boton_detener_circular)

            tiempoInicioGrabacion = System.currentTimeMillis()
            textoTiempo.text = "00:00"
            indicadorGrabando.visibility = View.VISIBLE
            manejadorTiempo.post(actualizadorTiempo)

        } catch (error: Exception) {
            error.printStackTrace()
            mostrarEstado("Error al iniciar la grabación: ${error.message}")
            uriArchivoActual?.let { contentResolver.delete(it, null, null) }
            uriArchivoActual = null
        }
    }

    private fun detenerGrabacion() {
        try {
            mediaRecorder?.apply {
                stop()
                release()
            }
            mostrarEstado("✓ Audio guardado (carpeta Música/Trabajo1)")
        } catch (error: Exception) {
            error.printStackTrace()
            mostrarEstado("Error al guardar el audio")
        }
        mediaRecorder = null

        grabando = false
        botonGrabar.setBackgroundResource(R.drawable.bg_boton_grabar_circular)
        manejadorTiempo.removeCallbacks(actualizadorTiempo)
        indicadorGrabando.visibility = View.GONE
    }

    private fun mostrarEstado(mensaje: String) {
        textoEstado.text = mensaje
        textoEstado.visibility = View.VISIBLE
    }

    override fun onPause() {
        super.onPause()
        if (grabando) detenerGrabacion()
    }
}