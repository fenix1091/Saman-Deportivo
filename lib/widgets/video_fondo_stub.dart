import 'package:flutter/material.dart';

/// En las plataformas que no son web no hay iframe: no se dibuja nada y la
/// portada se queda con su degradado naranja.
class VideoFondo extends StatelessWidget {
  const VideoFondo({super.key, required this.videoId, this.inicio = 0});

  final String videoId;
  final int inicio;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
