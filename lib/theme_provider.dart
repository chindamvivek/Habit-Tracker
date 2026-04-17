import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  static const Color primaryBlue = Color(0xFF4E55E0);
  static const Color primaryGreen = Color(0xFFB8EB6C);
  static const Color primaryYellow = Color(0xFFF7CD63);
  static const Color primaryPink = Color(0xFFFC8FC6);
  static const Color backgroundWhite = Color(0xFFFFFFFF);
  static const Color lightGrey = Color(0xFFF5F5F7);
  static const Color darkText = Color(0xFF1D1D1F);

  ThemeMode _themeMode = ThemeMode.light; // Default to light as per mockup

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    notifyListeners();
  }

  // Light Theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: backgroundWhite,
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundWhite,
        elevation: 0,
        iconTheme: IconThemeData(color: darkText),
        titleTextStyle: TextStyle(
          color: darkText,
          fontSize: 24,
          fontWeight: FontWeight.w900,
        ),
      ),
      cardTheme: CardThemeData(
        color: lightGrey,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      colorScheme: const ColorScheme.light(
        primary: primaryBlue,
        secondary: primaryPink,
        surface: backgroundWhite,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: darkText,
          fontWeight: FontWeight.bold,
          fontSize: 32,
        ),
        titleLarge: TextStyle(
          color: darkText,
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
        bodyLarge: TextStyle(color: darkText, fontSize: 16),
        bodyMedium: TextStyle(color: Colors.black54, fontSize: 14),
      ),
    );
  }

  // Dark Theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF121212),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E1E1E),
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E1E1E),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      colorScheme: const ColorScheme.dark(
        primary: Colors.blue,
        secondary: Colors.purpleAccent,
        surface: Color(0xFF1E1E1E),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.white),
        bodyMedium: TextStyle(color: Colors.white),
        titleLarge: TextStyle(color: Colors.white),
      ),
    );
  }
}
