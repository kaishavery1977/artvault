# ProGuard rules for ArtVault

# ML Kit text recognition - keep all language options
-keep class com.google.mlkit.vision.text.** { *; }
-dontwarn com.google.mlkit.vision.text.**

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Flutter
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# Google Sign In
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Sign in with Apple
-keep class com.apple.** { *; }

# Keep ML Kit vision
-keep class com.google.mlkit.vision.** { *; }
-dontwarn com.google.mlkit.vision.**