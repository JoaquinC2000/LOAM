import 'package:flutter/material.dart';

/// Pago simulado. Imita el flujo de una compra dentro de la app:
/// elegir medio de pago → confirmar → procesando → listo.
/// No se cobra nada: es solo para mostrar la monetización.
///
/// Devuelve true si la "compra" se completó.
Future<bool> showPaymentSheet(BuildContext context, {required String product, required String price}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => _PaymentSheet(product: product, price: price),
  );
  return result ?? false;
}

enum _Step { choose, processing, done }

class _PaymentSheet extends StatefulWidget {
  const _PaymentSheet({required this.product, required this.price});
  final String product;
  final String price;

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  _Step step = _Step.choose;
  int method = 0;

  static const _methods = [
    (Icons.credit_card_rounded, 'Tarjeta de crédito', '•••• 4242'),
    (Icons.account_balance_wallet_rounded, 'Billetera virtual', 'Saldo disponible'),
    (Icons.card_giftcard_rounded, 'Tarjeta de regalo', 'Código canjeado'),
  ];

  Future<void> _pay() async {
    setState(() => step = _Step.processing);
    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;
    setState(() => step = _Step.done);
    await Future.delayed(const Duration(milliseconds: 1100));
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: switch (step) {
          _Step.choose => _buildChoose(context),
          _Step.processing => _buildProcessing(),
          _Step.done => _buildDone(),
        },
      ),
    );
  }

  Widget _buildChoose(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      key: const ValueKey('choose'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Confirmar compra', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              Expanded(child: Text(widget.product, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
              Text(widget.price, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text('Medio de pago', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        for (var i = 0; i < _methods.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            onTap: () => setState(() => method = i),
            leading: Icon(_methods[i].$1),
            title: Text(_methods[i].$2),
            subtitle: Text(_methods[i].$3),
            trailing: Icon(
              method == i ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: method == i ? scheme.primary : null,
            ),
          ),
        const SizedBox(height: 12),
        FilledButton(onPressed: _pay, child: Text('Pagar ${widget.price}')),
        const SizedBox(height: 8),
        Text(
          '🧪 Compra simulada: no se cobra dinero real.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildProcessing() {
    return const SizedBox(
      key: ValueKey('processing'),
      height: 220,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text('Procesando pago...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildDone() {
    return SizedBox(
      key: const ValueKey('done'),
      height: 220,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 500),
            curve: Curves.elasticOut,
            builder: (context, v, child) => Transform.scale(scale: v, child: child),
            child: const CircleAvatar(
              radius: 40,
              backgroundColor: Color(0xFF43A047),
              child: Icon(Icons.check_rounded, color: Colors.white, size: 48),
            ),
          ),
          const SizedBox(height: 16),
          const Text('¡Compra exitosa!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
