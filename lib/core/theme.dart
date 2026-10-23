import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colores de la marca Samán Deportivo (ver design/marca/paleta.png).
class AppColors {
  static const verdeSaman = Color(0xFF1F5E3A);
  static const verdeHoja = Color(0xFF2E8B57);
  static const verdeClaro = Color(0xFFE6F2EA);
  static const naranja = Color(0xFFF28C28);
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
      seedColor: AppColors.verdeHoja,
      primary: AppColors.verdeHoja,
      secondary: AppColors.naranja,
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
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}
