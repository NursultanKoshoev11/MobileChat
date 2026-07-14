import 'package:flutter/material.dart';

import '../shared/koom_ui.dart';

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
  const AppAppearanceScope(
      {super.key,
      required AppAppearanceController controller,
      required super.child})
      : super(notifier: controller);

  static AppAppearanceController controllerOf(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppAppearanceScope>();
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
      tooltip: dark
          ? (text.isKy ? 'Жарык режим' : 'Светлый режим')
          : (text.isKy ? 'Караңгы режим' : 'Тёмный режим'),
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
    showDragHandle: false,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
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

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: colors.shadow,
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: colors.textMuted.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        text.settings,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textStrong,
                          fontWeight: FontWeight.w900,
                          fontSize: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filledTonal(
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        backgroundColor: colors.surfaceSoft,
                        foregroundColor: colors.textStrong,
                      ),
                      icon: const Icon(Icons.close_rounded),
                      tooltip: text.close,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  text.isKy ? 'Тема' : 'Тема',
                  style: TextStyle(
                    color: colors.textMuted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                KoomAdaptiveTileGrid(
                  minItemWidth: 150,
                  maxColumns: 2,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _SettingsOption(
                      label: text.lightMode,
                      icon: Icons.light_mode_rounded,
                      selected: !appearance.isDark,
                      onTap: () =>
                          appearance.setThemeMode(ThemeMode.light),
                    ),
                    _SettingsOption(
                      label: text.darkMode,
                      icon: Icons.dark_mode_rounded,
                      selected: appearance.isDark,
                      onTap: () =>
                          appearance.setThemeMode(ThemeMode.dark),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  text.languageLabel,
                  style: TextStyle(
                    color: colors.textMuted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                KoomAdaptiveTileGrid(
                  minItemWidth: 150,
                  maxColumns: 2,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _SettingsOption(
                      label: AppLanguage.ru.displayName,
                      icon: Icons.language_rounded,
                      selected: language.language == AppLanguage.ru,
                      onTap: () => language.setLanguage(AppLanguage.ru),
                    ),
                    _SettingsOption(
                      label: AppLanguage.ky.displayName,
                      icon: Icons.language_rounded,
                      selected: language.language == AppLanguage.ky,
                      onTap: () => language.setLanguage(AppLanguage.ky),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsOption extends StatelessWidget {
  const _SettingsOption(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final background = selected ? MobileChatTheme.primary : colors.surfaceSoft;
    final foreground = selected ? Colors.white : colors.textStrong;
    final iconColor = selected ? Colors.white : colors.textMuted;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? MobileChatTheme.primary : colors.border,
            width: 1.5,
          ),
        ),
        child: Row(children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 8),
          Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: foreground, fontWeight: FontWeight.w800))),
          const SizedBox(width: 8),
          SizedBox(
            width: 18,
            height: 18,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 140),
              opacity: selected ? 1 : 0,
              child: const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
