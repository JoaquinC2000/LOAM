import 'package:flutter/material.dart';

import '../models/app_state.dart';
import '../models/catalog.dart';
import '../services/sound_service.dart';
import '../widgets/ad_dialog.dart';
import '../widgets/game_header.dart';
import '../widgets/payment_sheet.dart';

/// Tienda con 5 pestañas:
///   💎 Diamantes (se compran con dinero simulado)
///   🎨 Temas, 💣 Minas, 🚩 Banderas (se compran con diamantes)
///   👑 PRO (suscripción simulada)
class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      initialIndex: initialTab,
      child: ListenableBuilder(
        listenable: appState,
        builder: (context, _) => Scaffold(
          body: Column(
            children: [
              GameHeader(onBack: () => Navigator.of(context).pop()),
              const TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.center,
                labelStyle: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                tabs: [
                  Tab(text: '💎 Diamantes'),
                  Tab(text: '🎨 Temas'),
                  Tab(text: '💣 Minas'),
                  Tab(text: '🚩 Banderas'),
                  Tab(text: '👑 PRO'),
                ],
              ),
              // Sin "const" a propósito: así las pestañas se redibujan
              // cuando cambian los diamantes o lo que compraste.
              Expanded(
                child: TabBarView(
                  children: [
                    // ignore: prefer_const_constructors
                    _DiamondsTab(),
                    // ignore: prefer_const_constructors
                    _ThemesTab(),
                    // ignore: prefer_const_constructors
                    _SkinsTab(isMine: true),
                    // ignore: prefer_const_constructors
                    _SkinsTab(isMine: false),
                    // ignore: prefer_const_constructors
                    _ProTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _snack(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// Pregunta antes de gastar diamantes.
Future<bool> _confirmSpend(BuildContext context, String item, int cost) async {
  if (appState.diamonds < cost) {
    _snack(context, 'Te faltan ${cost - appState.diamonds} 💎. ¡Conseguí más en la pestaña Diamantes!');
    DefaultTabController.of(context).animateTo(0);
    return false;
  }
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('¿Comprar $item?'),
      content: Text('Cuesta $cost 💎. Te van a quedar ${appState.diamonds - cost} 💎.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Comprar')),
      ],
    ),
  );
  return ok ?? false;
}

// ============================ Diamantes ============================

class _DiamondsTab extends StatelessWidget {
  const _DiamondsTab();

  Future<void> _buy(BuildContext context, DiamondPack pack) async {
    final total = pack.diamonds + pack.bonus;
    final paid = await showPaymentSheet(context, product: '$total diamantes 💎', price: pack.price);
    if (!paid) return;
    appState.buyDiamondPack(pack);
    SoundService.coin();
    if (context.mounted) _snack(context, '¡Sumaste $total 💎!');
  }

  Future<void> _watchAd(BuildContext context) async {
    final watched = await showAdDialog(context, rewarded: true);
    if (!watched) return;
    appState.addDiamonds(Catalog.rewardedAdDiamonds);
    SoundService.coin();
    if (context.mounted) _snack(context, '¡Ganaste ${Catalog.rewardedAdDiamonds} 💎 gratis!');
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.85,
          children: [
            for (final (i, pack) in Catalog.diamondPacks.indexed) _DiamondPackCard(pack: pack, size: i, onTap: () => _buy(context, pack)),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          color: Theme.of(context).colorScheme.secondaryContainer,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: const Text('📺', style: TextStyle(fontSize: 32)),
            title: const Text('Diamantes gratis', style: TextStyle(fontWeight: FontWeight.w900)),
            subtitle: const Text('Mirá un anuncio y ganá ${Catalog.rewardedAdDiamonds} 💎'),
            trailing: FilledButton(onPressed: () => _watchAd(context), child: const Text('Ver')),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Ganá diamantes también cuando ganás partidas: 5 en Fácil, 10 en Medio y 20 en Difícil (el doble si sos PRO).',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13),
        ),
      ],
    );
  }
}

class _DiamondPackCard extends StatelessWidget {
  const _DiamondPackCard({required this.pack, required this.size, required this.onTap});

  final DiamondPack pack;
  final int size;
  final VoidCallback onTap;

  static const _piles = ['💎', '💎💎', '💎💎💎', '💰💎💎'];

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          SoundService.tap();
          onTap();
        },
        child: Ink(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF4FC3F7), Color(0xFF1E88E5)],
            ),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_piles[size], style: const TextStyle(fontSize: 34)),
                    const SizedBox(height: 6),
                    Text(
                      '${pack.diamonds}',
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
                    ),
                    if (pack.bonus > 0)
                      Text(
                        '+${pack.bonus} de regalo',
                        style: const TextStyle(color: Color(0xFFFFF59D), fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                    const Spacer(),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        pack.price,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF1565C0), fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              ),
              if (pack.tag != null)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF4081),
                      borderRadius: BorderRadius.only(bottomLeft: Radius.circular(14)),
                    ),
                    child: Text(pack.tag!, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================ Temas ============================

class _ThemesTab extends StatelessWidget {
  const _ThemesTab();

  Future<void> _onTap(BuildContext context, BoardTheme t) async {
    if (appState.ownsTheme(t)) {
      appState.selectTheme(t);
      return;
    }
    if (t.proOnly) {
      _snack(context, 'El tema ${t.name} es exclusivo para cuentas PRO 👑');
      DefaultTabController.of(context).animateTo(4);
      return;
    }
    if (await _confirmSpend(context, 'el tema ${t.name}', t.price)) {
      appState.buyTheme(t);
      SoundService.coin();
      if (context.mounted) _snack(context, '¡Tema ${t.name} activado! ${t.emoji}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      padding: const EdgeInsets.all(16),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.78,
      children: [
        for (final t in Catalog.themes)
          _ShopCard(
            selected: appState.selectedTheme == t.id,
            owned: appState.ownsTheme(t),
            price: t.price,
            proOnly: t.proOnly,
            title: '${t.emoji} ${t.name}',
            preview: _ThemePreview(theme: t, mineEmoji: appState.mineEmoji, flagEmoji: appState.flagEmoji),
            onTap: () => _onTap(context, t),
          ),
      ],
    );
  }
}

/// Mini tablero de 4x4 para mostrar cómo se ve el tema.
class _ThemePreview extends StatelessWidget {
  const _ThemePreview({required this.theme, required this.mineEmoji, required this.flagEmoji});

  final BoardTheme theme;
  final String mineEmoji;
  final String flagEmoji;

  static const _layout = [
    ['c', 'c', 'f', 'c'],
    ['1', '2', 'c', 'c'],
    ['', '1', '3', 'm'],
    ['', '', '1', 'c'],
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: theme.background, borderRadius: BorderRadius.circular(12)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var r = 0; r < 4; r++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var c = 0; c < 4; c++) _cell(_layout[r][c], (r + c) % 2 == 0),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _cell(String type, bool even) {
    final covered = type == 'c' || type == 'f';
    final color = type == 'm'
        ? const Color(0xFFFF8A80)
        : covered
            ? (even ? theme.covered : theme.coveredAlt)
            : (even ? theme.revealed : theme.revealedAlt);
    final text = switch (type) {
      'f' => flagEmoji,
      'm' => mineEmoji,
      'c' || '' => '',
      _ => type,
    };
    const numberColors = {'1': Color(0xFF1976D2), '2': Color(0xFF388E3C), '3': Color(0xFFD32F2F)};
    return Container(
      width: 26,
      height: 26,
      color: color,
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: numberColors[type]),
      ),
    );
  }
}

