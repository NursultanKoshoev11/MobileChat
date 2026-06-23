// Deprecated legacy entrypoint. Use lib/main.dart for production builds.
// Kept as a compatibility shim so old CI/build commands do not compile the removed
// email/password prototype by mistake.

import 'main.dart' as app;

@Deprecated('Use lib/main.dart. This shim exists only for legacy build commands.')
Future<void> main() => app.main();
