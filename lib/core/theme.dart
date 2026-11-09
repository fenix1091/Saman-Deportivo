import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colores de la marca Samán Deportivo. El naranja es el color principal (hoja
/// Foundations del Figma); el verde queda para lo que salió bien y para el logo.
class AppColors {
  static const verdeSaman = Color(0xFF1F5E3A);
  static const verdeHoja = Color(0xFF2E8B57);
  static const verdeClaro = Color(0xFFE6F2EA);
  static const naranja = Color(0xFFF58220);

  /// Naranja oscuro para botones y enlaces: el texto blanco se lee bien encima (5,2:1).
  static const naranjaProfundo = Color(0xFFC2410C);
  static const naranjaClaro = Color(0xFFFDEBD7);
  static const azul = Color(0xFF1B3A6B);
  static const rojo = Color(0xFFC8433A);
  static const texto = Color(0xFF1C2321);
  static const gris = Color(0xFF6B7A72);
  static const fondo = Color(0xFFF6F8F6);
  static const borde = Color(0xFFDDE3EA);
}

/// Medidas que se repiten en toda la interfaz.
class AppRadios {
  static const campo = 14.0;
  static const tarjeta = 18.0;
  static const ventana = 22.0;
}

/// Cambio de pantalla: la nueva aparece con un fundido y un desplazamiento corto.
class _TransicionSuave extends PageTransitionsBuilder {
  const _TransicionSuave();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
    final curva = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    return FadeTransition(
      opacity: curva,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.025), end: Offset.zero).animate(curva),
        child: child,
      ),
    );
  }
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

  TextStyle? titulo(TextStyle? estilo, FontWeight peso) =>
      estilo == null ? null : GoogleFonts.poppins(textStyle: estilo, fontWeight: peso, color: AppColors.texto);

  final inter = GoogleFonts.interTextTheme(base.textTheme);
  final textos = inter.copyWith(
    displayLarge: titulo(inter.displayLarge, FontWeight.w700),
    displayMedium: titulo(inter.displayMedium, FontWeight.w700),
    displaySmall: titulo(inter.displaySmall, FontWeight.w700),
    headlineLarge: titulo(inter.headlineLarge, FontWeight.w700),
    headlineMedium: titulo(inter.headlineMedium, FontWeight.w700),
    headlineSmall: titulo(inter.headlineSmall, FontWeight.w700),
    titleLarge: titulo(inter.titleLarge, FontWeight.w600),
    titleMedium: titulo(inter.titleMedium, FontWeight.w600),
  );

  OutlineInputBorder borde(Color color, [double grosor = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadios.campo),
        borderSide: BorderSide(color: color, width: grosor),
      );

  final formaBoton = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadios.campo));
  const transicion = _TransicionSuave();

  return base.copyWith(
    textTheme: textos,
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {for (final plataforma in TargetPlatform.values) plataforma: transicion},
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.fondo,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      titleTextStyle: textos.titleLarge,
    ),
    // Campos rellenos con borde suave; los mensajes de ayuda y de error no se cortan en el teléfono.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      helperMaxLines: 3,
      errorMaxLines: 3,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: borde(AppColors.borde),
      enabledBorder: borde(AppColors.borde),
      focusedBorder: borde(AppColors.naranja, 2),
      errorBorder: borde(AppColors.rojo),
      focusedErrorBorder: borde(AppColors.rojo, 2),
      floatingLabelStyle: const TextStyle(color: AppColors.naranjaProfundo, fontWeight: FontWeight.w600),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.naranjaProfundo,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(50),
        shape: formaBoton,
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
      ).copyWith(
        // El botón se levanta al pasar el ratón y baja al pulsarlo.
        elevation: WidgetStateProperty.resolveWith(
          (estados) => estados.contains(WidgetState.pressed)
              ? 0
              : estados.contains(WidgetState.hovered)
                  ? 4
                  : 0,
        ),
        shadowColor: const WidgetStatePropertyAll(Color(0x66C2410C)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.naranjaProfundo,
        side: const BorderSide(color: AppColors.borde),
        shape: formaBoton,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.naranjaProfundo,
        shape: formaBoton,
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadios.tarjeta),
        side: const BorderSide(color: AppColors.borde),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadios.ventana)),
      titleTextStyle: textos.titleLarge,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.texto,
      contentTextStyle: GoogleFonts.inter(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: const StadiumBorder(side: BorderSide(color: AppColors.borde)),
      backgroundColor: Colors.white,
      selectedColor: AppColors.naranjaClaro,
      side: const BorderSide(color: AppColors.borde),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.borde, thickness: 1),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: AppColors.texto, borderRadius: BorderRadius.circular(8)),
      textStyle: GoogleFonts.inter(color: Colors.white, fontSize: 12),
    ),
  );
}
