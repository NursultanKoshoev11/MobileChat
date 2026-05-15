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
  const AppAppearanceScope({super.key, required AppAppearanceController controller, required super.child}) : super(notifier: controller);

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
      tooltip: dark ? (text.isKy ? 'Жарык режим' : 'Светлый режим') : (text.isKy ? 'Караңгы режим' : 'Тёмный режим'),
      onPressed: controller.toggleTheme,
      icon: Icon(dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
      color: MobileChatTheme.primary,
    );
  }
}

class AppSettingsButton extends StatelessWidget {
  const AppSettingsButton({super.key});

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    return IconButton(
      tooltip: text.isKy ? 'Жөндөөлөр' : 'Настройки',
      icon: const Icon(Icons.settings_rounded),
      onPressed: () => showAppSettingsSheet(context),
    );
  }
}

Future<void> showAppSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: Theme.of(context).cardColor,
    builder: (_) => const AppSettingsSheet(),
  );
}

class AppSettingsSheet extends StatelessWidget {
  const AppSettingsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final appearance = AppAppearanceScope.controllerOf(context);
    final language = AppLanguageScope.controllerOf(context);
    final text = AppLanguageScope.textOf(context);
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(text.isKy ? 'Жөндөөлөр' : 'Настройки', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: colors.textStrong)),
        const SizedBox(height: 14),
        Text(text.isKy ? 'Тема' : 'Тема', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _SettingsOption(label: text.isKy ? 'Жарык режим' : 'Светлый режим', icon: Icons.light_mode_rounded, selected: !appearance.isDark, onTap: () => appearance.setThemeMode(ThemeMode.light))),
          const SizedBox(width: 10),
          Expanded(child: _SettingsOption(label: text.isKy ? 'Караңгы режим' : 'Тёмный режим', icon: Icons.dark_mode_rounded, selected: appearance.isDark, onTap: () => appearance.setThemeMode(ThemeMode.dark))),
        ]),
        const SizedBox(height: 16),
        Text(text.languageLabel, style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _SettingsOption(label: 'Русский', icon: Icons.language_rounded, selected: language.language == AppLanguage.ru, onTap: () => language.setLanguage(AppLanguage.ru))),
          const SizedBox(width: 10),
          Expanded(child: _SettingsOption(label: 'Кыргызча', icon: Icons.language_rounded, selected: language.language == AppLanguage.ky, onTap: () => language.setLanguage(AppLanguage.ky))),
        ]),
      ]),
    );
  }
}

class _SettingsOption extends StatelessWidget {
  const _SettingsOption({required this.label, required this.icon, required this.selected, required this.onTap});

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? MobileChatTheme.primary.withValues(alpha: 0.18) : colors.surfaceSoft,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? MobileChatTheme.primary : colors.border, width: selected ? 1.5 : 1),
        ),
        child: Row(children: [
          Icon(icon, color: selected ? MobileChatTheme.primary : colors.textMuted),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: TextStyle(color: colors.textStrong, fontWeight: FontWeight.w800))),
          if (selected) const Icon(Icons.check_circle_rounded, color: MobileChatTheme.primary, size: 18),
        ]),
      ),
    );
  }
}
