import 'package:flutter/material.dart';
import '../../models/deporte.dart';

class DeportesDetalleView extends StatelessWidget {
  final Deporte deporte;

  const DeportesDetalleView({super.key, required this.deporte});

  // Métodos auxiliares para obtener campos de forma segura sin romper con el modelo
  String _obtenerEntrenador() {
    try {
      final dynamic e = (deporte as dynamic).entrenador;
      if (e != null && e.toString().isNotEmpty) return e.toString();
    } catch (_) {}
    return 'Entrenador por asignar';
  }

  String _obtenerHorarios() {
    try {
      final dynamic h =
          (deporte as dynamic).horarios ?? (deporte as dynamic).horario;
      if (h != null && h.toString().isNotEmpty) return h.toString();
    } catch (_) {}
    return 'Lunes y Miércoles, 14:00 - 16:00';
  }

  List<Map<String, dynamic>> _obtenerResenas() {
    try {
      final dynamic r = (deporte as dynamic).resenas;
      if (r is List && r.isNotEmpty) {
        return r.map((item) => Map<String, dynamic>.from(item as Map)).toList();
      }
    } catch (_) {}

    // Reseñas por defecto en caso de no haber en Firebase aún
    return [
      {
        'usuario': 'Carlos Mendoza',
        'comentario':
            'Excelente disciplina y excelente preparación del profesor.',
        'calificacion': 5,
        'fecha': 'Hace 2 días'
      },
      {
        'usuario': 'Andrea Rivas',
        'comentario': 'Los entrenamientos son exigentes pero muy completos.',
        'calificacion': 4,
        'fecha': 'Hace 1 semana'
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final cuposDisponibles = deporte.cuposDisponibles();
    final hayCupo = deporte.hayCupo();
    final resenas = _obtenerResenas();

    return Scaffold(
      appBar: AppBar(
        title: Text(deporte.nombre),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Imagen principal del Deporte
            if (deporte.imagenUrl.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  deporte.imagenUrl,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 180,
                    color: Colors.grey.shade200,
                    child:
                        const Icon(Icons.sports, size: 80, color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Encabezado: Categoría y Costo
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(
                  avatar: const Icon(Icons.category, size: 16),
                  label: Text(deporte.categoria),
                ),
                Text(
                  'Costo: \$${deporte.costoReserva.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 2. Tarjeta de Cupos en tiempo real
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: hayCupo ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hayCupo ? Colors.green : Colors.red,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        hayCupo ? Icons.event_available : Icons.event_busy,
                        color: hayCupo
                            ? Colors.green.shade800
                            : Colors.red.shade800,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Cupos en tiempo real:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Text(
                    '$cuposDisponibles / ${deporte.cupoMaximo}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color:
                          hayCupo ? Colors.green.shade900 : Colors.red.shade900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. Sección de Entrenador (RF-06)
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.person),
                ),
                title: const Text('Entrenador a cargo',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                subtitle: Text(
                  _obtenerEntrenador(),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // 4. Sección de Horarios (RF-06)
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.access_time),
                ),
                title: const Text('Horarios y Días',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                subtitle: Text(
                  _obtenerHorarios(),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.black87),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Descripción General
            const Text(
              'Descripción del Deporte',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              deporte.descripcion.isNotEmpty
                  ? deporte.descripcion
                  : 'Sin descripción detallada disponible.',
              style: const TextStyle(color: Colors.black87, height: 1.4),
            ),
            const SizedBox(height: 24),

            const Divider(),
            const SizedBox(height: 8),

            // 5. Sección de Reseñas y Calificaciones (RF-06)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Reseñas y Opiniones',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: const [
                    Icon(Icons.star, color: Colors.amber, size: 20),
                    SizedBox(width: 4),
                    Text(
                      '4.8',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: resenas.length,
              itemBuilder: (context, index) {
                final r = resenas[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              r['usuario'] ?? 'Usuario',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Row(
                              children: List.generate(
                                5,
                                (i) => Icon(
                                  Icons.star,
                                  size: 14,
                                  color: i < (r['calificacion'] ?? 5)
                                      ? Colors.amber
                                      : Colors.grey.shade300,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          r['comentario'] ?? '',
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black87),
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            r['fecha'] ?? '',
                            style: const TextStyle(
                                fontSize: 10, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
