package com.example.trabajo1

import android.app.Application
import android.content.Intent
import android.content.SharedPreferences
import com.google.firebase.firestore.FirebaseFirestore

class AlertaCatastrofeApp : Application() {

    private lateinit var firestore: FirebaseFirestore
    private lateinit var preferencias: SharedPreferences
    private val VENTANA_COINCIDENCIA_MS = 2 * 60 * 1000L

    override fun onCreate() {
        super.onCreate()
        firestore = FirebaseFirestore.getInstance()
        preferencias = getSharedPreferences("alertas_prefs", MODE_PRIVATE)
        escucharEventosDeCatastrofe()
    }

    private fun obtenerIdsProcesados(): MutableSet<String> {
        return preferencias.getStringSet("ids_procesados", emptySet())?.toMutableSet() ?: mutableSetOf()
    }

    private fun marcarComoProcesado(id: String) {
        val actuales = obtenerIdsProcesados()
        actuales.add(id)
        preferencias.edit().putStringSet("ids_procesados", actuales).apply()
    }

    private fun escucharEventosDeCatastrofe() {
        firestore.collection("catastrofes")
            .addSnapshotListener { snapshot, error ->
                if (error != null) {
                    error.printStackTrace()
                    return@addSnapshotListener
                }

                val idsYaProcesados = obtenerIdsProcesados()
                val ahora = System.currentTimeMillis()

                snapshot?.documents?.forEach { documento ->
                    val id = documento.id
                    if (id in idsYaProcesados) return@forEach

                    val fechaHoraMillis = documento.getLong("tiempo") ?: return@forEach
                    val tipo = documento.getString("tipo") ?: "Catástrofe"
                    val latitud = documento.getDouble("latitud") ?: 0.0
                    val longitud = documento.getDouble("longitud") ?: 0.0

                    val coincideEnTiempo = kotlin.math.abs(ahora - fechaHoraMillis) <= VENTANA_COINCIDENCIA_MS
                    if (coincideEnTiempo) {
                        marcarComoProcesado(id)
                        traerAppAlFrenteYAlertar(tipo, latitud, longitud, fechaHoraMillis)
                    }
                }
            }
    }

    private fun traerAppAlFrenteYAlertar(tipo: String, lat: Double, lon: Double, fechaHoraMillis: Long) {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("alertaTipo", tipo)
            putExtra("alertaLat", lat)
            putExtra("alertaLon", lon)
            putExtra("alertaFechaHoraMillis", fechaHoraMillis)
        }
        startActivity(intent)
    }
}