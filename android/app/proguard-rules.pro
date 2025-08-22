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

# ERWEITERTE REGELN FÜR GOOGLE ML KIT
# Diese umfassenderen Regeln verhindern, dass R8 dynamisch geladene
# Klassen und Abhängigkeiten von ML Kit und den Google Mobile Services (GMS) entfernt.
-keep public class com.google.mlkit.** {*;}
-keep public class com.google.android.gms.internal.mlkit_vision_common.** {*;}
-keep public class com.google.android.gms.internal.mlkit_vision_text_common.** {*;}ision_text_common.** { *; }