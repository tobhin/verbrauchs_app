# Flutter's default ProGuard rules.
# You can customize this file to optimize your application's size.
# For more information, see https://flutter.dev/docs/deployment/android#reviewing-the-proguard-rules

# The following rules are used by default Flutter apps.
-dontwarn io.flutter.embedding.**
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keepclassmembers class fia {
    *** any;
}

# HINZUGEFÜGT: Regeln für Google ML Kit Text Recognition
# Verhindert, dass R8 die optionalen Sprach-Klassen im Release-Build entfernt.
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }