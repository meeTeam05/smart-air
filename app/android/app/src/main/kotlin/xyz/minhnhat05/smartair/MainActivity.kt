package xyz.minhnhat05.smartair

import android.content.Intent
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "mt_home/settings"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getAndroidSdkInt" -> {
                        result.success(Build.VERSION.SDK_INT)
                    }
                    "openBluetoothSettings" -> {
                        startActivity(
                            Intent(Settings.ACTION_BLUETOOTH_SETTINGS)
                        )
                        result.success(null)
                    }
                    "openLocationSettings" -> {
                        startActivity(
                            Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)
                        )
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
