package com.cashtrace.app

import android.Manifest
import android.content.pm.PackageManager
import android.net.Uri
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val SMS_CHANNEL = "money_tracker/sms"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "readInbox" -> {
                        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS)
                            != PackageManager.PERMISSION_GRANTED
                        ) {
                            result.error("PERMISSION_DENIED", "READ_SMS permission not granted", null)
                            return@setMethodCallHandler
                        }
                        // sinceMs: epoch ms — only return messages AFTER this time (null = all)
                        val sinceMs = call.argument<Long>("sinceMs")
                        try {
                            val uri = Uri.parse("content://sms/inbox")
                            val projection = arrayOf("address", "body", "date")
                            val (selection, selectionArgs) =
                                if (sinceMs != null)
                                    Pair("date > ?", arrayOf(sinceMs.toString()))
                                else
                                    Pair(null, null)

                            val cursor = contentResolver.query(
                                uri,
                                projection,
                                selection,
                                selectionArgs,
                                "date ASC"
                            )

                            val messages = mutableListOf<Map<String, Any?>>()
                            cursor?.use { c ->
                                val addrIdx = c.getColumnIndexOrThrow("address")
                                val bodyIdx = c.getColumnIndexOrThrow("body")
                                val dateIdx = c.getColumnIndexOrThrow("date")
                                while (c.moveToNext()) {
                                    messages.add(
                                        mapOf(
                                            "address" to c.getString(addrIdx),
                                            "body" to c.getString(bodyIdx),
                                            "date" to c.getLong(dateIdx),
                                        )
                                    )
                                }
                            }
                            result.success(messages)
                        } catch (e: Exception) {
                            result.error("QUERY_FAILED", "SMS query error: ${e.message}", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
