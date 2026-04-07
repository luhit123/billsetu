import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { system, light, dark }

/// Provides theme-mode state to the widget tree.
/// Persists user preference to SharedPreferences under 'app_theme_mode'.
class ThemeProvider extends StatefulWidget {
  const ThemeProvider({required this.child, super.key});

  final Widget child;

  static ThemeMode themeModeOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_ThemeScope>();
    if (scope == null) return ThemeMode.system;
    return switch (scope.mode) {
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
      AppThemeMode.system => ThemeMode.system,
    };
  }

  static AppThemeMode appThemeModeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_ThemeScope>()?.mode ??
        AppThemeMode.system;
  }

  static Future<void> setThemeMode(BuildContext context, AppThemeMode mode) async {
    context.findAncestorStateOfType<_ThemeProviderState>()?.setMode(mode);
  }

  @override
  State<ThemeProvider> createState() => _ThemeProviderState();
}

class _ThemeProviderState extends State<ThemeProvider> {
  AppThemeMode _mode = AppThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadMode();
  }

  Future<void> _loadMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('app_theme_mode');
      if (mounted && saved != null) {
        setState(() {
          _mode = AppThemeMode.values.firstWhere(
            (m) => m.name == saved,
            orElse: () => AppThemeMode.system,
          );
        });
      }
    } catch (e) {
      debugPrint('[ThemeService] Failed to load theme: $e');
    }
  }

  Future<void> setMode(AppThemeMode mode) async {
    setState(() => _mode = mode);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_theme_mode', mode.name);
    } catch (e) {
      debugPrint('[ThemeService] Failed to save theme: $e');
    }
  }

  @override
  Widget build(BuildContext context) =>
      _ThemeScope(mode: _mode, child: widget.child);
}

class _ThemeScope extends InheritedWidget {
  const _ThemeScope({required this.mode, required super.child});

  final AppThemeMode mode;

  @override
  bool updateShouldNotify(_ThemeScope old) => old.mode != mode;
}