// ============================ Minas y banderas ============================

class _SkinsTab extends StatelessWidget {
  const _SkinsTab({required this.isMine});
  final bool isMine;

  Future<void> _onTap(BuildContext context, SkinItem s) async {
    final owned = isMine ? appState.ownedMines.contains(s.id) : appState.ownedFlags.contains(s.id);
    if (owned) {
      if (isMine) {
        appState.selectMine(s);
      } else {
        appState.selectFlag(s);
      }
      return;
    }
    if (await _confirmSpend(context, s.name, s.price)) {
      if (isMine) {
        appState.buyMine(s);
        SoundService.coin();
      } else {
        appState.buyFlag(s);
        SoundService.coin();
      }
      if (context.mounted) _snack(context, '¡${s.name} ${s.emoji} activado!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = isMine ? Catalog.mines : Catalog.flags;
    final selected = isMine ? appState.selectedMine : appState.selectedFlag;
    final owned = isMine ? appState.ownedMines : appState.ownedFlags;
    return GridView.count(
      padding: const EdgeInsets.all(16),
      crossAxisCount: 3,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.72,
      children: [
        for (final s in items)
          _ShopCard(
            selected: selected == s.id,
            owned: owned.contains(s.id),
            price: s.price,
            title: s.name,
            preview: Text(s.emoji, style: const TextStyle(fontSize: 44)),
            onTap: () => _onTap(context, s),
          ),
      ],
    );
  }
}

/// Tarjeta genérica de la tienda: vista previa, nombre y botón de precio/usar.
class _ShopCard extends StatelessWidget {
  const _ShopCard({
    required this.selected,
    required this.owned,
    required this.price,
    required this.title,
    required this.preview,
    required this.onTap,
    this.proOnly = false,
  });

  final bool selected;
  final bool owned;
  final int price;
  final bool proOnly;
  final String title;
  final Widget preview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final String buttonText;
    final Color buttonColor;
    if (selected) {
      buttonText = '✔ En uso';
      buttonColor = const Color(0xFF43A047);
    } else if (owned) {
      buttonText = 'Usar';
      buttonColor = const Color(0xFF42A5F5);
    } else if (proOnly) {
      buttonText = '👑 PRO';
      buttonColor = const Color(0xFFFFA000);
    } else {
      buttonText = '$price 💎';
      buttonColor = const Color(0xFF7E57C2);
    }

    return GestureDetector(
      onTap: () {
        SoundService.tap();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? const Color(0xFF43A047) : Colors.transparent, width: 3),
        ),
        child: Column(
          children: [
            Expanded(child: Center(child: FittedBox(child: preview))),
            const SizedBox(height: 6),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(color: buttonColor, borderRadius: BorderRadius.circular(20)),
              child: Text(
                buttonText,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================ PRO ============================

class _ProTab extends StatelessWidget {
  const _ProTab();

  Future<void> _subscribe(BuildContext context) async {
    final paid = await showPaymentSheet(context, product: 'Suscripción PRO 👑', price: Catalog.proPrice);
    if (!paid) return;
    appState.activatePro();
    SoundService.coin();
    if (context.mounted) _snack(context, '¡Bienvenido a PRO! 👑 +${Catalog.proGiftDiamonds} 💎 de regalo');
  }

  Future<void> _cancel(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cancelar PRO?'),
        content: const Text('Vas a volver a ver publicidad y perderás el tema Dorado.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Seguir PRO')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancelar')),
        ],
      ),
    );
    if (ok == true) appState.cancelPro();
  }

  @override
  Widget build(BuildContext context) {
    final isPro = appState.isPro;
    const benefits = [
      ('🚫', 'Sin publicidad', 'Jugá sin interrupciones'),
      ('💎', 'Diamantes x2', 'Al ganar cada partida'),
      ('👑', 'Tema Dorado', 'Exclusivo para PRO'),
      ('🎁', '+${Catalog.proGiftDiamonds} diamantes', 'De regalo al suscribirte'),
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFFFD54F), Color(0xFFFFA000)]),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              const Text('👑', style: TextStyle(fontSize: 56)),
              Text(
                isPro ? '¡Ya sos PRO!' : 'Buscaminas PRO',
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF4E342E)),
              ),
              if (!isPro)
                const Text(Catalog.proPrice, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF5D4037))),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final b in benefits)
          Card(
            child: ListTile(
              leading: Text(b.$1, style: const TextStyle(fontSize: 28)),
              title: Text(b.$2, style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text(b.$3),
              trailing: isPro ? const Icon(Icons.check_circle_rounded, color: Color(0xFF43A047)) : null,
            ),
          ),
        const SizedBox(height: 16),
        if (isPro)
          OutlinedButton(onPressed: () => _cancel(context), child: const Text('Cancelar suscripción'))
        else
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFFA000)),
            onPressed: () => _subscribe(context),
            child: const Text('Hacerme PRO'),
          ),
      ],
    );
  }
}
