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