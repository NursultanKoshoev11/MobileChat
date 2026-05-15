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
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'MobileChat Offline Demo',
          theme: MobileChatTheme.light,
          darkTheme: MobileChatTheme.dark,
          themeMode: themeController.mode,
          home: const OfflineLoginScreen(),
        );
      },
    );
  }
}

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        return IconButton(
          tooltip: themeController.isDark ? 'Light mode' : 'Dark mode',
          onPressed: themeController.toggle,
          icon: Icon(themeController.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
        );
      },
    );
  }
}

final BorderRadius _cardRadius = BorderRadius.circular(22);

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

# Add theme toggles to main screens.
text = text.replace(
    "appBar: AppBar(title: const Text('Groups'), actions: [IconButton(",
    "appBar: AppBar(title: const Text('Groups'), actions: [const ThemeToggleButton(), IconButton(",
)
text = text.replace(
    "appBar: AppBar(title: const Text('Admin Panel'), actions: [IconButton(",
    "appBar: AppBar(title: const Text('Admin Panel'), actions: [const ThemeToggleButton(), IconButton(",
)
text = text.replace(
    "appBar: AppBar(title: Text(widget.group.title)),",
    "appBar: AppBar(title: Text(widget.group.title), actions: const [ThemeToggleButton()]),",
)
text = text.replace(
    "appBar: AppBar(title: const Text('Read post'), actions: [if (widget.group.canModerate)",
    "appBar: AppBar(title: const Text('Read post'), actions: [const ThemeToggleButton(), if (widget.group.canModerate)",
)

# Login card: background/card contrast.
text = text.replace(
    "decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 28, offset: Offset(0, 16))]),",
    "decoration: appCardDecoration(context, radius: 32),",
)
text = text.replace(
    "const Text('No internet. No server. Test admin number opens Admin Panel.', textAlign: TextAlign.center, style: TextStyle(color: MobileChatTheme.textMuted)),",
    "Text('No internet. No server. Test admin number opens Admin Panel.', textAlign: TextAlign.center, style: TextStyle(color: context.appColors.textMuted)),",
)
text = text.replace(
    "Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(16)), child: Text('Admin test number: $adminDemoPhone\\nDemo SMS code: $demoOtpCode', textAlign: TextAlign.center, style: const TextStyle(color: MobileChatTheme.primaryDark, fontWeight: FontWeight.w800))),",
    "Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: context.appColors.surfaceSoft, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.appColors.border)), child: const Text('Admin test number: $adminDemoPhone\\nDemo SMS code: $demoOtpCode', textAlign: TextAlign.center, style: TextStyle(color: MobileChatTheme.primary, fontWeight: FontWeight.w800))),",
)
text = text.replace(
    "const SizedBox(height: 18),\n                  FilledButton.icon(onPressed: enterDemo,",
    "const SizedBox(height: 18),\n                  const Align(alignment: Alignment.center, child: ThemeToggleButton()),\n                  const SizedBox(height: 8),\n                  FilledButton.icon(onPressed: enterDemo,",
)

# Cards and foreground surfaces. These exact patterns are inside build methods, so context is valid.
text = text.replace("Material(\n        color: Colors.white,", "Material(\n        color: context.appColors.surface,")
text = text.replace("decoration: BoxDecoration(color: Colors.white, borderRadius:", "decoration: BoxDecoration(color: context.appColors.surface, borderRadius:")
text = text.replace("color: Colors.white, child: Row", "color: context.appColors.surface, child: Row")
text = text.replace("color: const Color(0xFFEFF6FF)", "color: context.appColors.chipBackground")

# Important muted text colors that are not const-only widgets.
text = text.replace("color: MobileChatTheme.textMuted", "color: context.appColors.textMuted")
text = text.replace("style: const TextStyle(color: context.appColors.textMuted", "style: TextStyle(color: context.appColors.textMuted")
text = text.replace("style: const TextStyle(color: MobileChatTheme.primary", "style: const TextStyle(color: MobileChatTheme.primary")

# Keep icon foreground white. Do not replace it with theme surface.
text = text.replace("Icon(Icons.wifi_off_rounded, color: context.appColors.surface,", "Icon(Icons.wifi_off_rounded, color: Colors.white,")

# Safety checks.
if "darkTheme: MobileChatTheme.dark" not in text:
    raise SystemExit("Theme mode patch failed")
if "ThemeToggleButton" not in text:
    raise SystemExit("Theme toggle patch failed")
if "Icon(Icons.wifi_off_rounded, color: context.appColors.surface" in text:
    raise SystemExit("Icon color was patched incorrectly")

path.write_text(text)
print("Offline light/dark theme patch applied safely.")
