# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Kotlin
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }

# Keep model classes (adjust package if needed)
-keep class com.luhit.billeasy.** { *; }

# PDF / iText
-keep class com.itextpdf.** { *; }

# Prevent stripping of R8 rules for Firebase Crashlytics (if added later)
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
