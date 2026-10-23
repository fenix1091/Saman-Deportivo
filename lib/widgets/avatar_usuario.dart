import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Foto de perfil circular; si no hay foto muestra las iniciales del nombre.
///
/// Acepta una URL normal (Cloud Storage) o una data URL (repositorio local),
/// y [bytes] para previsualizar una foto que todavía no se ha guardado.
class AvatarUsuario extends StatelessWidget {
  const AvatarUsuario({super.key, required this.nombre, this.fotoUrl = '', this.bytes, this.radio = 48});

  final String nombre;
  final String fotoUrl;
  final Uint8List? bytes;
  final double radio;

  ImageProvider? get _imagen {
    if (bytes != null) return MemoryImage(bytes!);
    if (fotoUrl.startsWith('data:')) return MemoryImage(UriData.parse(fotoUrl).contentAsBytes());
    if (fotoUrl.isNotEmpty) return NetworkImage(fotoUrl);
    return null;
  }

  String get _iniciales {
    final partes = nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    return partes.take(2).map((p) => p[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final imagen = _imagen;
    return CircleAvatar(
      radius: radio,
      backgroundColor: esquema.primaryContainer,
      foregroundImage: imagen,
      child: imagen == null
          ? Text(_iniciales, style: TextStyle(fontSize: radio * 0.7, color: esquema.onPrimaryContainer))
          : null,
    );
  }
}
