# Noctra Production Hardening & Obfuscation ProGuard Rules

# 1. Ignore optional Play Store deferred components
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# 2. Source Attribute Preservation
-renamesourcefileattribute "SourceFile"
-keepattributes SourceFile,LineNumberTable

# 3. Optimization and Code Shrinking
-optimizationpasses 5
-dontpreverify

# 4. Strip all Logging and Debug Traces in Release
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
    public static *** w(...);
}

# 5. Flutter Framework & Embedder Preservation
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# 6. Audio, JustAudio & Background Media Service Preservation
-keep class com.ryanheise.** { *; }
-keep class androidx.media.** { *; }
-keep class androidx.media3.** { *; }
-keep class com.google.android.exoplayer2.** { *; }
-keep class com.google.android.gms.** { *; }

# 7. Keep Native JNI Methods & Noctra Classes
-keep class com.nomadguy.noctra.** { *; }
-keepclassmembers class com.nomadguy.noctra.** { *; }
-keepclasseswithmembernames class * {
    native <methods>;
}

# 8. Keep Custom Class View Annotations & Enums
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
