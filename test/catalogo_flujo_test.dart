import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:saman_deportivo/main.dart';

import 'falsos/auth_repository_falso.dart';
import 'falsos/deporte_repository_falso.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<DeporteRepositoryFalso> abrirCatalogo(WidgetTester tester, {Size tamano = const Size(1280, 900)}) async {
    tester.view.physicalSize = tamano;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final deportes = DeporteRepositoryFalso.conDatosDePrueba();
    await tester.pumpWidget(SamanDeportivoApp(repositorio: AuthRepositoryFalso.conDatosDePrueba(), deportes: deportes));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver deportes sin iniciar sesión'));
    await tester.pumpAndSettle();
    return deportes;
  }

  testWidgets('un visitante ve el catálogo con cupos y horarios sin iniciar sesión', (tester) async {
    await abrirCatalogo(tester);
    expect(find.text('Catálogo de deportes'), findsOneWidget);
    expect(find.text('3 disciplinas'), findsOneWidget);
    expect(find.text('5 de 25 cupos libres'), findsOneWidget);
    expect(find.text('Sin cupos'), findsOneWidget);
    expect(find.text('Martes 16:00 - 18:00'), findsOneWidget);
    expect(find.text('Natación'), findsNothing);
  });

  testWidgets('busca sin acentos, filtra y limpia los filtros', (tester) async {
    await abrirCatalogo(tester);
    await tester.enterText(find.byType(TextField), 'futbol');
    await tester.pumpAndSettle();
    expect(find.text('1 disciplina'), findsOneWidget);
    expect(find.text('Fútbol'), findsOneWidget);

    await tester.tap(find.byTooltip('Filtros'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Sábado'));
    await tester.pumpAndSettle();
    expect(find.text('Ver 0 resultados'), findsOneWidget);
    await tester.tap(find.text('Ver 0 resultados'));
    await tester.pumpAndSettle();
    expect(find.text('No encontramos disciplinas con esos filtros.'), findsOneWidget);

    await tester.tap(find.text('Limpiar filtros'));
    await tester.pumpAndSettle();
    expect(find.text('3 disciplinas'), findsOneWidget);
  });

  testWidgets('el detalle muestra entrenador, horarios, costo y reseñas, y los cupos cambian en vivo', (tester) async {
    final deportes = await abrirCatalogo(tester);
    await tester.tap(find.text('Fútbol'));
    await tester.pumpAndSettle();
    expect(find.text('Entrenador Prueba'), findsOneWidget);
    expect(find.text('Fútbol · 8 años de experiencia'), findsOneWidget);
    expect(find.text('Jueves 16:00 - 18:00'), findsOneWidget);
    expect(find.text('Reserva del cupo: \$5.00'), findsOneWidget);
    expect(find.text('4.5'), findsOneWidget);
    expect(find.text('Muy buen ambiente.'), findsOneWidget);
    expect(find.text('5 de 25 cupos libres'), findsOneWidget);

    deportes.cambiarCupos('FUT-01', 25);
    await tester.pumpAndSettle();
    expect(find.text('Sin cupos'), findsOneWidget);
  });

  testWidgets('en el teléfono el catálogo se ve en una columna sin desbordarse', (tester) async {
    await abrirCatalogo(tester, tamano: const Size(390, 844));
    expect(find.text('Fútbol'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
