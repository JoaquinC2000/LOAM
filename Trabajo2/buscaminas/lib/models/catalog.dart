import 'package:flutter/material.dart';

/// Todo lo que se puede comprar en la tienda.
/// Está en un solo lugar para que sea fácil agregar cosas nuevas.

/// Tema del tablero (colores del césped, la tierra y el fondo).
class BoardTheme {
  const BoardTheme({
    required this.id,
    required this.name,
    required this.emoji,
    required this.price,
    required this.covered,
    required this.coveredAlt,
    required this.revealed,
    required this.revealedAlt,
    required this.background,
    this.proOnly = false,
  });

  final String id;
  final String name;
  final String emoji;
  final int price;
  final Color covered;
  final Color coveredAlt;
  final Color revealed;
  final Color revealedAlt;
  final Color background;
  final bool proOnly;
}

/// Ícono para las minas o para las banderas.
class SkinItem {
  const SkinItem({required this.id, required this.name, required this.emoji, required this.price});

  final String id;
  final String name;
  final String emoji;
  final int price;
}

/// Paquete de diamantes que se "compra" con dinero (simulado).
class DiamondPack {
  const DiamondPack({required this.diamonds, required this.price, this.tag, this.bonus = 0});

  final int diamonds;
  final String price;
  final String? tag;
  final int bonus;
}

/// Poderes que se usan durante la partida y se pagan con diamantes.
class PowerUp {
  const PowerUp({required this.id, required this.name, required this.emoji, required this.cost, required this.description});

  final String id;
  final String name;
  final String emoji;
  final int cost;
  final String description;
}

class Catalog {
  static const themes = <BoardTheme>[
    BoardTheme(
      id: 'pradera',
      name: 'Pradera',
      emoji: '🌳',
      price: 0,
      covered: Color(0xFFAAD751),
      coveredAlt: Color(0xFFA2D149),
      revealed: Color(0xFFE5C29F),
      revealedAlt: Color(0xFFD7B899),
      background: Color(0xFF4A752C),
    ),
    BoardTheme(
      id: 'playa',
      name: 'Playa',
      emoji: '🏖️',
      price: 60,
      covered: Color(0xFF7FD3E8),
      coveredAlt: Color(0xFF6CC8DF),
      revealed: Color(0xFFFBE7B5),
      revealedAlt: Color(0xFFF3DCA4),
      background: Color(0xFF2B8FB3),
    ),
    BoardTheme(
      id: 'golosinas',
      name: 'Golosinas',
      emoji: '🍭',
      price: 100,
      covered: Color(0xFFFF9EC7),
      coveredAlt: Color(0xFFFF8DBD),
      revealed: Color(0xFFFFF1D6),
      revealedAlt: Color(0xFFFBE6C2),
      background: Color(0xFFC2185B),
    ),
    BoardTheme(
      id: 'espacio',
      name: 'Espacio',
      emoji: '🚀',
      price: 120,
      covered: Color(0xFF8A7CF5),
      coveredAlt: Color(0xFF7C6CF0),
      revealed: Color(0xFFE6E1FF),
      revealedAlt: Color(0xFFD9D3FB),
      background: Color(0xFF241B5A),
    ),
    BoardTheme(
      id: 'dorado',
      name: 'Dorado',
      emoji: '👑',
      price: 0,
      covered: Color(0xFFFFD54F),
      coveredAlt: Color(0xFFFFCA28),
      revealed: Color(0xFFFFF8E1),
      revealedAlt: Color(0xFFFFF0C2),
      background: Color(0xFF9C6B00),
      proOnly: true,
    ),
  ];

  static const mines = <SkinItem>[
    SkinItem(id: 'bomba', name: 'Bomba', emoji: '💣', price: 0),
    SkinItem(id: 'bicho', name: 'Vaquita', emoji: '🐞', price: 30),
    SkinItem(id: 'cangrejo', name: 'Cangrejo', emoji: '🦀', price: 30),
    SkinItem(id: 'fantasma', name: 'Fantasma', emoji: '👻', price: 50),
    SkinItem(id: 'meteorito', name: 'Meteorito', emoji: '☄️', price: 50),
    SkinItem(id: 'pulpo', name: 'Pulpo', emoji: '🐙', price: 80),
  ];

  static const flags = <SkinItem>[
    SkinItem(id: 'bandera', name: 'Bandera', emoji: '🚩', price: 0),
    SkinItem(id: 'flor', name: 'Flor', emoji: '🌸', price: 20),
    SkinItem(id: 'estrella', name: 'Estrella', emoji: '⭐', price: 20),
    SkinItem(id: 'globo', name: 'Globo', emoji: '🎈', price: 30),
    SkinItem(id: 'pirata', name: 'Pirata', emoji: '🏴‍☠️', price: 40),
  ];

  static const diamondPacks = <DiamondPack>[
    DiamondPack(diamonds: 50, price: 'US\$ 0,99'),
    DiamondPack(diamonds: 150, price: 'US\$ 2,49', tag: 'POPULAR', bonus: 15),
    DiamondPack(diamonds: 400, price: 'US\$ 4,99', bonus: 60),
    DiamondPack(diamonds: 1000, price: 'US\$ 9,99', tag: 'MEJOR VALOR', bonus: 250),
  ];

  static const proPrice = 'US\$ 2,99 / mes';
  static const proGiftDiamonds = 50;
  static const rewardedAdDiamonds = 5;

  static const probe = PowerUp(id: 'lupa', name: 'Lupa', emoji: '🔍', cost: 10, description: 'Elegí una casilla: muestra su número o marca la mina');
  static const radar = PowerUp(id: 'radar', name: 'Radar', emoji: '📡', cost: 15, description: 'Encuentra una mina y le pone bandera');
  static const extraTime = PowerUp(id: 'tiempo', name: '+30 s', emoji: '⏳', cost: 15, description: 'Suma 30 segundos (contrarreloj)');
  static const secondLife = PowerUp(id: 'vida', name: 'Segunda vida', emoji: '❤️', cost: 20, description: 'Seguí jugando después de explotar');

  static BoardTheme themeById(String id) => themes.firstWhere((t) => t.id == id, orElse: () => themes.first);
  static SkinItem mineById(String id) => mines.firstWhere((m) => m.id == id, orElse: () => mines.first);
  static SkinItem flagById(String id) => flags.firstWhere((f) => f.id == id, orElse: () => flags.first);
}
