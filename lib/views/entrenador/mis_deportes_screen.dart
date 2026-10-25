import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../repositories/asistencia_repository.dart';
import '../../viewmodels/auth_view_model.dart';

class MisDeportesScreen extends StatefulWidget {
  final String deporteId;

  final AsistenciaRepository? repositorio;

  const MisDeportesScreen(
      {super.key, required this.deporteId, this.repositorio});

  @override
  State<MisDeportesScreen> createState() => _MisDeportesScreenState();
}

class _MisDeportesScreenState extends State<MisDeportesScreen> {
  late final AsistenciaRepository _asistenciaRepo =
      widget.repositorio ?? AsistenciaRepository();
  DateTime _fechaSeleccionada = DateTime.now();
  final Map<String, bool> _asistenciaMap = {};

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Gestión de Asistencia - ${widget.deporteId}'),
          actions: [
            IconButton(
              tooltip: 'Mi perfil',
              icon: const Icon(Icons.account_circle_outlined),
              onPressed: () => context.push('/perfil'),
            ),
            IconButton(
              tooltip: 'Cerrar sesión',
              icon: const Icon(Icons.logout),
              onPressed: () => context.read<AuthViewModel>().cerrarSesion(),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(
                  icon: Icon(Icons.check_circle_outline),
                  text: 'Tomar Asistencia'),
              Tab(icon: Icon(Icons.bar_chart), text: 'Historial'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            buildAsistenciaTab(),
            buildHistorialTab(),
          ],
        ),
      ),
    );
  }

  Widget buildAsistenciaTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Fecha: ${_fechaSeleccionada.year}-${_fechaSeleccionada.month.toString().padLeft(2, '0')}-${_fechaSeleccionada.day.toString().padLeft(2, '0')}',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.calendar_today),
                label: const Text('Cambiar Fecha'),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _fechaSeleccionada,
                    firstDate: DateTime(2024),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() {
                      _fechaSeleccionada = picked;
                      _asistenciaMap.clear();
                    });
                  }
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream:
                _asistenciaRepo.obtenerEstudiantesInscritos(widget.deporteId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                    child: Text('No hay estudiantes inscritos.'));
              }

              final estudiantes = snapshot.data!;

              return ListView.builder(
                itemCount: estudiantes.length,
                itemBuilder: (context, index) {
                  final est = estudiantes[index];
                  final uid = est['id'] as String;
                  final nombre = est['nombre'] ?? 'Estudiante';
                  final carnet = est['carnet'] ?? 'Sin Carnet';
                  final bool estaPresente = _asistenciaMap[uid] ?? false;

                  return CheckboxListTile(
                    title: Text(nombre),
                    subtitle: Text('Carnet: $carnet'),
                    value: estaPresente,
                    onChanged: (val) {
                      setState(() {
                        _asistenciaMap[uid] = val ?? false;
                      });
                    },
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () async {
                try {
                  await _asistenciaRepo.registrarAsistencia(
                    deporteId: widget.deporteId,
                    fecha: _fechaSeleccionada,
                    asistenciaMap: _asistenciaMap,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('Asistencia guardada y actualizada con éxito'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error al guardar: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Guardar Asistencia',
                  style: TextStyle(color: Colors.white, fontSize: 18)),
            ),
          ),
        )
      ],
    );
  }

  Widget buildHistorialTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _asistenciaRepo.obtenerEstudiantesInscritos(widget.deporteId),
      builder: (context, estSnapshot) {
        if (!estSnapshot.hasData)
          return const Center(child: CircularProgressIndicator());

        return StreamBuilder<Map<String, double>>(
          stream:
              _asistenciaRepo.obtenerPorcentajesAsistencia(widget.deporteId),
          builder: (context, pctSnapshot) {
            final estudiantes = estSnapshot.data!;
            final porcentajes = pctSnapshot.data ?? {};

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: estudiantes.length,
              itemBuilder: (context, index) {
                final est = estudiantes[index];
                final uid = est['id'] as String;
                final nombre = est['nombre'] ?? 'Estudiante';
                final carnet = est['carnet'] ?? 'Sin Carnet';
                final pct = porcentajes[uid] ?? 0.0;

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: pct >= 75 ? Colors.green : Colors.orange,
                      child: Text('${pct.toInt()}%',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12)),
                    ),
                    title: Text(nombre),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Carnet: $carnet'),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: pct / 100,
                          backgroundColor: Colors.grey[200],
                          color: pct >= 75 ? Colors.green : Colors.orange,
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
