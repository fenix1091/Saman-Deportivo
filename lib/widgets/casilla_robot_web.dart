// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

/// Clave pública de la casilla en reCAPTCHA Enterprise (tipo "casilla de verificación").
const _claveCasilla = '6LespRguAAAAAP5Spz9JOQHlJoXrtZiXt2WlTsBj';

const _guion = 'https://www.google.com/recaptcha/enterprise.js?render=explicit&hl=es';

/// Casilla "No soy un robot" de reCAPTCHA (solo web).
///
/// Si reCAPTCHA no llega a cargar (red de la universidad, bloqueador de anuncios),
/// a los pocos segundos se da por marcada para no dejar a nadie sin registrarse.
class CasillaRobot extends StatefulWidget {
  const CasillaRobot({super.key, required this.alCambiar});

  /// Avisa con `true` cuando la persona pasa la comprobación y con `false` si caduca.
  final ValueChanged<bool> alCambiar;

  @override
  State<CasillaRobot> createState() => _CasillaRobotState();
}

class _CasillaRobotState extends State<CasillaRobot> {
  static int _siguiente = 0;
  static const _espera = Duration(seconds: 8);

  late final String _tipo = 'casilla-robot-${_siguiente++}';
  final _caja = html.DivElement();
  Timer? _sondeo;
  DateTime _inicio = DateTime.now();
  bool _dibujada = false;
  bool _sinServicio = false;

  @override
  void initState() {
    super.initState();
    ui_web.platformViewRegistry.registerViewFactory(_tipo, (int id) => _caja);
    _cargarGuion();
    _inicio = DateTime.now();
    _sondeo = Timer.periodic(const Duration(milliseconds: 250), (_) => _intentar());
  }

  /// App Check ya carga el guion de reCAPTCHA Enterprise; solo se añade si falta.
  void _cargarGuion() {
    final yaEsta = html.document
        .querySelectorAll('script')
        .any((s) => (s.getAttribute('src') ?? '').contains('recaptcha/enterprise.js'));
    if (yaEsta) return;
    html.document.head!.append(html.ScriptElement()
      ..src = _guion
      ..async = true
      ..defer = true);
  }

  js.JsObject? get _recaptcha {
    final g = js.context['grecaptcha'];
    if (g is! js.JsObject) return null;
    final e = g['enterprise'];
    return e is js.JsObject && e.hasProperty('render') ? e : null;
  }

  void _intentar() {
    if (!mounted || _dibujada) return _sondeo?.cancel();
    final e = _recaptcha;
    if (e != null && (_caja.isConnected ?? false)) {
      _dibujada = true;
      _sondeo?.cancel();
      try {
        final opciones = js.JsObject(js.context['Object'] as js.JsFunction)
          ..['sitekey'] = _claveCasilla
          ..['callback'] = ((dynamic _) => _avisar(true))
          ..['expired-callback'] = (() => _avisar(false))
          ..['error-callback'] = _rendirse;
        e.callMethod('render', [_caja, opciones]);
      } catch (_) {
        _rendirse();
      }
      return;
    }
    if (DateTime.now().difference(_inicio) > _espera) {
      _sondeo?.cancel();
      _rendirse();
    }
  }

  void _avisar(bool marcada) {
    if (mounted) widget.alCambiar(marcada);
  }

  void _rendirse() {
    if (!mounted) return;
    setState(() => _sinServicio = true);
    widget.alCambiar(true);
  }

  @override
  void dispose() {
    _sondeo?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_sinServicio) return const SizedBox.shrink();
    // La casilla estándar de reCAPTCHA mide 304 × 78 px.
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(width: 304, height: 78, child: HtmlElementView(viewType: _tipo)),
    );
  }
}
