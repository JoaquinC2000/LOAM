package com.example.trabajo1

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import com.google.firebase.firestore.FirebaseFirestore


data class ContactoEmergencia(
    val institucion: String = "",
    val numero: String = ""
)

class EmergenciaActivity : AppCompatActivity() {

    private lateinit var contenedorContactos: LinearLayout
    private lateinit var progreso: ProgressBar
    private val firestore = FirebaseFirestore.getInstance()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_emergencia)

        contenedorContactos = findViewById(R.id.contenedorContactos)
        progreso = findViewById(R.id.progresoContactos)

        findViewById<View>(R.id.botonVolver).setOnClickListener { finish() }

        escucharContactosEnTiempoReal()
    }

    // Se queda escuchando la base de datos por si hay algun cambio
    private fun escucharContactosEnTiempoReal() {
        firestore.collection("emergencias")
            .addSnapshotListener { snapshot, error ->
                progreso.visibility = View.GONE

                if (error != null) {
                    error.printStackTrace()
                    return@addSnapshotListener
                }

                contenedorContactos.removeAllViews() // limpiamos antes de redibujar

                snapshot?.documents?.forEach { documento ->
                    val contacto = documento.toObject(ContactoEmergencia::class.java)
                    if (contacto != null) {
                        agregarTarjetaContacto(contacto)
                    }
                }
            }
    }

    // Arma las tarjetas de cada contacto.
    private fun agregarTarjetaContacto(contacto: ContactoEmergencia) {
        val vista = LayoutInflater.from(this).inflate(R.layout.item_contacto, contenedorContactos, false)

        vista.findViewById<TextView>(R.id.textoNombreContacto).text = contacto.institucion
        vista.findViewById<TextView>(R.id.textoNumeroContacto).text = contacto.numero

        // Con ACTION_DIAL abre el telefono con el numero cargado
        vista.findViewById<View>(R.id.botonLlamar).setOnClickListener {
            val intentLlamada = Intent(Intent.ACTION_DIAL, Uri.parse("tel:${contacto.numero}"))
            startActivity(intentLlamada)
        }

        contenedorContactos.addView(vista)
    }
}