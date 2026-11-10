import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/persona.dart';
import '../../viewmodels/auth_view_model.dart';
import '../../widgets/formulario_centrado.dart';
import '../../widgets/marco_acceso.dart';

/// Paso posterior al registro: el estudiante confirma que el correo es suyo
/// abriendo el enlace que se le envió. La pantalla lo detecta sola.
///
/// Hasta que lo haga, la guardia de rutas no lo deja pasar de aquí; la reserva de
/// cupos, además, la impiden las reglas de Firestore.
class VerificarCorreoView extends StatefulWidget {
  const VerificarCorreoView({super.key, this.cadaCuanto = const Duration(seconds: 4)});

  /// Cada cuánto se consulta si el enlace ya se abrió.
  final Duration cadaCuanto;

  @override
  State<VerificarCorreoView> createState() => _VerificarCorreoViewState();
}

class _VerificarCorreoViewState extends State<VerificarCorreoView> {
  static const _esperaReenvio = 60;

  Timer? _sondeo;
  Timer? _cuenta;
  int _segundos = 0;
  bool _comprobando = false;
  bool _verificado = false;
  String? _aviso;
  bool _avisoEsError = false;

  @override
  void initState() {
    super.initState();
    final usuario = context.read<AuthViewModel>().usuario;
    _verificado = usuario is Estudiante && usuario.correoVerificado;
    if (!_verificado) {
      _sondeo = Timer.periodic(widget.cadaCuanto, (_) => _comprobar(silencioso: true));
    }
  }

  @override
  void dispose() {
    _sondeo?.cancel();
    _cuenta?.cancel();
    super.dispose();
  }

  Future<void> _comprobar({bool silencioso = false}) async {
    if (_comprobando || _verificado) return;
    _comprobando = true;
    if (!silencioso) setState(() => _aviso = null);
    final listo = await context.read<AuthViewModel>().comprobarCorreo();
    if (!mounted) return;
    _comprobando = false;
    if (listo) {
      _sondeo?.cancel();
      setState(() {
        _verificado = true;
        _aviso = null;
      });
    } else if (!silencioso) {
      setState(() {
        _aviso = 'Todavía no aparece verificado. Abre el enlace del correo y vuelve a intentarlo.';
        _avisoEsError = true;
      });
    }
  }

  Future<void> _reenviar() async {
    final error = await context.read<AuthViewModel>().reenviarVerificacion();
    if (!mounted) return;
    setState(() {
      _aviso = error ?? 'Te enviamos otro correo. Puede tardar un minuto en llegar.';
      _avisoEsError = error != null;
      _segundos = _esperaReenvio;
    });
    _cuenta?.cancel();
    _cuenta = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _segundos--);
      if (_segundos <= 0) t.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<AuthViewModel>().usuario;
    final textos = Theme.of(context).textTheme;
    if (usuario == null) return const Scaffold(body: SizedBox.shrink());
    final inicio = AuthViewModel.rutaInicio(usuario.rol);

    return MarcoAcceso(
      lema: 'Un paso más y listo',
      detalle: 'Confirmar tu correo nos asegura que las reservas y los avisos lleguen a la persona correcta.',
      conVolver: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _verificado
            ? [
                const Icon(Icons.verified_outlined, size: 64, color: AppColors.verdeHoja),
                const SizedBox(height: 16),
                Text('Correo verificado', textAlign: TextAlign.center, style: textos.headlineMedium),
                const SizedBox(height: 8),
                Text('Ya puedes reservar tu cupo en las disciplinas.',
                    textAlign: TextAlign.center, style: textos.bodyLarge),
                const SizedBox(height: 24),
                FilledButton(onPressed: () => context.go(inicio), child: const Text('Ir a mi panel')),
              ]
            : [
                const Icon(Icons.mark_email_unread_outlined, size: 64, color: AppColors.naranjaProfundo),
                const SizedBox(height: 16),
                Text('Revisa tu correo', textAlign: TextAlign.center, style: textos.headlineMedium),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Te enviamos un enlace a '),
                      TextSpan(text: usuario.correo, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const TextSpan(text: '. Ábrelo para confirmar que es tuyo y entrar; esta pantalla avanza sola.'),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  style: textos.bodyLarge,
                ),
                const SizedBox(height: 8),
                Text('Si no lo ves, revisa la carpeta de spam o correo no deseado.',
                    textAlign: TextAlign.center, style: textos.bodySmall?.copyWith(color: AppColors.gris)),
                if (_aviso != null) ...[
                  const SizedBox(height: 16),
                  if (_avisoEsError)
                    MensajeError(_aviso!)
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration:
                          BoxDecoration(color: AppColors.verdeClaro, borderRadius: BorderRadius.circular(12)),
                      child: Text(_aviso!, style: const TextStyle(color: AppColors.verdeSaman)),
                    ),
                ],
                const SizedBox(height: 24),
                FilledButton(onPressed: _comprobar, child: const Text('Ya abrí el enlace')),
                const SizedBox(height: 10),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  onPressed: _segundos > 0 ? null : _reenviar,
                  child: Text(_segundos > 0 ? 'Reenviar correo ($_segundos s)' : 'Reenviar correo'),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => context.read<AuthViewModel>().cerrarSesion(),
                  child: const Text('Cerrar sesión'),
                ),
              ],
      ),
    );
  }
}
