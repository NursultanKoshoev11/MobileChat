from pathlib import Path

path = Path("lib/features/groups/groups_screen.dart")
text = path.read_text(encoding="utf-8")
old = "import 'dart:async';\n"
new = "import 'dart:async';\nimport 'dart:typed_data';\n"
if text.count(old) != 1:
    raise RuntimeError("Expected one dart:async import in groups_screen.dart")
path.write_text(text.replace(old, new, 1), encoding="utf-8")
Path(__file__).unlink(missing_ok=True)
