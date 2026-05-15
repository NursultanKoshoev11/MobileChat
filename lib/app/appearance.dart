import 'package:flutter/material.dart';

import 'localization.dart';
import 'theme.dart';

class AppAppearanceController extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;

  void setThemeMode(ThemeMode value) {
    if (_themeMode == value) return;
    _themeMode = value;
    notifyListeners();
  }

  void toggleTheme() {
    setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
  }
}

class AppAppearanceScope extends InheritedNotifier<AppAppearanceController> {
  const AppAppearanceScope({
    super.key,
    required AppAppearanceController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppAppearanceController controllerOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppAppearanceScope>();
    assert(scope != null, 'AppAppearanceScope not found in widget tree');
    return scope!.notifier!;
  }
}

class ThemeModeButton extends StatelessWidget {
  const ThemeModeButton({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppAppearanceScope.controllerOf(context);
    final text = AppLanguageScope.textOf(context);
    final dark = controller.isDark;
    return IconButton(
      tooltip: dark ? (text.isKy ? 'Жарык тема' : 'Светлая тема') : (text.isKy ? 'Караңгы тема' : 'Тёмная тема'),
      onPressed: controller.toggleTheme,
      icon: Icon(dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
      color: MobileChatTheme.primaryDark,
    );
  }
}
