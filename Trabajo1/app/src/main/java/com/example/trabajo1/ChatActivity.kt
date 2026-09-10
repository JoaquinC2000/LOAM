package com.example.trabajo1

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.Query

data class MensajeChat(
    val texto: String = "",
    val emisor: String = "usuario",
    val timestamp: Long = 0L
)

class ChatActivity : AppCompatActivity() {

    private lateinit var contenedorMensajes: LinearLayout
    private lateinit var scrollMensajes: ScrollView
    private lateinit var campoTexto: EditText
    private val firestore = FirebaseFirestore.getInstance()

    private var procesandoRespuestaAutomatica = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_chat)

        findViewById<View>(R.id.botonVolverChat).setOnClickListener { finish() }

        contenedorMensajes = findViewById(R.id.contenedorMensajes)
        scrollMensajes = findViewById(R.id.scrollMensajes)
        campoTexto = findViewById(R.id.campoTextoChat)

        findViewById<View>(R.id.botonEnviarChat).setOnClickListener { enviarMensaje() }

        escucharMensajesEnTiempoReal()
    }

    private fun enviarMensaje() {
        val texto = campoTexto.text.toString().trim()
        if (texto.isEmpty()) return

        val datos = hashMapOf(
            "texto" to texto,
            "emisor" to "usuario",
            "timestamp" to System.currentTimeMillis()
        )
        firestore.collection("mensajes_chat").add(datos)
        campoTexto.setText("")
    }

    private fun escucharMensajesEnTiempoReal() {
        firestore.collection("mensajes_chat")
            .orderBy("timestamp", Query.Direction.ASCENDING)
            .addSnapshotListener { snapshot, error ->
                if (error != null) {
                    error.printStackTrace()
                    return@addSnapshotListener
                }

                val mensajes = snapshot?.documents?.mapNotNull {
                    it.toObject(MensajeChat::class.java)
                } ?: emptyList()

                contenedorMensajes.removeAllViews()
                mensajes.forEach { agregarBurbujaMensaje(it) }
                scrollMensajes.post { scrollMensajes.fullScroll(View.FOCUS_DOWN) }

                comprobarSiguienteMensajeDelGuion(mensajes)
            }
    }

    private fun comprobarSiguienteMensajeDelGuion(mensajes: List<MensajeChat>) {
        if (procesandoRespuestaAutomatica) return

        val cantidadAsistente = mensajes.count { it.emisor == "asistente" }
        val cantidadUsuario = mensajes.count { it.emisor == "usuario" }

        val siguienteOrden = when {
            cantidadAsistente == 0 -> 1
            cantidadUsuario >= cantidadAsistente -> cantidadAsistente + 1
            else -> null
        }

        if (siguienteOrden == null) return

        procesandoRespuestaAutomatica = true
        firestore.collection("chat_guion")
            .whereEqualTo("orden", siguienteOrden)
            .get()
            .addOnSuccessListener { resultado ->
                val textoRespuesta = resultado.documents.firstOrNull()?.getString("texto")
                if (textoRespuesta == null) {

                    procesandoRespuestaAutomatica = false
                    return@addOnSuccessListener
                }

                Handler(Looper.getMainLooper()).postDelayed({
                    val datos = hashMapOf(
                        "texto" to textoRespuesta,
                        "emisor" to "asistente",
                        "timestamp" to System.currentTimeMillis()
                    )
                    firestore.collection("mensajes_chat").add(datos)
                        .addOnCompleteListener { procesandoRespuestaAutomatica = false }
                }, 1200)
            }
            .addOnFailureListener {
                it.printStackTrace()
                procesandoRespuestaAutomatica = false
            }
    }

    private fun agregarBurbujaMensaje(mensaje: MensajeChat) {
        val vista = LayoutInflater.from(this)
            .inflate(R.layout.item_mensaje, contenedorMensajes, false) as TextView
        vista.text = mensaje.texto

        val esUsuario = mensaje.emisor == "usuario"
        vista.setBackgroundResource(
            if (esUsuario) R.drawable.bg_burbuja_usuario else R.drawable.bg_burbuja_asistente
        )
        vista.setTextColor(
            ContextCompat.getColor(this, if (esUsuario) R.color.white else R.color.texto_principal)
        )

        val parametros = vista.layoutParams as LinearLayout.LayoutParams
        parametros.gravity = if (esUsuario) Gravity.END else Gravity.START
        vista.layoutParams = parametros

        contenedorMensajes.addView(vista)
    }
}