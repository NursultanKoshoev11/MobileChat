from pathlib import Path

path = Path("lib/main_offline.dart")
text = path.read_text()

old_root = """void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OfflineDemoApp());
}

class OfflineDemoApp extends StatelessWidget {
  const OfflineDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MobileChat Offline Demo',
      theme: MobileChatTheme.light,
      home: const OfflineLoginScreen(),
    );
  }
}

final demo = DemoStore();
"""

new_root = """void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OfflineDemoApp());
}

final themeController = DemoThemeController();
final demo = DemoStore();

class DemoThemeController extends ChangeNotifier {
  ThemeMode mode = ThemeMode.light;
  bool get isDark => mode == ThemeMode.dark;

  void toggle() {
    mode = isDark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }
}

class OfflineDemoApp extends StatelessWidget {
  const OfflineDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'MobileChat Offline Demo',
        theme: MobileChatTheme.light,
        darkTheme: MobileChatTheme.dark,
        themeMode: themeController.mode,
        home: const OfflineLoginScreen(),
      ),
    );
  }
}

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) => IconButton(
        tooltip: themeController.isDark ? 'Light mode' : 'Dark mode',
        onPressed: themeController.toggle,
        icon: Icon(themeController.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
      ),
    );
  }
}

BoxDecoration appCardDecoration(BuildContext context, {double radius = 22}) {
  final colors = context.appColors;
  return BoxDecoration(
    color: colors.surface,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: colors.border),
    boxShadow: [BoxShadow(color: colors.shadow, blurRadius: 18, offset: const Offset(0, 8))],
  );
}

final demo = DemoStore();
"""

if old_root in text and "darkTheme: MobileChatTheme.dark" not in text:
    text = text.replace(old_root, new_root)

simple_replacements = {
    "appBar: AppBar(title: const Text('Groups'), actions: [IconButton(": "appBar: AppBar(title: const Text('Groups'), actions: [const ThemeToggleButton(), IconButton(",
    "appBar: AppBar(title: const Text('Admin Panel'), actions: [IconButton(": "appBar: AppBar(title: const Text('Admin Panel'), actions: [const ThemeToggleButton(), IconButton(",
    "appBar: AppBar(title: Text(widget.group.title)),": "appBar: AppBar(title: Text(widget.group.title), actions: const [ThemeToggleButton()]),",
    "appBar: AppBar(title: const Text('Read post'), actions: [if (widget.group.canModerate)": "appBar: AppBar(title: const Text('Read post'), actions: [const ThemeToggleButton(), if (widget.group.canModerate)",
    "decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 28, offset: Offset(0, 16))]),": "decoration: appCardDecoration(context, radius: 32),",
    "const SizedBox(height: 18),\n                  FilledButton.icon(onPressed: enterDemo,": "const SizedBox(height: 18),\n                  const Align(alignment: Alignment.center, child: ThemeToggleButton()),\n                  const SizedBox(height: 8),\n                  FilledButton.icon(onPressed: enterDemo,",
    "Material(\n        color: Colors.white,": "Material(\n        color: context.appColors.surface,",
    "decoration: BoxDecoration(color: Colors.white, borderRadius:": "decoration: BoxDecoration(color: context.appColors.surface, borderRadius:",
    "color: Colors.white, child: Row": "color: context.appColors.surface, child: Row",
    "color: const Color(0xFFEFF6FF)": "color: context.appColors.chipBackground",
    "color: MobileChatTheme.textMuted": "color: context.appColors.textMuted",
    "style: const TextStyle(color: context.appColors.textMuted": "style: TextStyle(color: context.appColors.textMuted",
    "Icon(Icons.wifi_off_rounded, color: context.appColors.surface,": "Icon(Icons.wifi_off_rounded, color: Colors.white,",
}

for old, new in simple_replacements.items():
    text = text.replace(old, new)

# Remove const from common Text widgets if context.appColors was injected.
for snippet in [
    "const Text('No requests yet.', style: TextStyle(color: context.appColors.textMuted))",
    "const Text('No comments yet.', style: TextStyle(color: context.appColors.textMuted))",
    "const Text('Fill information so platform admins can verify the organization before creating an official group.', style: TextStyle(color: context.appColors.textMuted))",
    "const Text('This post accepts votes only. Comments are disabled.', style: TextStyle(color: context.appColors.textMuted))",
    "const Text('This post is read-only.', style: TextStyle(color: context.appColors.textMuted))",
]:
    text = text.replace(snippet, snippet.replace("const Text", "Text"))

if "darkTheme: MobileChatTheme.dark" not in text:
    raise SystemExit("Theme mode patch failed")
if "ThemeToggleButton" not in text:
    raise SystemExit("Theme toggle patch failed")

path.write_text(text)
print("Offline light/dark theme patch applied safely.")

# Russian/Kyrgyz text must be applied after theme patch because theme patch adds a few UI strings.
exec(Path("scripts/patch_offline_i18n.py").read_text(), {"__name__": "__main__"})
