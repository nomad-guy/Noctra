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

# 4. Keep error-level logging (only strip verbose/debug/info) — errors
#    are needed for production crash diagnosis.
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}

# 5. Flutter Framework & Embedder Preservation
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# 6. Audio, JustAudio 0.10 (Media3) & Background Media Service Preservation
-keep class com.ryanheise.** { *; }
-keep class androidx.media.** { *; }
# Media3 ExoPlayer — just_audio 0.10 uses Media3, NOT legacy exoplayer2
-keep class androidx.media3.** { *; }
-keep class com.google.android.gms.** { *; }
# Keep MediaItem and related classes for lock screen / notification controls
-keepclassmembers class androidx.media3.common.MediaItem { *; }
-keepclassmembers class androidx.media3.common.MediaMetadata { *; }

# 7. Keep Noctra classes accessed from MainActivity (MethodChannel) or used at runtime
-keep class com.nomadguy.noctra.** { *; }
-keepclasseswithmembernames class * {
    native <methods>;
}

# 8. Keep Enums (used in Flutter plugin callbacks)
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
