# Flutter's default ProGuard rules.
-dontwarn io.flutter.embedding.**
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keepclassmembers class fia {
    *** any;
}

# HINZUGEFÜGT: R8 anweisen, Warnungen über fehlende, optionale
# ML Kit Sprachpakete zu ignorieren, da wir sie nicht verwenden.
# Dies behebt den "Missing classes" Fehler an der Wurzel.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**