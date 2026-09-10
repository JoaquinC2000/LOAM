package com.example.trabajo1

import android.app.AlertDialog
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.camera2.CameraAccessException
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.location.Geocoder
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.BatteryManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.speech.RecognizerIntent
import android.view.View
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.constraintlayout.widget.ConstraintLayout
import androidx.core.content.ContextCompat
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

class MainActivity : AppCompatActivity() {

    // Linterna
    private var estaLinternaEncendida: Boolean = false
    private lateinit var administradorCamara: CameraManager
    private var idCamaraConFlash: String? = null
    private lateinit var botonLinterna: ConstraintLayout
    private lateinit var textoEstadoLinterna: TextView
    private lateinit var iconoLinterna: ImageView

    // Clima
    private lateinit var textoTemperatura: TextView
    private lateinit var textoDescripcionClima: TextView
    private lateinit var iconoClima: TextView

    // Batería
    private lateinit var textoPorcentajeBateria: TextView
    private lateinit var textoTiempoRestanteBateria: TextView
    private lateinit var iconoBateria: TextView

    // Botones de navegación
    private lateinit var botonEmergencias: LinearLayout  // Emergencias
    private lateinit var botonUbicacion: LinearLayout  // Mapa
    private lateinit var botonMultimedia: LinearLayout  //Grabacion
    private lateinit var botonChat: LinearLayout  // Chat con asistencia
    private lateinit var botonGuia: LinearLayout  // Guia
    private lateinit var botonComandoVoz: ImageView  // Comando de voz


    // Alerta de catástrofe
    private lateinit var overlayAlerta: View
    private var alertaActivaAhora = false
    private var reproductorSonido: MediaPlayer? = null
    private var brilloOriginal: Float = -1f
    private val manejadorFlash = Handler(Looper.getMainLooper())
    private val coloresFlash = listOf(R.color.accent_emergencia, R.color.white, R.color.black, R.color.accent_emergencia)
    private var indiceColorFlash = 0
    private var estadoFlashFisicoAlerta = false
    private val efectoFlash = object : Runnable {
        override fun run() {
            overlayAlerta.setBackgroundColor(ContextCompat.getColor(this@MainActivity, coloresFlash[indiceColorFlash]))
            indiceColorFlash = (indiceColorFlash + 1) % coloresFlash.size

            if (idCamaraConFlash != null) {
                try {
                    estadoFlashFisicoAlerta = !estadoFlashFisicoAlerta
                    administradorCamara.setTorchMode(idCamaraConFlash!!, estadoFlashFisicoAlerta)
                } catch (error: Exception) { /* ignoramos, no es crítico */ }
            }

            if (alertaActivaAhora) manejadorFlash.postDelayed(this, 120)
        }
    }

