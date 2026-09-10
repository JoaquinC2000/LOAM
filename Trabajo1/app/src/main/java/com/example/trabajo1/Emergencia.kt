package com.example.trabajo1

// El constructor vacío por defecto es obligatorio para que Firebase pueda deserializar los datos
data class Emergencia(
    val institucion: String = "",
    val numero: String = ""
)