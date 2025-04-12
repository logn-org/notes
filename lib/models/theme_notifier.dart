import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier with ChangeNotifier {
  ThemeData _themeData;
  ThemeData darkTheme;
  final SharedPreferences _prefs;

  ThemeNotifier(this._prefs)
    : _themeData = _loadThemeFromPrefs(_prefs),
      darkTheme = ThemeData.dark();

  ThemeData get themeData => _themeData;
  ThemeMode get themeMode {
    final isDarkMode = _prefs.getBool('isDarkMode') ?? false;
    return isDarkMode ? ThemeMode.dark : ThemeMode.light;
  }

  static ThemeData _loadThemeFromPrefs(SharedPreferences prefs) {
    final isDarkMode = prefs.getBool('isDarkMode') ?? false;
    return isDarkMode
        ? ThemeData.dark()
        : ThemeData.light().copyWith(
          primaryColor: Colors.blue, // Example customization
        );
  }

  Future<void> setTheme(ThemeData theme) async {
    _themeData = theme;
    final isDarkMode = theme == ThemeData.dark();
    await _prefs.setBool('isDarkMode', isDarkMode);
    notifyListeners();
  }

  void toggleTheme() {
    final isDarkMode = _themeData != ThemeData.dark();
    setTheme(isDarkMode ? ThemeData.dark() : ThemeData.light());
    notifyListeners();
  }
}
