import 'package:flutter/material.dart';
import '../../repositories/asistencia_repository.dart';

class MisDeportesScreen extends StatefulWidget {
  final String deporteId;

  const MisDeportesScreen({super.key, this.deporteId = 'futbol'});

  @override
  State<MisDeportesScreen> createState() => _MisDeportesScreenState();
}

class _MisDeportesScreenState extends State<MisDeportesScreen> {
  final AsistenciaRepository _asistenciaRepo = AsistenciaRepository();
  DateTime fechaSeleccionada = DateTime.now();
  Map<String, bool> estadosAsistencia = {};
  bool guardando = false;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Módulo Entrenador - ${widget.deporteId.toUpperCase()}'),
          backgroundColor: const Color(0xFF2E7D32),
          foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.check_box), text: 'Asistencia (RF-14/15)'),
              Tab(icon: Icon(Icons.analytics), text: 'Historial (RF-16)'),
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
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _asistenciaRepo.obtenerEstudiantesInscritos(widget.deporteId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No hay estudiantes inscritos.'));
        }

        final estudiantes = snapshot.data!;

        for (var est in estudiantes) {
          estadosAsistencia.putIfAbsent(est['id'], () => true);
        }

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Fecha: ${fechaSeleccionada.day}/${fechaSeleccionada.month}/${fechaSeleccionada.year}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: fechaSeleccionada,
                        firstDate: DateTime(2024),
                        lastDate: DateTime(2030),
                      );
                      if (date != null)
                        setState(() => fechaSeleccionada = date);
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: const Text('Cambiar fecha'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: estudiantes.length,
                  itemBuilder: (context, index) {
                    final est = estudiantes[index];
                    final estId = est['id'];

                    return Card(
                      child: CheckboxListTile(
                        title: Text(est['nombre'] ?? 'Sin nombre'),
                        subtitle: Text(
                            'Carnet: ${est['carnet'] ?? est['cedula'] ?? 'N/A'}'),
                        value: estadosAsistencia[estId] ?? true,
                        onChanged: (val) {
                          setState(
                              () => estadosAsistencia[estId] = val ?? false);
                        },
                      ),
                    );
                  },
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: guardando
                    ? null
                    : () async {
                        setState(() => guardando = true);
                        await _asistenciaRepo.registrarAsistencia(
                          deporteId: widget.deporteId,
                          fecha: fechaSeleccionada,
                          asistenciaMap: estadosAsistencia,
                        );
                        setState(() => guardando = false);

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Asistencia guardada en Firestore')),
                          );
                        }
                      },
                child: guardando
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Guardar Asistencia (RF-15)',
                        style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
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
                final estId = est['id'];
                final porcentaje = porcentajes[estId] ?? 0.0;

                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(est['nombre'] ?? 'Sin nombre'),
                    subtitle: Text('Carnet: ${est['carnet'] ?? 'N/A'}'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$porcentaje%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: porcentaje >= 75 ? Colors.green : Colors.red,
                          ),
                        ),
                        const Text('Asistencia',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
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
