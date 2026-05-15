from pathlib import Path

path = Path("lib/main_offline.dart")
text = path.read_text()
old = """  Future<void> login(OfflineSession session) async {
    await store.saveSession(session);
    setState(() => sessionFuture = Future.value(session));
  }

  Future<void> logout() async {
    await store.clearSession();
    setState(() => sessionFuture = Future.value(null));
  }
"""
new = """  Future<void> login(OfflineSession session) async {
    setState(() => sessionFuture = Future.value(session));
    try {
      await store.saveSession(session);
    } catch (_) {
      // Offline demo must open even if local secure storage is unavailable.
    }
  }

  Future<void> logout() async {
    setState(() => sessionFuture = Future.value(null));
    try {
      await store.clearSession();
    } catch (_) {
      // Offline demo must log out even if local secure storage is unavailable.
    }
  }
"""
if old not in text:
    print("Offline login block already patched or changed. No patch applied.")
else:
    path.write_text(text.replace(old, new))
    print("Offline login block patched successfully.")
