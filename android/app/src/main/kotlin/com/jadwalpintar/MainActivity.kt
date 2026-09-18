package com.jadwalpintar

import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // ANDROID_ID asli (Settings.Secure) — device_info_plus tidak
        // menyediakannya (id di sana = Build.ID). Tanpa permission.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "jadwalpintar/device",
        ).setMethodCallHandler { call, result ->
            if (call.method == "getAndroidId") {
                try {
                    result.success(
                        Settings.Secure.getString(
                            contentResolver,
                            Settings.Secure.ANDROID_ID,
                        ),
                    )
                } catch (e: Exception) {
                    result.success(null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
