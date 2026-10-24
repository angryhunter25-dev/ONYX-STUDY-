package com.onyx.user_app

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter host activity. Channel "onyx/rooms":
 *   open(args) -> opens the native voice-room screen (RoomActivity) and returns the
 *   ONYX tab index the user tapped in its bottom bar (-1 = just went back).
 */
class MainActivity : FlutterActivity() {
    private var roomsResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "onyx/rooms")
            .setMethodCallHandler { call, result ->
                if (call.method == "open") {
                    if (roomsResult != null) {
                        result.error("busy", "Rooms already open", null)
                        return@setMethodCallHandler
                    }
                    roomsResult = result
                    val i = Intent(this, RoomActivity::class.java)
                    (call.arguments as? Map<*, *>)?.forEach { (k, v) ->
                        if (k is String && v is String) i.putExtra(k, v)
                    }
                    startActivityForResult(i, 4711)
                } else {
                    result.notImplemented()
                }
            }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == 4711) {
            roomsResult?.success(data?.getIntExtra("tab", -1) ?: -1)
            roomsResult = null
        } else {
            super.onActivityResult(requestCode, resultCode, data)
        }
    }
}
