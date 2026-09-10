package com.example.trabajo1

import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.TextView
import androidx.recyclerview.widget.RecyclerView

class EmergenciasAdapter(
    private var lista: List<Emergencia>,
    private val onCallClick: (String) -> Unit
) : RecyclerView.Adapter<EmergenciasAdapter.EmergenciaViewHolder>() {

    class EmergenciaViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {
        val tvInstitucion: TextView = itemView.findViewById(R.id.tvInstitucion)
        val tvNumero: TextView = itemView.findViewById(R.id.tvNumero)
        val btnLlamar: Button = itemView.findViewById(R.id.btnLlamar)
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): EmergenciaViewHolder {
        val view = LayoutInflater.from(parent.context).inflate(R.layout.emergencia, parent, false)
        return EmergenciaViewHolder(view)
    }

    override fun onBindViewHolder(holder: EmergenciaViewHolder, position: Int) {
        val item = lista[position]
        holder.tvInstitucion.text = item.institucion
        holder.tvNumero.text = item.numero

        holder.btnLlamar.setOnClickListener {
            onCallClick(item.numero)
        }
    }

    override fun getItemCount(): Int = lista.size

    fun actualizarLista(nuevaLista: List<Emergencia>) {
        this.lista = nuevaLista
        notifyDataSetChanged()
    }
}