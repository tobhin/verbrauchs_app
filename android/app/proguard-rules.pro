# Behalte alles von Google ML Kit (Text Recognition)
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Behalte Flutter Plugins
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.plugins.**

# Behalte Klassen für Local Notifications
-keep class com.dexterous.** { *; }
-dontwarn com.dexterous.**

# Behalte alle Parcelable Implementierungen
-keepclassmembers class * implements android.os.Parcelable {
  public static final android.os.Parcelable$Creator *;
}

# Behalte alles was von ML Kit intern aufgerufen werden könnte
-keep class com.google.android.gms.internal.mlkit_** { *; }
-dontwarn com.google.android.gms.internal.mlkit_**

# Behalte alle Annotationen (kann für ML Kit und Flutter wichtig sein)
-keepattributes *Annotation*

# Behalte Enums für Plugin-Funktionalität
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# --- NEU: R8-Fehler für optionale ML Kit-Modelle ignorieren ---
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
