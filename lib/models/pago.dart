import 'conversion.dart';

enum EstadoPago { pendiente, completado, fallido, reembolsado }

/// Pago de la reserva de un cupo con PayPal. Se guarda en `pagos/{id}`.
///
/// Solo se guarda la referencia de PayPal, nunca los datos de la tarjeta.
class Pago {
  const Pago({
    required this.id,
    required this.inscripcionId,
    required this.monto,
    this.moneda = 'USD',
    this.metodo = 'PayPal',
    this.referenciaExterna = '',
    required this.fecha,
    this.estado = EstadoPago.pendiente,
  });

  final String id;
  final String inscripcionId;
  final double monto;
  final String moneda;
  final String metodo;

  /// Id de la orden en PayPal.
  final String referenciaExterna;
  final DateTime fecha;
  final EstadoPago estado;

  Map<String, dynamic> aMapa() => {
        'inscripcionId': inscripcionId,
        'monto': monto,
        'moneda': moneda,
        'metodo': metodo,
        'referenciaExterna': referenciaExterna,
        'fecha': fecha,
        'estado': estado.name,
      };

  factory Pago.desdeMapa(String id, Map<String, dynamic> mapa) => Pago(
        id: id,
        inscripcionId: mapa['inscripcionId'] as String,
        monto: (mapa['monto'] as num).toDouble(),
        moneda: mapa['moneda'] as String? ?? 'USD',
        metodo: mapa['metodo'] as String? ?? 'PayPal',
        referenciaExterna: mapa['referenciaExterna'] as String? ?? '',
        fecha: leerFecha(mapa['fecha']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        estado: EstadoPago.values.byName(mapa['estado'] as String? ?? 'pendiente'),
      );
}
