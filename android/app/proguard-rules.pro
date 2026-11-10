# Flutter Wrapper Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Android Alarm Manager Plus
-keep class dev.fluttercommunity.plus.androidalarmmanager.** { *; }
-keep class dev.fluttercommunity.plus.androidalarmmanager.AlarmService { *; }
-keep class dev.fluttercommunity.plus.androidalarmmanager.AlarmBroadcastReceiver { *; }
-keep class dev.fluttercommunity.plus.androidalarmmanager.RebootBroadcastReceiver { *; }

# Sound Mode
-keep class com.clwater.sound_mode.** { *; }

# Google Mobile Ads (AdMob)
-keep class com.google.android.gms.ads.** { *; }
-keep public class com.google.android.gms.ads.initialization.OnInitializationCompleteListener { *; }

# Hive & Type Adapters
-keep class com.kawiish.smartsilent.** { *; }
-keepnames class * extends io.flutter.plugin.common.StandardMessageCodec { *; }

# MultiDex
-keep class androidx.multidex.** { *; }

# Prevent native method stripping
-keepclasseswithmembernames class * {
    native <methods>;
}
