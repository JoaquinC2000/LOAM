package com.example.trabajo1

import android.content.pm.ActivityInfo
import android.os.Bundle
import android.net.Uri
import android.view.LayoutInflater
import android.view.View
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.MediaController
import android.widget.TextView
import android.widget.Toast
import android.widget.VideoView
import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.AppCompatActivity
import androidx.constraintlayout.widget.ConstraintLayout
import androidx.core.content.ContextCompat

data class PasoAccion(val emoji: String, val titulo: String, val descripcion: String)

data class InfoCatastrofe(
    val titulo: String,
    val nombreImagen: String,
    val nombreVideo: String,
    val colorAccent: Int,
    val pasos: List<PasoAccion>
)

class GuiaActivity : AppCompatActivity() {

    private val catastrofes = mapOf(
        "incendio" to InfoCatastrofe(
            titulo = "incendio",
            nombreImagen = "img_incendio",
            nombreVideo = "incendio",
            colorAccent = R.color.accent_emergencia,
            pasos = listOf(
                PasoAccion("⚠️", "Evacuar Inmediatamente", "No intentes recoger pertenencias. Usá las escaleras, nunca el ascensor."),
                PasoAccion("🚪", "Toca las Puertas Antes de Abrir", "Si la puerta o el pomo están calientes, no abras. Buscá otra salida."),
                PasoAccion("😷", "Cubrí tus Vías Respiratorias", "Usá un paño húmedo si es posible y mantenete agachado bajo el humo."),
                PasoAccion("📞", "Llamá a Bomberos", "Una vez afuera y a salvo, no vuelvas a entrar por ningún motivo.")
            )
        ),
        "inundacion" to InfoCatastrofe(
            titulo = "inundación",
            nombreImagen = "img_inundacion",
            nombreVideo = "inundacion",
            colorAccent = R.color.accent_ubicacion,
            pasos = listOf(
                PasoAccion("⬆️", "Buscá Altura", "Subí a un lugar alto dentro de tu vivienda, lejos del nivel del agua."),
                PasoAccion("🚫", "No Cruces el Agua", "Ni a pie ni en auto: las calles inundadas pueden ocultar peligros."),
                PasoAccion("⚡", "Cortá la Electricidad", "Si el agua puede llegar a los tomacorrientes, desconectá todo."),
                PasoAccion("🎒", "Protegé tus Documentos", "Guardalos en una bolsa impermeable junto a lo esencial.")
            )
        ),
        "terremoto" to InfoCatastrofe(
            titulo = "terremoto",
            nombreImagen = "img_terremoto",
            nombreVideo = "terremoto",
            colorAccent = R.color.accent_guia,
            pasos = listOf(
                PasoAccion("🛡️", "Protegete Ya", "Agachate, cubrite la cabeza y sostenete de un mueble firme."),
                PasoAccion("🪟", "Alejate de Peligros", "Alejate de ventanas y objetos que puedan caer sobre vos."),
                PasoAccion("🚫", "No Uses el Ascensor", "Ni durante ni inmediatamente después del sismo."),
                PasoAccion("🚶", "Evacuá con Cuidado", "Una vez que termine, salí del edificio si es seguro hacerlo.")
            )
        )
    )

    private lateinit var imagenCatastrofe: ImageView
    private lateinit var contenedorVideoPlaceholder: LinearLayout
    private lateinit var videoCatastrofe: VideoView
    private lateinit var contenedorPasos: LinearLayout
    private lateinit var contenedorTarjetaVideo: ConstraintLayout
    private lateinit var botonPantallaCompleta: ImageView
    private lateinit var contenedorVideoFullscreen: FrameLayout
    private lateinit var botonCerrarFullscreenGuia: ImageView

    private lateinit var tabIncendio: LinearLayout
    private lateinit var tabInundacion: LinearLayout
    private lateinit var tabTerremoto: LinearLayout
    private lateinit var textoTabIncendio: TextView
    private lateinit var textoTabInundacion: TextView
    private lateinit var textoTabTerremoto: TextView
    private lateinit var indicadorTabIncendio: View
    private lateinit var indicadorTabInundacion: View
    private lateinit var indicadorTabTerremoto: View

