package com.example.trabajo1

import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL

data class Emisora(val nombre: String, val url: String, val bitrate: Int = 0)

class RadioActivity : AppCompatActivity() {

    private lateinit var progreso: ProgressBar
    private lateinit var textoEstacion: TextView
    private lateinit var textoEstado: TextView
    private lateinit var botonPower: ImageView
    private lateinit var contenedorLista: LinearLayout

    private var emisoras: List<Emisora> = emptyList()
    private var indiceActual = 0
    private var reproductor: MediaPlayer? = null
    private var estaSonando = false
    private var estaConectando = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_radio)

        findViewById<View>(R.id.botonVolverRadio).setOnClickListener { finish() }

        progreso = findViewById(R.id.progresoRadio)
        textoEstacion = findViewById(R.id.textoNombreEstacion)
        textoEstado = findViewById(R.id.textoEstadoRadio)
        botonPower = findViewById(R.id.botonPowerRadio)
        contenedorLista = findViewById(R.id.contenedorListaEmisoras)

        botonPower.setOnClickListener { alternarReproduccion() }
        findViewById<View>(R.id.botonStopRadio).setOnClickListener { detenerReproduccion() }
        findViewById<View>(R.id.botonEmisoraAnterior).setOnClickListener { cambiarEmisora(indiceActual - 1) }
        findViewById<View>(R.id.botonEmisoraSiguiente).setOnClickListener { cambiarEmisora(indiceActual + 1) }

        cargarEmisoras()
    }

    private fun cargarEmisoras() {
        lifecycleScope.launch {
            try {
                val respuestaJson = withContext(Dispatchers.IO) {
                    val urlApi = URL("https://de1.api.radio-browser.info/json/stations/bycountry/argentina?hidebroken=true&order=clickcount&reverse=true&limit=15")
                    val conexion = (urlApi.openConnection() as HttpURLConnection).apply {
                        requestMethod = "GET"
                        connectTimeout = 8000
                        readTimeout = 8000
                        setRequestProperty("User-Agent", "Trabajo1SafeguardApp/1.0")
                    }
                    val lector = BufferedReader(InputStreamReader(conexion.inputStream))
                    val respuesta = StringBuilder()
                    var linea: String?
                    while (lector.readLine().also { linea = it } != null) {
                        respuesta.append(linea)
                    }
                    lector.close()
                    conexion.disconnect()
                    respuesta.toString()
                }

                val arrayJson = JSONArray(respuestaJson)
                val lista = mutableListOf<Emisora>()
                for (i in 0 until arrayJson.length()) {
                    val obj = arrayJson.getJSONObject(i)
                    val nombre = obj.optString("name")
                    val url = obj.optString("url_resolved")
                    val bitrate = obj.optInt("bitrate", 0)
                    if (nombre.isNotBlank() && url.isNotBlank()) {
                        lista.add(Emisora(nombre, url, bitrate))
                    }
                }

                emisoras = lista
                progreso.visibility = View.GONE

                if (emisoras.isEmpty()) {
                    textoEstacion.text = "No se encontraron emisoras"
                } else {
                    armarListaEmisoras()
                    mostrarEmisoraActual()
                }

            } catch (error: Exception) {
                error.printStackTrace()
                progreso.visibility = View.GONE
                textoEstacion.text = "Sin conexión"
                textoEstado.text = "No se pudieron cargar las emisoras"
            }
        }
    }

    private fun armarListaEmisoras() {
        contenedorLista.removeAllViews()
        emisoras.forEachIndexed { index, emisora ->
            val fila = LayoutInflater.from(this).inflate(R.layout.item_fila_emisora, contenedorLista, false)

            fila.findViewById<TextView>(R.id.textoNombreFila).text = emisora.nombre
            fila.findViewById<TextView>(R.id.textoDetalleFila).text =
                if (emisora.bitrate > 0) "${emisora.bitrate} kbps" else "Emisora online"

            fila.setOnClickListener { cambiarEmisora(index) }
            contenedorLista.addView(fila)
        }
        resaltarSeleccionEnLista()
    }

    private fun resaltarSeleccionEnLista() {
        for (i in 0 until contenedorLista.childCount) {
            val fila = contenedorLista.getChildAt(i)
            val esActual = i == indiceActual
            fila.setBackgroundResource(if (esActual) R.drawable.bg_tarjeta_menu_violeta else R.drawable.bg_tarjeta_clima)
            fila.findViewById<TextView>(R.id.iconoSonandoFila).visibility =
                if (esActual && estaSonando) View.VISIBLE else View.GONE
        }
    }

    private fun mostrarEmisoraActual() {
        val emisora = emisoras.getOrNull(indiceActual) ?: return
        textoEstacion.text = emisora.nombre
        textoEstado.text = if (estaSonando) "Reproduciendo..." else "Presioná ▶ para escuchar"
        resaltarSeleccionEnLista()
    }

    private fun cambiarEmisora(nuevoIndice: Int) {
        if (emisoras.isEmpty()) return
        indiceActual = ((nuevoIndice % emisoras.size) + emisoras.size) % emisoras.size

        val estabaSonando = estaSonando
        detenerReproduccion()
        mostrarEmisoraActual()
        if (estabaSonando) iniciarReproduccion()
    }

    private fun alternarReproduccion() {
        if (emisoras.isEmpty() || estaConectando) return
        if (estaSonando) detenerReproduccion() else iniciarReproduccion()
    }

    private fun iniciarReproduccion() {
        if (estaConectando) return
        val emisora = emisoras.getOrNull(indiceActual) ?: return

        liberarReproductorActual()

        estaConectando = true
        botonPower.isEnabled = false
        textoEstado.text = "Conectando..."

        try {
            reproductor = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )
                setDataSource(emisora.url)
                setOnPreparedListener {
                    estaConectando = false
                    botonPower.isEnabled = true
                    it.start()
                    estaSonando = true
                    botonPower.setImageResource(android.R.drawable.ic_media_pause)
                    textoEstado.text = "Reproduciendo..."
                    resaltarSeleccionEnLista()
                }
                setOnErrorListener { _, _, _ ->
                    Toast.makeText(this@RadioActivity, "No se pudo conectar con esta emisora", Toast.LENGTH_SHORT).show()
                    detenerReproduccion()
                    true
                }
                prepareAsync()
            }
        } catch (error: Exception) {
            error.printStackTrace()
            estaConectando = false
            botonPower.isEnabled = true
            textoEstado.text = "Error al conectar"
        }
    }

    private fun liberarReproductorActual() {
        try {
            reproductor?.apply {
                setOnPreparedListener(null)
                setOnErrorListener(null)
                stop()
                release()
            }
        } catch (error: Exception) {
            error.printStackTrace()
        }
        reproductor = null
    }

    private fun detenerReproduccion() {
        liberarReproductorActual()
        estaConectando = false
        estaSonando = false
        botonPower.isEnabled = true
        botonPower.setImageResource(android.R.drawable.ic_media_play)
        if (emisoras.isNotEmpty()) textoEstado.text = "Presioná ▶ para escuchar"
        resaltarSeleccionEnLista()
    }

    override fun onPause() {
        super.onPause()
        detenerReproduccion()
    }
}