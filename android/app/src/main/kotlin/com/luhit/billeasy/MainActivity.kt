package com.luhit.billeasy

import android.content.ClipData
import android.content.Intent
import android.content.pm.PackageManager
import android.util.Log
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val TAG = "WhatsAppShare"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.luhit.billeasy/share")
            .setMethodCallHandler { call, result ->
                if (call.method == "whatsapp") {
                    val phone = call.argument<String>("phone") ?: ""
                    val filePath = call.argument<String>("filePath") ?: ""
                    val text = call.argument<String>("text") ?: ""

                    Log.d(TAG, "Sharing to phone=$phone file=$filePath")

                    // Find installed WhatsApp
                    val pkg = listOf("com.whatsapp", "com.whatsapp.w4b").firstOrNull { p ->
                        try {
                            packageManager.getPackageInfo(p, 0)
                            true
                        } catch (_: PackageManager.NameNotFoundException) {
                            false
                        }
                    }

                    if (pkg == null) {
                        result.error("NO_WA", "WhatsApp is not installed", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val hasFile = filePath.isNotEmpty() && File(filePath).exists()

                        val intent = if (hasFile) {
                            val authority = "${applicationContext.packageName}.fileprovider"
                            val fileUri = FileProvider.getUriForFile(this, authority, File(filePath))
                            Log.d(TAG, "FileProvider URI=$fileUri authority=$authority")
                            val mime = when {
                                filePath.endsWith(".pdf") -> "application/pdf"
                                filePath.endsWith(".png") -> "image/png"
                                filePath.endsWith(".jpg") || filePath.endsWith(".jpeg") -> "image/jpeg"
                                else -> "*/*"
                            }
                            Intent(Intent.ACTION_SEND).apply {
                                setPackage(pkg)
                                type = mime
                                putExtra(Intent.EXTRA_STREAM, fileUri)
                                if (text.isNotEmpty()) putExtra(Intent.EXTRA_TEXT, text)
                                clipData = ClipData.newRawUri("", fileUri)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                        } else {
                            // Text-only message (no file, e.g. reminders)
                            Intent(Intent.ACTION_SEND).apply {
                                setPackage(pkg)
                                type = "text/plain"
                                putExtra(Intent.EXTRA_TEXT, text)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                        }

                        // jid works for saved AND unsaved numbers that have WhatsApp
                        if (phone.isNotEmpty()) {
                            intent.putExtra("jid", "${phone}@s.whatsapp.net")
                            Log.d(TAG, "Set jid=${phone}@s.whatsapp.net")
                        }

                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to launch WhatsApp", e)
                        result.error("FAILED", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
