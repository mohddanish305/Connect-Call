# Flutter Proguard Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Agora RTC Engine Keep Rules
# Critical: Preserves Agora JNI bindings, native event handlers, and SDK callbacks
-keep class io.agora.** { *; }
-keep class io.agora.rtc2.** { *; }
-keep class io.agora.base.** { *; }
-dontwarn io.agora.**

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**

# Java Desugaring
-dontwarn java.time.**
-dontwarn java.util.concurrent.**

# Play Core (Deferred Components)
-dontwarn com.google.android.play.core.**

