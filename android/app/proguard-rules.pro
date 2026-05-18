# Flutter and Firebase default release rules.
# Keep rules can be added here if a specific native dependency requires them.

-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }

# Flutter references Play Core deferred component APIs from the engine, but this app
# does not use deferred components. These classes may be absent in normal APK builds.
# Without these rules R8 fails release builds with Missing class com.google.android.play.core.*.
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
