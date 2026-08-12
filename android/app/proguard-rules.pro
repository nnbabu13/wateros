# Flutter-specific ProGuard rules
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Play Core (deferred components)
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Supabase
-keep class io.github.jan-tennert.supabase.** { *; }
-keep class kotlinx.serialization.** { *; }
-keepattributes *Annotation*

# Kotlin serialization
-keepattributes Signature
-dontwarn kotlinx.serialization.**

# App classes
-keep class com.swanaqua.wateros.** { *; }
