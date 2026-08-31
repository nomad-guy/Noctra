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

# 6. Audio, JustAudio 0.10 (Media3) & Background Media Service Preservation
-keep class com.ryanheise.** { *; }
-keep class androidx.media.** { *; }
# Media3 ExoPlayer — just_audio 0.10 uses Media3, NOT legacy exoplayer2
-keep class androidx.media3.** { *; }
-keep class androidx.media3.exoplayer.** { *; }
-keep class androidx.media3.extractor.** { *; }
-keep class androidx.media3.datasource.** { *; }
-keep class androidx.media3.common.** { *; }
-keep class androidx.media3.session.** { *; }
-keep class com.google.android.gms.** { *; }
# Keep MediaItem and related classes for lock screen / notification controls
-keepclassmembers class androidx.media3.common.MediaItem { *; }
-keepclassmembers class androidx.media3.common.MediaMetadata { *; }

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
