package com.example.trabajo1

import android.os.Bundle
import android.view.View
import android.widget.LinearLayout
import androidx.appcompat.app.AppCompatActivity
import android.content.Intent

class MultimediaActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_multimedia)

        findViewById<View>(R.id.botonVolverMultimedia).setOnClickListener { finish() }

        findViewById<LinearLayout>(R.id.btnVideoFrontal).setOnClickListener {
            val intent = Intent(this, GrabacionVideoActivity::class.java)
            intent.putExtra("tipoCamara", "frontal")
            startActivity(intent)
        }
        findViewById<LinearLayout>(R.id.btnVideoSelfie).setOnClickListener {
            val intent = Intent(this, GrabacionVideoActivity::class.java)
            intent.putExtra("tipoCamara", "selfie")
            startActivity(intent)
        }
        findViewById<LinearLayout>(R.id.btnAudioMemo).setOnClickListener {
            startActivity(Intent(this, GrabacionAudioActivity::class.java))
        }
        findViewById<LinearLayout>(R.id.btnRadio).setOnClickListener {
            startActivity(Intent(this, RadioActivity::class.java))
        }
    }
}