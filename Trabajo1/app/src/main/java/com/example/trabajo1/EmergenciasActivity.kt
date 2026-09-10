package com.example.trabajo1

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.google.firebase.firestore.FirebaseFirestore

class EmergenciasActivity : AppCompatActivity() {

    private lateinit var rvEmergencias: RecyclerView
    private lateinit var adapter: EmergenciasAdapter
    private val firestore = FirebaseFirestore.getInstance()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_emergencias)

        rvEmergencias = findViewById(R.id.rvEmergencias)
        rvEmergencias.layoutManager = LinearLayoutManager(this)

        adapter = EmergenciasAdapter(emptyList()) { numero ->
            val intent = Intent(Intent.ACTION_DIAL).apply {
                data = Uri.parse("tel:$numero")
            }
            startActivity(intent)
        }
        rvEmergencias.adapter = adapter

        escucharEmergenciasEnTiempoReal()
    }

    private fun escucharEmergenciasEnTiempoReal() {
        firestore.collection("emergencias")
            .addSnapshotListener { snapshots, error ->
                if (error != null) {
                    runOnUiThread {
                        Toast.makeText(this, "Error: ${error.message}", Toast.LENGTH_LONG).show()
                    }
                    return@addSnapshotListener
                }

                if (snapshots != null && !snapshots.isEmpty) {
                    val lista = snapshots.toObjects(Emergencia::class.java)
                    runOnUiThread {
                        adapter.actualizarLista(lista)
                    }
                }
            }
    }
}