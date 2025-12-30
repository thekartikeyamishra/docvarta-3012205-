// lib/theme/app_theme.dart
import 'package:flutter/material.dart';

/// Central theme file for DocVartaa.
/// Provides AppTheme InheritedWidget to optionally access a custom ThemeData,
/// and also provides a ready-to-use ThemeData (lightTheme) you can apply to
/// MaterialApp.theme.
class AppTheme extends InheritedWidget {
  final ThemeData data;

  const AppTheme({required this.data, required super.child, super.key});

  /// Access the provided ThemeData. Returns null if no AppTheme ancestor exists.
  static ThemeData? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppTheme>()?.data;

  @override
  bool updateShouldNotify(AppTheme oldWidget) => data != oldWidget.data;

  /// Primary brand colors and TextTheme tuned to the screenshots you provided.
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: false,
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFFBFBFD), // subtle off-white
    primaryColor: const Color(0xFF1E88E5), // bright but soft blue
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF1E88E5),
      primary: const Color(0xFF1E88E5),
      secondary: const Color(0xFFFFA726),
      background: const Color(0xFFFBFBFD),
      surface: Colors.white,
      onPrimary: Colors.white,
      onBackground: Colors.black87,
      onSurface: Colors.black87,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1E88E5),
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
      iconTheme: IconThemeData(color: Colors.white),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
      margin: EdgeInsets.zero,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF1E88E5),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide(color: Colors.grey.shade300),
      ),
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      bodyLarge: TextStyle(fontSize: 15, color: Colors.black87),
      bodyMedium: TextStyle(fontSize: 14, color: Colors.black87),
      bodySmall: TextStyle(fontSize: 13, color: Colors.black54),
      labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF6F7FB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      hintStyle: TextStyle(color: Colors.grey.shade500),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: const Color(0xFF1E88E5),
      unselectedItemColor: Colors.grey.shade600,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      elevation: 12,
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    visualDensity: VisualDensity.adaptivePlatformDensity,
    splashColor: Colors.white24,
    highlightColor: Colors.transparent,
  );

  /// Helper widget to wrap app with AppTheme (optional).
  /// Use like:
  ///   runApp(AppThemeProvider(child: MyApp()));
  static Widget provider({required Widget child}) {
    return AppTheme(data: AppTheme.lightTheme, child: child);
  }
}
