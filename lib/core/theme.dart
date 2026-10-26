import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colores de la marca Samán Deportivo. El naranja es el color principal (hoja
/// Foundations del Figma); el verde queda para lo que salió bien y para el logo.
class AppColors {
  static const verdeSaman = Color(0xFF1F5E3A);
  static const verdeHoja = Color(0xFF2E8B57);
  static const verdeClaro = Color(0xFFE6F2EA);
  static const naranja = Color(0xFFF58220);
  static const naranjaClaro = Color(0xFFFDEBD7);
  static const azul = Color(0xFF1B3A6B);
  static const rojo = Color(0xFFC8433A);
  static const texto = Color(0xFF1C2321);
  static const gris = Color(0xFF6B7A72);
  static const fondo = Color(0xFFF6F8F6);
}

/// Tema de la aplicación: Poppins para títulos e Inter para textos.
ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.naranja,
      primary: AppColors.naranja,
      onPrimary: Colors.white,
      secondary: AppColors.verdeHoja,
      tertiary: AppColors.azul,
      error: AppColors.rojo,
    ),
    scaffoldBackgroundColor: AppColors.fondo,
  );
  return base.copyWith(
    textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
      headlineMedium: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: AppColors.texto),
      titleLarge: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppColors.texto),
    ),
    // Los mensajes de ayuda y de error de los formularios no se cortan en el teléfono.
    inputDecorationTheme: const InputDecorationTheme(helperMaxLines: 3, errorMaxLines: 3),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}
