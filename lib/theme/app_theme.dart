import 'package:flutter/material.dart';

/// Sistema visual de Bipy. Los colores salen del logo: azul marino y amarillo.
///
/// Regla de uso: el amarillo es el color de la accion principal de cada
/// pantalla (y de los acentos sobre fondos azules); el azul marino es el color
/// de estructura (barras, tarjeta destacada, texto de enlace). Los verdes y
/// rojos son solo para estados (exito / error).
///
/// Todos los pares texto/fondo usados aqui superan 4.5:1 de contraste.
class AppTheme {
  AppTheme._();

  // Marca (tomados del logo)
  static const Color navy = Color(0xFF00204F);
  static const Color navyDeep = Color(0xFF081733); // fondo de pantallas oscuras
  static const Color navySurface = Color(0xFF10264A); // tarjetas sobre fondo oscuro
  static const Color yellow = Color(0xFFFFBB02);

  // Neutros sobre fondo claro
  static const Color background = Color(0xFFF5F6FA);
  static const Color cardBackground = Colors.white;
  static const Color textDark = Color(0xFF0F1B2E);
  static const Color textMuted = Color(0xFF5B6678);
  static const Color line = Color(0xFFDDE2EC);

  // Neutros sobre fondo oscuro
  static const Color textMutedOnDark = Color(0xFF9FB0C8);

  // Estados
  static const Color success = Color(0xFF157A45);
  static const Color successOnDark = Color(0xFF4ADE80);
  static const Color danger = Color(0xFFC62F2F);
  static const Color dangerOnDark = Color(0xFFFF6B6B);

  static const String fontFamily = 'Barlow';

  /// Tema claro de toda la app. Las pantallas oscuras (seguimiento del viaje
  /// y del pedido) definen su propio fondo con [navyDeep].
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: navy).copyWith(
      primary: navy,
      onPrimary: Colors.white,
      secondary: yellow,
      onSecondary: navy,
      surface: Colors.white,
      onSurface: textDark,
      error: danger,
      onError: Colors.white,
    );

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: line),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: yellow,
          foregroundColor: navy,
          minimumSize: const Size(64, 52),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontFamily: fontFamily, fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: navy,
          minimumSize: const Size(64, 48),
          side: const BorderSide(color: Color(0xFFB6BFCF)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontFamily: fontFamily, fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: navy,
          minimumSize: const Size(48, 48),
          textStyle: const TextStyle(fontFamily: fontFamily, fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(borderSide: const BorderSide(color: navy, width: 2)),
        errorBorder: inputBorder.copyWith(borderSide: const BorderSide(color: danger)),
        focusedErrorBorder: inputBorder.copyWith(borderSide: const BorderSide(color: danger, width: 2)),
        labelStyle: const TextStyle(color: textMuted),
        floatingLabelStyle: const TextStyle(color: navy, fontWeight: FontWeight.w600),
        hintStyle: const TextStyle(color: textMuted),
        prefixIconColor: textMuted,
        suffixIconColor: textMuted,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textDark,
        ),
        contentTextStyle: const TextStyle(fontFamily: fontFamily, fontSize: 16, color: textMuted),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: navy,
        contentTextStyle: const TextStyle(fontFamily: fontFamily, fontSize: 15, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: navy),
    );
  }
}
