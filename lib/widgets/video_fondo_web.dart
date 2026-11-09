// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

/// Video de YouTube como fondo (solo web): silenciado, en bucle, sin controles y
/// sin recibir clics, recortado para cubrir toda la caja como una foto.
class VideoFondo extends StatefulWidget {
  const VideoFondo({super.key, required this.videoId, this.inicio = 0});

  final String videoId;

  /// Segundo en el que arranca el video.
  final int inicio;

  @override
  State<VideoFondo> createState() => _VideoFondoState();
}

class _VideoFondoState extends State<VideoFondo> {
  static final _registrados = <String>{};
  static final _iframes = <String, html.IFrameElement>{};

  String get _tipo => 'video-fondo-${widget.videoId}-${widget.inicio}';

  @override
  void initState() {
    super.initState();
    if (_registrados.add(_tipo)) {
      ui_web.platformViewRegistry.registerViewFactory(_tipo, (int id) {
        final caja = html.DivElement()
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.overflow = 'hidden'
          ..style.position = 'relative'
          ..style.backgroundColor = '#C2410C'
          ..style.pointerEvents = 'none';
        final v = widget.videoId;
        final iframe = html.IFrameElement()
          ..src = 'https://www.youtube-nocookie.com/embed/$v'
              '?autoplay=1&mute=1&loop=1&playlist=$v&controls=0&start=${widget.inicio}'
              '&modestbranding=1&playsinline=1&rel=0&iv_load_policy=3&disablekb=1&fs=0'
          ..allow = 'autoplay; encrypted-media; picture-in-picture'
          ..title = 'Video de fondo'
          ..tabIndex = -1
          ..style.border = '0'
          ..style.position = 'absolute'
          ..style.pointerEvents = 'none';
        iframe.setAttribute('frameborder', '0');
        iframe.setAttribute('aria-hidden', 'true');
        caja.append(iframe);
        _iframes[_tipo] = iframe;
        return caja;
      });
    }
  }

  /// Ajusta el iframe para cubrir la caja manteniendo 16:9 (como `object-fit: cover`).
  void _cubrir(double ancho, double alto) {
    final iframe = _iframes[_tipo];
    if (iframe == null || ancho <= 0 || alto <= 0) return;
    var w = ancho;
    var h = w * 9 / 16;
    if (h < alto) {
      h = alto;
      w = h * 16 / 9;
    }
    // Un poco más grande para tapar la franja negra y el título que YouTube pinta arriba.
    w *= 1.12;
    h *= 1.12;
    iframe.style
      ..width = '${w.round()}px'
      ..height = '${h.round()}px'
      ..left = '${((ancho - w) / 2).round()}px'
      ..top = '${((alto - h) / 2).round()}px';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _cubrir(c.maxWidth, c.maxHeight));
        return IgnorePointer(child: HtmlElementView(viewType: _tipo));
      },
    );
  }
}
