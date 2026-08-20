# flutter_local_notifications deserializes scheduled notifications from disk
# with Gson, so the reflected model classes and their generic signatures must
# survive R8. Without this, notifications restored after a reboot crash.
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn com.dexterous.flutterlocalnotifications.**

# Gson's TypeToken relies on generic type information at runtime.
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken

# Play Core is referenced by the Flutter embedding's deferred-components
# support, which this app does not use.
-dontwarn com.google.android.play.core.**
