package com.onyx.user_app

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Flutter host activity. Adds one channel: Flutter "Rooms" tab -> native RoomActivity. */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "onyx/rooms")
            .setMethodCallHandler { call, result ->
                if (call.method == "open") {
                    startActivity(Intent(this, RoomActivity::class.java))
                    result.success(true)
                } else {
                    result.notImplemented()
                }
            }
    }
}
