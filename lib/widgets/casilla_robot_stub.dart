import 'package:flutter/material.dart';

/// Fuera de la web no hay reCAPTCHA: la casilla no se dibuja y se da por marcada.
class CasillaRobot extends StatefulWidget {
  const CasillaRobot({super.key, required this.alCambiar});

  /// Avisa con `true` cuando la persona pasa la comprobación y con `false` si caduca.
  final ValueChanged<bool> alCambiar;

  @override
  State<CasillaRobot> createState() => _CasillaRobotState();
}

class _CasillaRobotState extends State<CasillaRobot> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.alCambiar(true);
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
