// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:math' as math;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

/// Client ID de la app de PayPal en modo sandbox (developer.paypal.com > Apps &
/// Credentials > Sandbox). Es público: PayPal lo pide en el navegador. La clave
/// secreta nunca va en la app. Se puede cambiar al compilar con
/// `--dart-define=PAYPAL_CLIENT_ID=...`.
const _clienteSandbox = String.fromEnvironment(
  'PAYPAL_CLIENT_ID',
  defaultValue: 'BAAjrWW3cNXlQoOTZnqodelsIsnvCRRzkxQONFQXSJZRtzEuWkxJoQvIGbjK1Qf1ee-ayiAph5LcCygX6w',
);

/// Hay SDK de PayPal en la web siempre que exista un Client ID.
bool get payPalDisponible => _clienteSandbox.isNotEmpty;

String get _guion => 'https://www.paypal.com/sdk/js?client-id=$_clienteSandbox'
    '&currency=USD&intent=capture&locale=es_ES&disable-funding=paylater,venmo';

/// Botones de PayPal dibujados con su SDK dentro de la ventana de pago.
///
/// Al pulsar uno, [antesDeCobrar] aparta el cupo y devuelve el id de la reserva
/// (o `null` si no se puede); con eso se crea la orden en PayPal. Cuando el
/// estudiante aprueba, la orden se captura y [alAprobar] recibe el id de la
/// transacción de PayPal, que es lo que se guarda en el pago.
class BotonesPayPal extends StatefulWidget {
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
  State<BotonesPayPal> createState() => _BotonesPayPalState();
}

class _BotonesPayPalState extends State<BotonesPayPal> {
  static int _siguiente = 0;
  static const _espera = Duration(seconds: 15);

  late final String _tipo = 'botones-paypal-${_siguiente++}';
  final _caja = html.DivElement()..style.width = '100%';
  Timer? _sondeo;
  final DateTime _inicio = DateTime.now();
  bool _dibujados = false;
  double _alto = 160;

  @override
  void initState() {
    super.initState();
    ui_web.platformViewRegistry.registerViewFactory(_tipo, (int id) => _caja);
    _cargarGuion();
    _sondeo = Timer.periodic(const Duration(milliseconds: 250), (_) => _intentar());
  }

  void _cargarGuion() {
    if (html.document.getElementById('sdk-paypal') != null) return;
    html.document.head!.append(html.ScriptElement()
      ..id = 'sdk-paypal'
      ..src = _guion
      ..async = true);
  }

  js.JsObject? get _paypal {
    final p = js.context['paypal'];
    return p is js.JsObject && p.hasProperty('Buttons') ? p : null;
  }

  void _intentar() {
    if (!mounted) {
      _sondeo?.cancel();
      return;
    }
    if (_dibujados) {
      // Los botones (y el formulario de tarjeta) cambian de alto: la caja los sigue.
      final alto = math.max(160, _caja.scrollHeight).toDouble();
      if ((alto - _alto).abs() > 2) setState(() => _alto = alto);
      return;
    }
    final paypal = _paypal;
    if (paypal != null && (_caja.isConnected ?? false)) {
      _dibujados = true;
      try {
        (paypal.callMethod('Buttons', [_opciones()]) as js.JsObject).callMethod('render', [_caja]);
      } catch (_) {
        _sondeo?.cancel();
        widget.alFallar('No se pudieron mostrar los botones de PayPal.');
      }
      return;
    }
    if (DateTime.now().difference(_inicio) > _espera) {
      _sondeo?.cancel();
      widget.alFallar('No se pudo cargar PayPal. Revisa tu conexión o desactiva el bloqueador de anuncios.');
    }
  }

  js.JsObject _opciones() {
    final opciones = js.JsObject.jsify({
      'style': {'layout': 'vertical', 'color': 'gold', 'shape': 'rect', 'label': 'pay', 'height': 45},
    });
    opciones['createOrder'] = ([dynamic _, dynamic acciones]) => _promesa(() async {
          final reserva = await widget.antesDeCobrar();
          if (reserva == null) throw StateError('sin reserva');
          final orden = js.JsObject.jsify({
            'purchase_units': [
              {
                'custom_id': reserva,
                'description': widget.concepto.length > 120 ? widget.concepto.substring(0, 120) : widget.concepto,
                'amount': {'currency_code': 'USD', 'value': widget.monto.toStringAsFixed(2)},
              }
            ],
            'application_context': {'brand_name': 'Samán Deportivo', 'shipping_preference': 'NO_SHIPPING'},
          });
          final pedido = (acciones as js.JsObject)['order'] as js.JsObject;
          return _futuro(pedido.callMethod('create', [orden]) as js.JsObject);
        });
    opciones['onApprove'] = ([dynamic datos, dynamic acciones]) => _promesa(() async {
          final pedido = (acciones as js.JsObject)['order'] as js.JsObject;
          final detalle = await _futuro(pedido.callMethod('capture') as js.JsObject) as js.JsObject;
          if (detalle['status'] != 'COMPLETED') {
            widget.alFallar('PayPal rechazó el pago. Revisa tu método de pago e inténtalo de nuevo.');
            return null;
          }
          final orden = (datos as js.JsObject)['orderID'] as String? ?? detalle['id'] as String;
          await widget.alAprobar(_idTransaccion(detalle) ?? orden);
          return null;
        });
    opciones['onCancel'] = ([dynamic _]) => widget.alCancelar();
    opciones['onError'] = ([dynamic _]) => widget.alFallar('PayPal no pudo completar el pago. Inténtalo de nuevo.');
    return opciones;
  }

  /// Id de la transacción (captura) que el comercio ve en su actividad de PayPal.
  String? _idTransaccion(js.JsObject detalle) {
    try {
      final unidad = (detalle['purchase_units'] as js.JsArray).first as js.JsObject;
      final capturas = (unidad['payments'] as js.JsObject)['captures'] as js.JsArray;
      return (capturas.first as js.JsObject)['id'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Convierte un trabajo de Dart en una promesa de JavaScript para el SDK.
  js.JsObject _promesa(Future<Object?> Function() trabajo) => js.JsObject(js.context['Promise'] as js.JsFunction, [
        (js.JsFunction resolver, js.JsFunction rechazar) {
          trabajo().then((v) => resolver.apply([v]), onError: (Object e) => rechazar.apply([e.toString()]));
        }
      ]);

  /// Espera una promesa de JavaScript desde Dart.
  Future<Object?> _futuro(js.JsObject promesa) {
    final c = Completer<Object?>();
    promesa.callMethod('then', [
      (dynamic v) => c.complete(v),
      (dynamic e) => c.completeError(e ?? 'error'),
    ]);
    return c.future;
  }

  @override
  void dispose() {
    _sondeo?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(height: _alto, child: HtmlElementView(viewType: _tipo));
}
