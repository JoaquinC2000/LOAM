package com.example.trabajo1

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.util.AttributeSet
import android.view.View
import kotlin.math.cos
import kotlin.math.sin

class BrujulaView @JvmOverloads constructor(
    context: Context, attrs: AttributeSet? = null
) : View(context, attrs) {

    private val pintarFondo = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
        color = Color.parseColor("#1A1A1A")
    }
    private val pintarBisel = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 6f
        color = Color.parseColor("#555555")
    }
    private val pintarAnilloInterno = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 2f
        color = Color.parseColor("#444444")
    }
    private val pintarMarcaMayor = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 3f
        color = Color.parseColor("#EEEEEE")
    }
    private val pintarMarcaMenor = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 1.5f
        color = Color.parseColor("#666666")
    }
    private val pintarMarcaCardinalRoja = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 4f
        color = Color.parseColor("#FF5252")
    }
    private val pintarNumero = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#BBBBBB")
        textSize = 22f
        textAlign = Paint.Align.CENTER
    }
    private val pintarNorte = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#FF5252")
        textSize = 34f
        textAlign = Paint.Align.CENTER
        isFakeBoldText = true
    }
    private val pintarLetraCardinal = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        textSize = 30f
        textAlign = Paint.Align.CENTER
        isFakeBoldText = true
    }
    private val pintarCentro = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 2f
        color = Color.parseColor("#999999")
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val cx = width / 2f
        val cy = height / 2f
        val radioExterno = (minOf(width, height) / 2f) - 8f
        val radioBisel = radioExterno - 4f
        val radioTicks = radioBisel - 14f
        val radioNumeros = radioTicks - 26f
        val radioLetras = radioTicks - 62f

        // Fondo circular oscuro + bisel (efecto "metálico" simple con 2 anillos)
        canvas.drawCircle(cx, cy, radioExterno, pintarFondo)
        canvas.drawCircle(cx, cy, radioBisel, pintarBisel)
        canvas.drawCircle(cx, cy, radioTicks + 6f, pintarAnilloInterno)

        // Marcas cada 6°, más largas y numeradas cada 30°, en rojo en los
        // 4 puntos cardinales exactos (N=0°, E=90°, S=180°, O=270°)
        for (grado in 0 until 360 step 6) {
            val esMayor = grado % 30 == 0
            val esCardinalExacto = grado % 90 == 0
            val anguloRad = Math.toRadians((grado - 90).toDouble())

            val largoMarca = when {
                esCardinalExacto -> 22f
                esMayor -> 16f
                else -> 8f
            }
            val pintura = when {
                esCardinalExacto -> pintarMarcaCardinalRoja
                esMayor -> pintarMarcaMayor
                else -> pintarMarcaMenor
            }

            val x1 = cx + (radioTicks * cos(anguloRad)).toFloat()
            val y1 = cy + (radioTicks * sin(anguloRad)).toFloat()
            val x2 = cx + ((radioTicks - largoMarca) * cos(anguloRad)).toFloat()
            val y2 = cy + ((radioTicks - largoMarca) * sin(anguloRad)).toFloat()
            canvas.drawLine(x1, y1, x2, y2, pintura)

            // Los números se rotan junto con su posición, para que "sigan"
            // la curva del anillo (como en las imágenes de referencia)
            if (esMayor) {
                canvas.save()
                canvas.rotate(grado.toFloat(), cx, cy)
                canvas.drawText(grado.toString(), cx, cy - radioNumeros + 8f, pintarNumero)
                canvas.restore()
            }
        }

        // Crosshair central (crucecita + puntito), como en la imagen de iPhone
        canvas.drawLine(cx - 10f, cy, cx + 10f, cy, pintarCentro)
        canvas.drawLine(cx, cy - 10f, cx, cy + 10f, pintarCentro)
        val pintarPuntoCentro = Paint(pintarCentro).apply { style = Paint.Style.FILL }
        canvas.drawCircle(cx, cy, 3f, pintarPuntoCentro)

        // Letras cardinales, más adentro que los números
        dibujarLetra(canvas, "N", 0, cx, cy, radioLetras, pintarNorte)
        dibujarLetra(canvas, "E", 90, cx, cy, radioLetras, pintarLetraCardinal)
        dibujarLetra(canvas, "S", 180, cx, cy, radioLetras, pintarLetraCardinal)
        dibujarLetra(canvas, "O", 270, cx, cy, radioLetras, pintarLetraCardinal)
    }

    private fun dibujarLetra(canvas: Canvas, letra: String, grado: Int, cx: Float, cy: Float, radio: Float, pintura: Paint) {
        val anguloRad = Math.toRadians((grado - 90).toDouble())
        val x = cx + (radio * cos(anguloRad)).toFloat()
        val y = cy + (radio * sin(anguloRad)).toFloat() - (pintura.ascent() + pintura.descent()) / 2
        canvas.drawText(letra, x, y, pintura)
    }
}