    // Batería: Se actualiza solo
    private val receptorBateria = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            actualizarUiBateria(intent)
        }
    }

    private val lanzadorReconocimientoVoz = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) { resultado ->
        if (resultado.resultCode == RESULT_OK) {
            val texto = resultado.data
                ?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
                ?.firstOrNull()
                ?.lowercase(Locale.getDefault())
            if (texto != null) {
                procesarComandoDeVoz(quitarTildes(texto))
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        botonLinterna = findViewById(R.id.btnFlashlight)
        textoEstadoLinterna = findViewById(R.id.tvTorchStatus)
        iconoLinterna = findViewById(R.id.ivTorchIcon)

        textoTemperatura = findViewById(R.id.textoTemperatura)
        textoDescripcionClima = findViewById(R.id.textoDescripcionClima)
        iconoClima = findViewById(R.id.iconoClima)

        textoPorcentajeBateria = findViewById(R.id.textoPorcentajeBateria)
        textoTiempoRestanteBateria = findViewById(R.id.textoTiempoRestanteBateria)
        iconoBateria = findViewById(R.id.iconoBateria)

        botonEmergencias = findViewById(R.id.btnNumerosEmergencia)

        botonUbicacion = findViewById(R.id.btnDondeEstoy)
        botonMultimedia = findViewById(R.id.btnMultimedia)
        botonChat = findViewById(R.id.btnChatAsistencia)
        botonGuia = findViewById(R.id.btnGuiaAccion)
        botonComandoVoz = findViewById(R.id.btnComandoVoz)
        botonComandoVoz.setOnLongClickListener {
            activarAlertaCatastrofe("Terremoto", -35.6566, -63.7568, System.currentTimeMillis())
            true
        }
        overlayAlerta = findViewById(R.id.overlayAlertaCatastrofe)

        configurarServicioLinterna()
        obtenerDatosDelClima()

        botonLinterna.setOnClickListener { cambiarEstadoLinterna() }
        botonEmergencias.setOnClickListener {
            startActivity(Intent(this, EmergenciaActivity::class.java))
        }
        botonUbicacion.setOnClickListener {
            startActivity(Intent(this, UbicacionActivity::class.java))
        }
        botonMultimedia.setOnClickListener {
            startActivity(Intent(this, MultimediaActivity::class.java))
        }
        botonChat.setOnClickListener {
            startActivity(Intent(this, ChatActivity::class.java))
        }
        botonGuia.setOnClickListener {
            startActivity(Intent(this, GuiaActivity::class.java))
        }
        botonComandoVoz.setOnClickListener {
            iniciarReconocimientoDeVoz()
        }

        registerReceiver(receptorBateria, IntentFilter(Intent.ACTION_BATTERY_CHANGED)) // Actualiza la bateria automaticamente

        revisarIntentDeAlerta(intent)
    }

    // Se dispara cuando la Activity YA existe (gracias a singleTask) y
    // alguien la trae al frente de nuevo con un Intent nuevo — es lo que
    // permite reaccionar a la alerta sin importar en qué pantalla estabas.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        revisarIntentDeAlerta(intent)
    }

    private fun revisarIntentDeAlerta(intentRecibido: Intent) {
        val tipo = intentRecibido.getStringExtra("alertaTipo") ?: return
        val lat = intentRecibido.getDoubleExtra("alertaLat", 0.0)
        val lon = intentRecibido.getDoubleExtra("alertaLon", 0.0)
        val fechaHoraMillis = intentRecibido.getLongExtra("alertaFechaHoraMillis", 0L)

        activarAlertaCatastrofe(tipo, lat, lon, fechaHoraMillis)

        // Limpiamos el extra para que no se repita solo si la Activity se
        // recrea (ej: rotar pantalla) mientras el mismo Intent sigue activo.
        intentRecibido.removeExtra("alertaTipo")
    }

    // =========================================================================
    // ALERTA DE CATÁSTROFE
    // =========================================================================
    private fun activarAlertaCatastrofe(tipo: String, latitud: Double, longitud: Double, fechaHoraMillis: Long) {
        alertaActivaAhora = true
        subirBrilloAlMaximo()
        vibrarContinuo()
        reproducirSonidoAlarma()
        iniciarEfectoLuces()

        lifecycleScope.launch {
            val direccion = obtenerDireccionDesdeCoordenadas(latitud, longitud)
            val textoTiempo = formatearFechaEvento(fechaHoraMillis)
            val mensaje = "Tipo: $tipo\n\n📍 Lugar: $direccion\n\n🕐 $textoTiempo\n\nRevisá la Guía de Acción para saber cómo proceder."

            AlertDialog.Builder(this@MainActivity)
                .setTitle("⚠️ ALERTA DE CATÁSTROFE")
                .setMessage(mensaje)
                .setCancelable(false)
                .setPositiveButton("Entendido") { _, _ -> detenerAlertaCatastrofe() }
                .show()
        }
    }

    private fun detenerAlertaCatastrofe() {
        alertaActivaAhora = false
        detenerVibracion()
        detenerSonidoAlarma()
        detenerEfectoLuces()
        restaurarBrilloOriginal()
    }

    private fun subirBrilloAlMaximo() {
        val parametros = window.attributes
        brilloOriginal = parametros.screenBrightness
        parametros.screenBrightness = 1.0f
        window.attributes = parametros
    }

    private fun restaurarBrilloOriginal() {
        val parametros = window.attributes
        parametros.screenBrightness = brilloOriginal
        window.attributes = parametros
    }

    @Suppress("DEPRECATION")
    private suspend fun obtenerDireccionDesdeCoordenadas(lat: Double, lon: Double): String {
        return withContext(Dispatchers.IO) {
            try {
                val geocoder = Geocoder(this@MainActivity, Locale.getDefault())
                val resultados = geocoder.getFromLocation(lat, lon, 1)
                resultados?.firstOrNull()?.getAddressLine(0) ?: "Ubicación desconocida"
            } catch (error: Exception) {
                "No se pudo determinar el lugar (¿sin conexión?)"
            }
        }
    }

    private fun formatearFechaEvento(fechaHoraMillis: Long): String {
        val ahora = System.currentTimeMillis()
        val formato = SimpleDateFormat("HH:mm", Locale.getDefault())
        val horaTexto = formato.format(Date(fechaHoraMillis))
        val minutosDiferencia = (fechaHoraMillis - ahora) / 60000

        return when {
            minutosDiferencia > 1 -> "Se aproxima a las $horaTexto (en aproximadamente $minutosDiferencia minutos)"
            minutosDiferencia < -1 -> "Ocurrió a las $horaTexto"
            else -> "Está ocurriendo ahora mismo ($horaTexto)"
        }
    }

    private fun vibrarContinuo() {
        val patron = longArrayOf(0, 500, 300, 500, 300)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            vibratorManager.defaultVibrator.vibrate(VibrationEffect.createWaveform(patron, 0))
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            @Suppress("DEPRECATION")
            val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            vibrator.vibrate(VibrationEffect.createWaveform(patron, 0))
        } else {
            @Suppress("DEPRECATION")
            val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            @Suppress("DEPRECATION")
            vibrator.vibrate(patron, 0)
        }
    }

    private fun detenerVibracion() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            vibratorManager.defaultVibrator.cancel()
        } else {
            @Suppress("DEPRECATION")
            val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            vibrator.cancel()
        }
    }

    private fun reproducirSonidoAlarma() {
        try {
            val idSonidoPropio = resources.getIdentifier("alarma_catastrofe", "raw", packageName)

            reproductorSonido = if (idSonidoPropio != 0) {
                MediaPlayer.create(this, idSonidoPropio)
            } else {
                val uriSonido = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                MediaPlayer().apply {
                    setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_ALARM)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build()
                    )
                    setDataSource(this@MainActivity, uriSonido)
                    prepare()
                }
            }
            reproductorSonido?.isLooping = true
            reproductorSonido?.start()
        } catch (error: Exception) {
            error.printStackTrace()
        }
    }

    private fun detenerSonidoAlarma() {
        try {
            reproductorSonido?.apply {
                stop()
                release()
            }
        } catch (error: Exception) {
            error.printStackTrace()
        }
        reproductorSonido = null
    }

    private fun iniciarEfectoLuces() {
        overlayAlerta.visibility = View.VISIBLE
        overlayAlerta.alpha = 0.65f
        indiceColorFlash = 0
        manejadorFlash.post(efectoFlash)
    }

    private fun detenerEfectoLuces() {
        manejadorFlash.removeCallbacks(efectoFlash)
        overlayAlerta.visibility = View.GONE
        if (idCamaraConFlash != null) {
            try {
                administradorCamara.setTorchMode(idCamaraConFlash!!, estaLinternaEncendida)
            } catch (error: Exception) { /* ignoramos */ }
        }
    }

    // =========================================================================
    // COMANDO POR VOZ
    // =========================================================================

    private fun iniciarReconocimientoDeVoz() {
        // Escucha y devuelve el texto transcripto
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "es-AR")
            putExtra(RecognizerIntent.EXTRA_PROMPT, "Decí un comando: linterna, emergencias, ubicación, brújula, radio, multimedia, chat o guía")
        }
        // Verifica si el dispositivo tiene una app de reconocimiento de voz instalada
        if (intent.resolveActivity(packageManager) != null) {
            lanzadorReconocimientoVoz.launch(intent)
        } else {
            Toast.makeText(this, "No hay ninguna app de reconocimiento de voz disponible en este dispositivo", Toast.LENGTH_LONG).show()
        }
    }

    private fun procesarComandoDeVoz(texto: String) {
        when {
            texto.contains("apagar linterna") || texto.contains("apagar la linterna") -> {
                if (estaLinternaEncendida) cambiarEstadoLinterna()
                Toast.makeText(this, "Comando: apagar linterna", Toast.LENGTH_SHORT).show()
            }
            texto.contains("prender linterna") || texto.contains("encender linterna") -> {
                if (!estaLinternaEncendida) cambiarEstadoLinterna()
                Toast.makeText(this, "Comando: prender linterna", Toast.LENGTH_SHORT).show()
            }
            texto.contains("linterna") -> {
                cambiarEstadoLinterna()
                Toast.makeText(this, "Comando: linterna", Toast.LENGTH_SHORT).show()
            }
            texto.contains("camara frontal") || texto.contains("video frontal") -> {
                val intent = Intent(this, GrabacionVideoActivity::class.java)
                intent.putExtra("tipoCamara", "frontal")
                startActivity(intent)
            }
            texto.contains("camara selfie") || texto.contains("video selfie") -> {
                val intent = Intent(this, GrabacionVideoActivity::class.java)
                intent.putExtra("tipoCamara", "selfie")
                startActivity(intent)
            }
            texto.contains("grabar audio") || texto.contains("audio memo") -> {
                startActivity(Intent(this, GrabacionAudioActivity::class.java))
            }
            texto.contains("multimedia") || texto.contains("video") || texto.contains("audio") -> {
                startActivity(Intent(this, MultimediaActivity::class.java))
            }
            texto.contains("emergencia") -> {
                startActivity(Intent(this, EmergenciaActivity::class.java))
            }
            texto.contains("ubicacion") || texto.contains("donde estoy") || texto.contains("mapa") -> {
                startActivity(Intent(this, UbicacionActivity::class.java))
            }
            texto.contains("chat") || texto.contains("asistencia") -> {
                startActivity(Intent(this, ChatActivity::class.java))
            }
            texto.contains("guia") || texto.contains("consejo") -> {
                startActivity(Intent(this, GuiaActivity::class.java))
            }
            texto.contains("brujula") -> {
                val intent = Intent(this, UbicacionActivity::class.java)
                intent.putExtra("abrirBrujula", true)
                startActivity(intent)
            }
            texto.contains("radio") -> {
                startActivity(Intent(this, RadioActivity::class.java))
            }
            else -> {
                Toast.makeText(this, "No entendí el comando: \"$texto\"", Toast.LENGTH_LONG).show()
            }
        }
    }

    private fun quitarTildes(texto: String): String {
        val normalizado = java.text.Normalizer.normalize(texto, java.text.Normalizer.Form.NFD)
        return normalizado.replace(Regex("\\p{Mn}"), "")
    }

    // =========================================================================
    // CLIMA
    // =========================================================================
    private fun obtenerDatosDelClima() {
        lifecycleScope.launch {
            try {
                val respuestaJson = withContext(Dispatchers.IO) {
                    val urlApi = URL("https://api.open-meteo.com/v1/forecast?latitude=-35.6566&longitude=-63.7568&current=temperature_2m,weather_code")
                    val conexion = (urlApi.openConnection() as HttpURLConnection).apply {
                        requestMethod = "GET"
                        connectTimeout = 8000
                        readTimeout = 8000
                        setRequestProperty("User-Agent", "SafeguardApp/1.0")
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

                val jsonCompleto = JSONObject(respuestaJson)
                val datosActuales = jsonCompleto.getJSONObject("current")
                val temperaturaObtenida = datosActuales.getDouble("temperature_2m").toInt()
                val codigoClima = datosActuales.getInt("weather_code")

                textoTemperatura.text = "${temperaturaObtenida}°C"
                textoDescripcionClima.text = interpretarCodigoClima(codigoClima)
                iconoClima.text = iconoParaClima(codigoClima)

            } catch (error: Exception) {
                error.printStackTrace()
                textoDescripcionClima.text = "Sin conexión"
            }
        }
    }

    private fun interpretarCodigoClima(codigo: Int): String {
        return when (codigo) {
            0 -> "Despejado"
            1, 2, 3 -> "Parcialmente nublado"
            45, 48 -> "Niebla"
            51, 53, 55 -> "Llovizna"
            61, 63, 65 -> "Lluvia"
            71, 73, 75 -> "Nieve"
            80, 81, 82 -> "Chubascos"
            95, 96, 99 -> "Tormenta eléctrica"
            else -> "Estable"
        }
    }

    private fun iconoParaClima(codigo: Int): String {
        return when (codigo) {
            0 -> "☀️"
            1, 2, 3 -> "⛅"
            45, 48 -> "🌫️"
            51, 53, 55 -> "🌦️"
            61, 63, 65 -> "🌧️"
            71, 73, 75 -> "❄️"
            80, 81, 82 -> "🌦️"
            95, 96, 99 -> "⛈️"
            else -> "🌡️"
        }
    }

    // =========================================================================
    // BATERÍA
    // =========================================================================
    private fun actualizarUiBateria(intent: Intent) {
        val nivel = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
        val escala = intent.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
        val porcentaje = if (nivel >= 0 && escala > 0) (nivel * 100 / escala) else -1

        if (porcentaje < 0) {
            textoPorcentajeBateria.text = "--%"
            textoTiempoRestanteBateria.text = "No disponible"
            return
        }

        textoPorcentajeBateria.text = "$porcentaje%"
        actualizarIconoBateria(porcentaje)

        val enchufado = intent.getIntExtra(BatteryManager.EXTRA_PLUGGED, -1)
        if (enchufado != 0) {
            textoTiempoRestanteBateria.text = "Cargando"
            return
        }

        val consumoPromedioPorHora = 5.5
        val horasRestantes = porcentaje / consumoPromedioPorHora
        val horas = horasRestantes.toInt()
        val minutos = ((horasRestantes - horas) * 60).toInt()

        val calendario = Calendar.getInstance()
        calendario.add(Calendar.MINUTE, (horasRestantes * 60).toInt())
        val formatoHora = SimpleDateFormat("HH:mm", Locale.getDefault())

        textoTiempoRestanteBateria.text = "${horas}h ${minutos}m (hasta ~${formatoHora.format(calendario.time)})"
    }

    private fun actualizarIconoBateria(porcentaje: Int) {
        val (emoji, color) = when {
            porcentaje > 50 -> "🔋" to R.color.on
            porcentaje > 20 -> "🪫" to R.color.bateria_media
            else -> "🪫" to R.color.bateria_baja
        }
        iconoBateria.text = emoji
        textoPorcentajeBateria.setTextColor(ContextCompat.getColor(this, color))
    }

    // =========================================================================
    // LINTERNA
    // =========================================================================
    private fun configurarServicioLinterna() {
        administradorCamara = getSystemService(Context.CAMERA_SERVICE) as CameraManager
        try {
            for (id in administradorCamara.cameraIdList) {
                val caracteristicas = administradorCamara.getCameraCharacteristics(id)
                val tieneFlash = caracteristicas.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) ?: false
                if (tieneFlash) {
                    idCamaraConFlash = id
                    break
                }
            }
        } catch (error: CameraAccessException) {
            error.printStackTrace()
            Toast.makeText(this, "Error al acceder a la cámara", Toast.LENGTH_SHORT).show()
        }
    }

    private fun cambiarEstadoLinterna() {
        if (idCamaraConFlash == null) {
            Toast.makeText(this, "El dispositivo no cuenta con flash disponible", Toast.LENGTH_SHORT).show()
            return
        }

        try {
            if (estaLinternaEncendida) {
                administradorCamara.setTorchMode(idCamaraConFlash!!, false)
                estaLinternaEncendida = false
                actualizarInterfazLinterna(false)
            } else {
                administradorCamara.setTorchMode(idCamaraConFlash!!, true)
                estaLinternaEncendida = true
                actualizarInterfazLinterna(true)
            }
        } catch (error: Exception) {
            error.printStackTrace()
            Toast.makeText(this, "Error al alternar la linterna", Toast.LENGTH_SHORT).show()
        }
    }
    private fun actualizarInterfazLinterna(encendida: Boolean) {
        if (encendida) {
            textoEstadoLinterna.text = "ENCENDIDA"
            textoEstadoLinterna.setTextColor(ContextCompat.getColor(this, R.color.on))
            iconoLinterna.setImageResource(R.drawable.flashlight_on)
        } else {
            textoEstadoLinterna.text = "APAGADA"
            textoEstadoLinterna.setTextColor(ContextCompat.getColor(this, R.color.off))
            iconoLinterna.setImageResource(R.drawable.flashlight_off)
        }
    }

    // =========================================================================
    // STOP
    // =========================================================================
    override fun onStop() {
        super.onStop()
        if (estaLinternaEncendida && idCamaraConFlash != null) {
            try {
                administradorCamara.setTorchMode(idCamaraConFlash!!, false)
                estaLinternaEncendida = false
                actualizarInterfazLinterna(false)
            } catch (error: Exception) {
                error.printStackTrace()
            }
        }
        if (alertaActivaAhora) {
            detenerAlertaCatastrofe()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        unregisterReceiver(receptorBateria)
    }
}