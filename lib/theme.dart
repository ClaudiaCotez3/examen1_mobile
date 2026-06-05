import 'package:flutter/material.dart';

/// Paleta del sistema — espejo exacto de los colores del frontend Angular
/// (azules #2563eb/#1d4ed8, escala slate, chips de estado, morado IA),
/// para que la app móvil se sienta parte del mismo producto.
class AppColors {
  AppColors._();

  // Azul primario (botones, links, estados activos)
  static const primary = Color(0xFF2563EB);
  static const primaryDark = Color(0xFF1D4ED8);
  static const primarySoft = Color(0xFFDBEAFE); // chips "Activo"
  static const primarySofter = Color(0xFFEFF6FF);

  // Escala slate (textos y bordes)
  static const ink = Color(0xFF0F172A); // títulos
  static const slate = Color(0xFF475569); // texto secundario
  static const slateSoft = Color(0xFF64748B); // subtítulos
  static const muted = Color(0xFF94A3B8); // hints
  static const border = Color(0xFFE2E8F0);
  static const borderStrong = Color(0xFFCBD5E1);
  static const background = Color(0xFFF8FAFC); // fondo de página
  static const surfaceSoft = Color(0xFFF1F5F9);

  // Estados (mismos pares fondo/texto que las chips del frontend)
  static const successBg = Color(0xFFDCFCE7);
  static const successText = Color(0xFF15803D);
  static const warningBg = Color(0xFFFEF9C3);
  static const warningText = Color(0xFFA16207);
  static const dangerBg = Color(0xFFFEE2E2);
  static const dangerText = Color(0xFFB91C1C);

  // Morado IA (asistente / módulo inteligente)
  static const ai = Color(0xFF7C3AED);
  static const aiDark = Color(0xFF6D28D9);
  static const aiSoft = Color(0xFFF5F3FF);
}

/// ThemeData global: bordes redondeados 8–12px, cards con borde sutil,
/// inputs estilo frontend (borde slate + focus azul).
ThemeData buildAppTheme() {
  const radius12 = BorderRadius.all(Radius.circular(12));
  const radius8 = BorderRadius.all(Radius.circular(8));

  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      surface: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.ink,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.ink,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      shape: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    cardTheme: const CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: radius12,
        side: BorderSide(color: AppColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: const OutlineInputBorder(
        borderRadius: radius8,
        borderSide: BorderSide(color: AppColors.borderStrong),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: radius8,
        borderSide: BorderSide(color: AppColors.borderStrong),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: radius8,
        borderSide: BorderSide(color: AppColors.primary, width: 2),
      ),
      hintStyle: const TextStyle(color: AppColors.muted, fontSize: 13.5),
      labelStyle: const TextStyle(color: AppColors.slate, fontSize: 13.5),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        shape: const RoundedRectangleBorder(borderRadius: radius8),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.slate,
        side: const BorderSide(color: AppColors.borderStrong),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: const RoundedRectangleBorder(borderRadius: radius8),
        textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.primary),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.ink,
      contentTextStyle: TextStyle(color: Colors.white, fontSize: 13.5),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
