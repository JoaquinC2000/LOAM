package com.example.trabajo1

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.location.LocationManager
import android.os.Bundle
import android.os.Looper
import android.view.View
import android.webkit.WebView
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.activity.OnBackPressedCallback
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.firebase.firestore.FirebaseFirestore

data class Coordenada(val lat: Double, val lon: Double)

class UbicacionActivity : AppCompatActivity() {

    private lateinit var mapaWeb: WebView
    private lateinit var textoError: TextView
    private var ubicacionActual: Coordenada? = null

    private lateinit var clienteUbicacion: FusedLocationProviderClient
    private var solicitandoUbicacion = false

    private val callbackUbicacion = object : LocationCallback() {
        override fun onLocationResult(resultado: LocationResult) {
            val ubicacion = resultado.lastLocation ?: return
            val coordenada = Coordenada(ubicacion.latitude, ubicacion.longitude)
            ubicacionActual = coordenada
            ocultarError()
            mostrarMapaEn(coordenada)
        }
    }

    // Si se desactiva la ubicacion y luego se activa nuevamente, estando en la pantalla del mapa,
    // se actualiza sin tener que cerrar la app
    private val receptorCambioGps = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            verificarGpsYPedirUbicacion()
        }
    }

    private val solicitarPermisoUbicacion = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { concedido ->
        if (concedido) verificarGpsYPedirUbicacion()
        else mostrarError("Necesitamos el permiso de ubicación para mostrar dónde estás.")
    }

    // === Brújula (Punto de innovación) ===
    private lateinit var administradorSensores: SensorManager
    private var sensorAcelerometro: Sensor? = null
    private var sensorMagnetometro: Sensor? = null
    private val lecturasAcelerometro = FloatArray(3)
    private val lecturasMagnetometro = FloatArray(3)
    private var hayLecturaAcelerometro = false
    private var hayLecturaMagnetometro = false
    private var anguloActualBrujula = 0f

    private lateinit var botonAbrirBrujula: View
    private lateinit var overlayBrujulaGrande: View
    private lateinit var vistaBrujulaGrande: BrujulaView
    private lateinit var textoGradosBrujulaGrande: TextView

    private val listenerSensores = object : SensorEventListener {
        override fun onSensorChanged(evento: SensorEvent) {
            when (evento.sensor.type) {
                Sensor.TYPE_ACCELEROMETER -> {
                    System.arraycopy(evento.values, 0, lecturasAcelerometro, 0, 3)
                    hayLecturaAcelerometro = true
                }
                Sensor.TYPE_MAGNETIC_FIELD -> {
                    System.arraycopy(evento.values, 0, lecturasMagnetometro, 0, 3)
                    hayLecturaMagnetometro = true
                }
            }
            if (hayLecturaAcelerometro && hayLecturaMagnetometro) actualizarBrujula()
        }
        override fun onAccuracyChanged(sensor: Sensor, accuracy: Int) {}
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_ubicacion)

        findViewById<View>(R.id.botonVolverUbicacion).setOnClickListener { finish() }
        textoError = findViewById(R.id.textoErrorUbicacion)
        textoError.setOnClickListener { verificarPermisoYObtenerUbicacion() }

        mapaWeb = findViewById(R.id.mapaUbicacion)
        mapaWeb.settings.javaScriptEnabled = true

        findViewById<LinearLayout>(R.id.botonRegistrarUbicacion).setOnClickListener {
            registrarUbicacionEnFirebase()
        }

        clienteUbicacion = LocationServices.getFusedLocationProviderClient(this)
        registerReceiver(receptorCambioGps, IntentFilter(LocationManager.PROVIDERS_CHANGED_ACTION))
        verificarPermisoYObtenerUbicacion()

        botonAbrirBrujula = findViewById(R.id.botonAbrirBrujula)
        overlayBrujulaGrande = findViewById(R.id.overlayBrujulaGrande)
        vistaBrujulaGrande = findViewById(R.id.vistaBrujulaGrande)
        textoGradosBrujulaGrande = findViewById(R.id.textoGradosBrujulaGrande)

        botonAbrirBrujula.setOnClickListener { mostrarBrujulaGrande() }
        overlayBrujulaGrande.setOnClickListener { ocultarBrujulaGrande() }
        findViewById<View>(R.id.botonCerrarBrujulaGrande).setOnClickListener { ocultarBrujulaGrande() }

        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                if (overlayBrujulaGrande.visibility == View.VISIBLE) {
                    ocultarBrujulaGrande()
                } else {
                    isEnabled = false
                    onBackPressedDispatcher.onBackPressed()
                }
            }
        })

        administradorSensores = getSystemService(SENSOR_SERVICE) as SensorManager
        sensorAcelerometro = administradorSensores.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        sensorMagnetometro = administradorSensores.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD)

        if (sensorAcelerometro == null || sensorMagnetometro == null) {
            botonAbrirBrujula.visibility = View.GONE
        }

        if (intent.getBooleanExtra("abrirBrujula", false) && sensorAcelerometro != null && sensorMagnetometro != null) {
            mostrarBrujulaGrande()
        }
    }

    private fun mostrarBrujulaGrande() {
        overlayBrujulaGrande.visibility = View.VISIBLE
    }

    private fun ocultarBrujulaGrande() {
        overlayBrujulaGrande.visibility = View.GONE
    }

    override fun onResume() {
        super.onResume()
        sensorAcelerometro?.let { administradorSensores.registerListener(listenerSensores, it, SensorManager.SENSOR_DELAY_UI) }
        sensorMagnetometro?.let { administradorSensores.registerListener(listenerSensores, it, SensorManager.SENSOR_DELAY_UI) }
    }

    override fun onPause() {
        super.onPause()
        administradorSensores.unregisterListener(listenerSensores)
    }

    private fun actualizarBrujula() {
        val matrizRotacion = FloatArray(9)
        val orientacion = FloatArray(3)
        val exito = SensorManager.getRotationMatrix(matrizRotacion, null, lecturasAcelerometro, lecturasMagnetometro)
        if (!exito) return

        SensorManager.getOrientation(matrizRotacion, orientacion)
        var azimutGrados = Math.toDegrees(orientacion[0].toDouble()).toFloat()
        if (azimutGrados < 0) azimutGrados += 360f

        val diferencia = azimutGrados - anguloActualBrujula
        anguloActualBrujula += diferencia * 0.15f

        vistaBrujulaGrande.rotation = -anguloActualBrujula
        textoGradosBrujulaGrande.text = "${azimutGrados.toInt()}° ${direccionCardinal(azimutGrados)}"
    }

    private fun direccionCardinal(grados: Float): String {
        return when {
            grados >= 337.5 || grados < 22.5 -> "N"
            grados < 67.5 -> "NE"
            grados < 112.5 -> "E"
            grados < 157.5 -> "SE"
            grados < 202.5 -> "S"
            grados < 247.5 -> "SO"
            grados < 292.5 -> "O"
            else -> "NO"
        }
    }

    private fun verificarPermisoYObtenerUbicacion() {
        val tienePermiso = ContextCompat.checkSelfPermission(
            this, Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED

        if (tienePermiso) verificarGpsYPedirUbicacion()
        else solicitarPermisoUbicacion.launch(Manifest.permission.ACCESS_FINE_LOCATION)
    }

    private fun verificarGpsYPedirUbicacion() {
        val gestorUbicacion = getSystemService(LOCATION_SERVICE) as LocationManager
        if (!gestorUbicacion.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
            mostrarError("⚠️ El GPS está desactivado. Activalo en Ajustes.")
            detenerSolicitudUbicacion()
            return
        }
        ocultarError()
        iniciarSolicitudUbicacion()
    }

    private fun iniciarSolicitudUbicacion() {
        if (solicitandoUbicacion) return
        val tienePermiso = ContextCompat.checkSelfPermission(
            this, Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        if (!tienePermiso) return

        val solicitud = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 5000L).build()
        clienteUbicacion.requestLocationUpdates(solicitud, callbackUbicacion, Looper.getMainLooper())
        solicitandoUbicacion = true
    }

    private fun detenerSolicitudUbicacion() {
        clienteUbicacion.removeLocationUpdates(callbackUbicacion)
        solicitandoUbicacion = false
    }

    private fun mostrarMapaEn(coordenada: Coordenada) {
        val delta = 0.005
        val bbox = "${coordenada.lon - delta},${coordenada.lat - delta},${coordenada.lon + delta},${coordenada.lat + delta}"
        val url = "https://www.openstreetmap.org/export/embed.html?bbox=$bbox&layer=mapnik&marker=${coordenada.lat},${coordenada.lon}"
        mapaWeb.loadUrl(url)
    }

    private fun registrarUbicacionEnFirebase() {
        val coordenada = ubicacionActual
        if (coordenada == null) {
            Toast.makeText(this, "Todavía no tenemos tu ubicación, esperá un segundo y probá de nuevo", Toast.LENGTH_LONG).show()
            return
        }
        val datos = hashMapOf(
            "latitud" to coordenada.lat,
            "longitud" to coordenada.lon,
            "timestamp" to System.currentTimeMillis()
        )
        FirebaseFirestore.getInstance().collection("ubicaciones_registradas")
            .add(datos)
            .addOnSuccessListener { Toast.makeText(this, "✓ Ubicación registrada en Firebase", Toast.LENGTH_SHORT).show() }
            .addOnFailureListener { error -> Toast.makeText(this, "Error al registrar: ${error.message}", Toast.LENGTH_LONG).show() }
    }

    private fun mostrarError(mensaje: String) {
        textoError.text = "$mensaje\n"
        textoError.visibility = View.VISIBLE
    }

    private fun ocultarError() {
        textoError.visibility = View.GONE
    }

    override fun onDestroy() {
        super.onDestroy()
        detenerSolicitudUbicacion()
        unregisterReceiver(receptorCambioGps)
    }
}