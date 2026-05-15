from pathlib import Path

path = Path("lib/main_offline.dart")
text = path.read_text()

text = text.replace(
"""void main() {
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
""",
"""void main() {
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

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: colors.border),
          boxShadow: [BoxShadow(color: colors.shadow, blurRadius: 18, offset: const Offset(0, 8))],
        ),
        child: child,
      ),
    );
  }
}
""")

# App bars: add theme toggle next to existing actions where possible.
text = text.replace(
"""appBar: AppBar(title: const Text('Groups'), actions: [IconButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyRequestsScreen())), icon: const Icon(Icons.assignment_outlined), tooltip: 'My requests'), IconButton(onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const OfflineLoginScreen())), icon: const Icon(Icons.logout_rounded), tooltip: 'Log out')]),""",
"""appBar: AppBar(title: const Text('Groups'), actions: [const ThemeToggleButton(), IconButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyRequestsScreen())), icon: const Icon(Icons.assignment_outlined), tooltip: 'My requests'), IconButton(onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const OfflineLoginScreen())), icon: const Icon(Icons.logout_rounded), tooltip: 'Log out')]),""")

text = text.replace(
"""appBar: AppBar(title: const Text('Admin Panel'), actions: [IconButton(onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const OfflineLoginScreen())), icon: const Icon(Icons.logout_rounded))]),""",
"""appBar: AppBar(title: const Text('Admin Panel'), actions: [const ThemeToggleButton(), IconButton(onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const OfflineLoginScreen())), icon: const Icon(Icons.logout_rounded))]),""")

text = text.replace(
"""appBar: AppBar(title: Text(widget.group.title)),""",
"""appBar: AppBar(title: Text(widget.group.title), actions: const [ThemeToggleButton()]),""")

text = text.replace(
"""appBar: AppBar(title: const Text('Read post'), actions:""",
"""appBar: AppBar(title: const Text('Read post'), actions: [const ThemeToggleButton(),""")

# Fix potential double bracket introduced above for Read post actions.
text = text.replace("""actions: [const ThemeToggleButton(), [if""", """actions: [const ThemeToggleButton(), if""")

# Login card and admin notice colors.
text = text.replace(
"""decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 28, offset: Offset(0, 16))]),""",
"""decoration: BoxDecoration(color: context.appColors.surface, borderRadius: BorderRadius.circular(32), border: Border.all(color: context.appColors.border), boxShadow: [BoxShadow(color: context.appColors.shadow, blurRadius: 28, offset: const Offset(0, 16))]),""")

text = text.replace(
"""const Text('No internet. No server. Test admin number opens Admin Panel.', textAlign: TextAlign.center, style: TextStyle(color: MobileChatTheme.textMuted)),""",
"""Text('No internet. No server. Test admin number opens Admin Panel.', textAlign: TextAlign.center, style: TextStyle(color: context.appColors.textMuted)),""")

text = text.replace(
"""Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(16)), child: Text('Admin test number: $adminDemoPhone\\nDemo SMS code: $demoOtpCode', textAlign: TextAlign.center, style: const TextStyle(color: MobileChatTheme.primaryDark, fontWeight: FontWeight.w800))),""",
"""Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: context.appColors.surfaceSoft, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.appColors.border)), child: const Text('Admin test number: $adminDemoPhone\\nDemo SMS code: $demoOtpCode', textAlign: TextAlign.center, style: TextStyle(color: MobileChatTheme.primary, fontWeight: FontWeight.w800))),""")

# Add theme toggle in login screen controls before main enter button if not present.
text = text.replace(
"""const SizedBox(height: 18),
                  FilledButton.icon(onPressed: enterDemo,""",
"""const SizedBox(height: 18),
                  Align(alignment: Alignment.center, child: const ThemeToggleButton()),
                  const SizedBox(height: 8),
                  FilledButton.icon(onPressed: enterDemo,""")

# Replace common hard-coded surfaces.
text = text.replace("""color: Colors.white,""", """color: context.appColors.surface,""")
text = text.replace("""color: const Color(0xFFEFF6FF)""", """color: context.appColors.chipBackground""")
text = text.replace("""color: MobileChatTheme.textMuted""", """color: context.appColors.textMuted""")
text = text.replace("""color: MobileChatTheme.primaryDark""", """color: MobileChatTheme.primary""")

# The global replacement can break const widgets with context in const constructors; fix known const TextStyle patterns.
text = text.replace("""style: const TextStyle(color: context.appColors.textMuted""", """style: TextStyle(color: context.appColors.textMuted""")
text = text.replace("""style: const TextStyle(color: MobileChatTheme.primary""", """style: const TextStyle(color: MobileChatTheme.primary""")
text = text.replace("""style: const TextStyle(color: context.appColors.textMuted, fontSize: 12""", """style: TextStyle(color: context.appColors.textMuted, fontSize: 12""")
text = text.replace("""style: const TextStyle(color: context.appColors.textMuted, fontWeight:""", """style: TextStyle(color: context.appColors.textMuted, fontWeight:""")
text = text.replace("""style: const TextStyle(color: context.appColors.textMuted))""", """style: TextStyle(color: context.appColors.textMuted))""")

# Add borders to Material cards by wrapping their child Padding with Container where not easy is too risky; at least Material color changes.

if "darkTheme: MobileChatTheme.dark" not in text:
    raise SystemExit("Theme mode patch failed")
if "ThemeToggleButton" not in text:
    raise SystemExit("Theme toggle patch failed")

path.write_text(text)
print("Offline theme patch applied.")
