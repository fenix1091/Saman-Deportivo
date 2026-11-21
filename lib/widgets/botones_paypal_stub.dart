import 'package:flutter/material.dart';

/// Fuera de la web no hay SDK de PayPal: se usa la pasarela simulada.
bool get payPalDisponible => false;

/// Sin SDK de PayPal no dibuja nada (ver [payPalDisponible]).
class BotonesPayPal extends StatelessWidget {
  const BotonesPayPal({
    super.key,
    required this.monto,
    required this.concepto,
    required this.antesDeCobrar,
    required this.alAprobar,
    required this.alFallar,
    required this.alCancelar,
  });

  final double monto;
  final String concepto;
  final Future<String?> Function() antesDeCobrar;
  final Future<void> Function(String referencia) alAprobar;
  final ValueChanged<String> alFallar;
  final VoidCallback alCancelar;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