    private var tipoActual = "incendio"
    private var estaEnFullscreen = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_guia)

        findViewById<View>(R.id.botonVolverGuia).setOnClickListener { finish() }

        imagenCatastrofe = findViewById(R.id.imagenCatastrofe)
        contenedorVideoPlaceholder = findViewById(R.id.contenedorVideoPlaceholder)
        videoCatastrofe = findViewById(R.id.videoCatastrofe)
        contenedorPasos = findViewById(R.id.contenedorPasos)
        contenedorTarjetaVideo = findViewById(R.id.contenedorTarjetaVideo)
        botonPantallaCompleta = findViewById(R.id.botonPantallaCompleta)
        contenedorVideoFullscreen = findViewById(R.id.contenedorVideoFullscreen)
        botonCerrarFullscreenGuia = findViewById(R.id.botonCerrarFullscreenGuia)

        tabIncendio = findViewById(R.id.tabIncendio)
        tabInundacion = findViewById(R.id.tabInundacion)
        tabTerremoto = findViewById(R.id.tabTerremoto)
        textoTabIncendio = findViewById(R.id.textoTabIncendio)
        textoTabInundacion = findViewById(R.id.textoTabInundacion)
        textoTabTerremoto = findViewById(R.id.textoTabTerremoto)
        indicadorTabIncendio = findViewById(R.id.indicadorTabIncendio)
        indicadorTabInundacion = findViewById(R.id.indicadorTabInundacion)
        indicadorTabTerremoto = findViewById(R.id.indicadorTabTerremoto)

        tabIncendio.setOnClickListener { mostrarCatastrofe("incendio") }
        tabInundacion.setOnClickListener { mostrarCatastrofe("inundacion") }
        tabTerremoto.setOnClickListener { mostrarCatastrofe("terremoto") }

        contenedorVideoPlaceholder.setOnClickListener { reproducirVideo() }
        botonPantallaCompleta.setOnClickListener { abrirPantallaCompleta() }
        botonCerrarFullscreenGuia.setOnClickListener { cerrarPantallaCompleta() }

        // Si el usuario aprieta "atrás" estando en pantalla completa, que
        // salga del fullscreen primero, en vez de cerrar toda la pantalla.
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                if (estaEnFullscreen) {
                    cerrarPantallaCompleta()
                } else {
                    isEnabled = false
                    onBackPressedDispatcher.onBackPressed()
                }
            }
        })

        mostrarCatastrofe("incendio")
    }

    private fun mostrarCatastrofe(tipo: String) {
        if (estaEnFullscreen) cerrarPantallaCompleta()
        detenerVideoSiEstaSonando()
        tipoActual = tipo
        val info = catastrofes[tipo] ?: return

        actualizarPestanas(tipo)

        val idImagen = resources.getIdentifier(info.nombreImagen, "drawable", packageName)
        if (idImagen != 0) imagenCatastrofe.setImageResource(idImagen)

        contenedorPasos.removeAllViews()
        val fondosPorIndice = listOf(R.drawable.bg_tarjeta_menu_roja, R.drawable.bg_tarjeta_menu_naranja, R.drawable.bg_tarjeta_menu_azul)
        val coloresPorIndice = listOf(R.color.accent_emergencia, R.color.accent_guia, R.color.accent_ubicacion)

        info.pasos.forEachIndexed { index, paso ->
            val vista = LayoutInflater.from(this).inflate(R.layout.item_paso_accion, contenedorPasos, false)
            vista.setBackgroundResource(fondosPorIndice[index % fondosPorIndice.size])

            val icono = vista.findViewById<TextView>(R.id.iconoPaso)
            icono.text = paso.emoji
            icono.backgroundTintList = ContextCompat.getColorStateList(this, coloresPorIndice[index % coloresPorIndice.size])

            vista.findViewById<TextView>(R.id.tituloPaso).text = paso.titulo
            vista.findViewById<TextView>(R.id.descripcionPaso).text = paso.descripcion

            contenedorPasos.addView(vista)
        }
    }

    private fun actualizarPestanas(tipoSeleccionado: String) {
        val gris = ContextCompat.getColor(this, R.color.texto_secundario)
        val transparente = ContextCompat.getColor(this, R.color.tarjeta_fondo)

        textoTabIncendio.setTextColor(gris)
        textoTabInundacion.setTextColor(gris)
        textoTabTerremoto.setTextColor(gris)
        indicadorTabIncendio.setBackgroundColor(transparente)
        indicadorTabInundacion.setBackgroundColor(transparente)
        indicadorTabTerremoto.setBackgroundColor(transparente)

        val info = catastrofes[tipoSeleccionado] ?: return
        val colorActivo = ContextCompat.getColor(this, info.colorAccent)
        when (tipoSeleccionado) {
            "incendio" -> {
                textoTabIncendio.setTextColor(colorActivo)
                indicadorTabIncendio.setBackgroundColor(colorActivo)
            }
            "inundacion" -> {
                textoTabInundacion.setTextColor(colorActivo)
                indicadorTabInundacion.setBackgroundColor(colorActivo)
            }
            "terremoto" -> {
                textoTabTerremoto.setTextColor(colorActivo)
                indicadorTabTerremoto.setBackgroundColor(colorActivo)
            }
        }
    }

    private fun reproducirVideo() {
        val info = catastrofes[tipoActual] ?: return
        val idVideo = resources.getIdentifier(info.nombreVideo, "raw", packageName)
        if (idVideo == 0) {
            Toast.makeText(this, "Todavía no cargaste el video de ${info.titulo}", Toast.LENGTH_SHORT).show()
            return
        }

        val uriVideo = Uri.parse("android.resource://$packageName/$idVideo")
        val controlador = MediaController(this)
        controlador.setAnchorView(videoCatastrofe)
        videoCatastrofe.setMediaController(controlador)
        videoCatastrofe.setVideoURI(uriVideo)
        videoCatastrofe.setOnPreparedListener { it.start() }

        contenedorVideoPlaceholder.visibility = View.GONE
        videoCatastrofe.visibility = View.VISIBLE
        botonPantallaCompleta.visibility = View.VISIBLE
    }

    // Acá está el corazón del pedido: NO se crea ningún reproductor nuevo,
    // se toma el VideoView que ya está reproduciendo y se lo "muda" de
    // contenedor. Como es la MISMA instancia, la reproducción sigue sin
    // cortarse (a lo sumo un parpadeo de un frame mientras se reacomoda
    // en la nueva ubicación).
    private fun abrirPantallaCompleta() {
        if (estaEnFullscreen) return
        estaEnFullscreen = true

        contenedorTarjetaVideo.removeView(videoCatastrofe)
        val paramsFullscreen = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        )
        contenedorVideoFullscreen.addView(videoCatastrofe, 0, paramsFullscreen)

        contenedorVideoFullscreen.visibility = View.VISIBLE
        requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
        ocultarBarrasDelSistema()
    }

    private fun cerrarPantallaCompleta() {
        if (!estaEnFullscreen) return
        estaEnFullscreen = false

        contenedorVideoFullscreen.removeView(videoCatastrofe)
        // Reconstruimos las MISMAS restricciones que tiene en el XML
        // original (relación 16:9, pegado a los 3 bordes) para que vuelva
        // a verse igual que antes al moverlo de nuevo a su lugar.
        val paramsInline = ConstraintLayout.LayoutParams(0, 0).apply {
            dimensionRatio = "H,16:9"
            startToStart = ConstraintLayout.LayoutParams.PARENT_ID
            endToEnd = ConstraintLayout.LayoutParams.PARENT_ID
            topToTop = ConstraintLayout.LayoutParams.PARENT_ID
        }
        contenedorTarjetaVideo.addView(videoCatastrofe, 0, paramsInline)

        contenedorVideoFullscreen.visibility = View.GONE
        requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
        mostrarBarrasDelSistema()
    }

    @Suppress("DEPRECATION")
    private fun ocultarBarrasDelSistema() {
        window.decorView.systemUiVisibility = (
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                        or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                        or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                        or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                        or View.SYSTEM_UI_FLAG_FULLSCREEN
                        or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                )
    }

    @Suppress("DEPRECATION")
    private fun mostrarBarrasDelSistema() {
        window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_VISIBLE
    }

    private fun detenerVideoSiEstaSonando() {
        if (estaEnFullscreen) cerrarPantallaCompleta()
        if (videoCatastrofe.isPlaying) {
            videoCatastrofe.stopPlayback()
        }
        videoCatastrofe.visibility = View.GONE
        contenedorVideoPlaceholder.visibility = View.VISIBLE
        botonPantallaCompleta.visibility = View.GONE
    }

    override fun onPause() {
        super.onPause()
        detenerVideoSiEstaSonando()
    }
}