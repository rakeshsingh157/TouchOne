package com.example.nfc_sender

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.RingtoneManager
import android.nfc.NdefMessage
import android.nfc.NdefRecord
import android.nfc.NfcAdapter
import android.os.Build
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.nio.charset.Charset

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.nfc_sender/nfc"
    private val NOTIFICATION_CHANNEL_ID = "nfc_received_channel"
    private val NOTIFICATION_ID = 1001
    private var nfcAdapter: NfcAdapter? = null
    private var methodChannel: MethodChannel? = null
    private var notificationManager: NotificationManager? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "checkNfcAvailability" -> {
                    if (nfcAdapter == null) {
                        result.success("NOT_SUPPORTED")
                    } else if (!nfcAdapter!!.isEnabled) {
                        result.success("DISABLED")
                    } else {
                        result.success("AVAILABLE")
                    }
                }
                "openNfcSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN) {
                        startActivity(Intent(android.provider.Settings.ACTION_NFC_SETTINGS))
                    } else {
                        startActivity(Intent(android.provider.Settings.ACTION_WIRELESS_SETTINGS))
                    }
                    result.success(null)
                }
                "startNfc" -> {
                    val mode = call.argument<String>("mode")
                    val data = call.argument<String>("data")
                    if (data != null) {
                        prepareMessage(mode, data)
                        result.success("HCE Ready")
                    } else {
                        result.error("ERROR", "Data cannot be null", null)
                    }
                }
                "stopNfc" -> {
                    NfcDataStore.messageToTransmit = null
                    result.success("NFC Stopped")
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        nfcAdapter = NfcAdapter.getDefaultAdapter(this)
        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        createNotificationChannel()
        handleNfcIntent(intent)
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "NFC Received",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications when NFC data is received"
                enableVibration(true)
                setShowBadge(true)
            }
            notificationManager?.createNotificationChannel(channel)
        }
    }
    
    private fun showNotification(title: String, message: String, data: String) {
        // Vibrate
        val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(VibrationEffect.createOneShot(500, VibrationEffect.DEFAULT_AMPLITUDE))
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(500)
        }
        
        // Create intent for when notification is tapped
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("nfc_data", data)
        }
        
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
        )
        
        // Build notification
        val defaultSound = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        val notification = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(message)
            .setStyle(NotificationCompat.BigTextStyle().bigText(message))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setSound(defaultSound)
            .setVibrate(longArrayOf(0, 500, 200, 500))
            .setContentIntent(pendingIntent)
            .build()
        
        notificationManager?.notify(NOTIFICATION_ID, notification)
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleNfcIntent(intent)
    }
    
    private fun handleNfcIntent(intent: Intent?) {
        if (intent == null) return
        
        when (intent.action) {
            NfcAdapter.ACTION_NDEF_DISCOVERED -> {
                // Handle NDEF discovered
                val uri = intent.data
                if (uri != null) {
                    val uriString = uri.toString()
                    
                    // Show notification
                    showNotification(
                        "\ud83d\udcf2 NFC Received!",
                        "Link: $uriString",
                        uriString
                    )
                    
                    // Send to Flutter side
                    methodChannel?.invokeMethod("nfcReceived", mapOf(
                        "type" to "URL",
                        "data" to uriString
                    ))
                    
                    // Open in browser/app
                    try {
                        val viewIntent = Intent(Intent.ACTION_VIEW, uri)
                        viewIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(viewIntent)
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                } else {
                    // Try to parse raw NDEF message
                    val rawMessages = intent.getParcelableArrayExtra(NfcAdapter.EXTRA_NDEF_MESSAGES)
                    if (rawMessages != null && rawMessages.isNotEmpty()) {
                        val ndefMsg = rawMessages[0] as NdefMessage
                        val records = ndefMsg.records
                        if (records.isNotEmpty()) {
                            val record = records[0]
                            val payload = String(record.payload, Charset.forName("UTF-8"))
                            
                            // Show notification
                            showNotification(
                                "\ud83d\udcac NFC Text Received!",
                                payload,
                                payload
                            )
                            
                            methodChannel?.invokeMethod("nfcReceived", mapOf(
                                "type" to "TEXT",
                                "data" to payload
                            ))
                        }
                    }
                }
            }
            NfcAdapter.ACTION_TAG_DISCOVERED -> {
                // Show notification for generic tag
                showNotification(
                    "\ud83c\udff7\ufe0f NFC Tag Detected!",
                    "TouchOne detected an NFC tag",
                    "NFC Tag"
                )
                
                methodChannel?.invokeMethod("nfcReceived", mapOf(
                    "type" to "TAG",
                    "data" to "NFC Tag Detected"
                ))
            }
            NfcAdapter.ACTION_TECH_DISCOVERED -> {
                // Handle tech discovered
                showNotification(
                    "\ud83d\udd0d NFC Tech Discovered!",
                    "TouchOne detected NFC technology",
                    "NFC Tech"
                )
            }
        }
    }

    private fun prepareMessage(mode: String?, data: String) {
        val record: NdefRecord = if (mode == "CONTACT") {
            createMimeRecord("text/vcard", data.toByteArray())
        } else if (mode == "URL" || (data.startsWith("http") || data.startsWith("upi://"))) {
            NdefRecord.createUri(data)
        } else {
            createTextRecord(data)
        }
        val message = NdefMessage(record)
        NfcDataStore.messageToTransmit = message.toByteArray()
    }

    private fun createMimeRecord(mimeType: String, payload: ByteArray): NdefRecord {
        val mimeBytes = mimeType.toByteArray(Charset.forName("US-ASCII"))
        return NdefRecord(
            NdefRecord.TNF_MIME_MEDIA,
            mimeBytes,
            ByteArray(0),
            payload
        )
    }

    private fun createTextRecord(payload: String): NdefRecord {
        val lang = "en"
        val textBytes = payload.toByteArray(Charset.forName("UTF-8"))
        val langBytes = lang.toByteArray(Charset.forName("US-ASCII"))
        val langLength = langBytes.size
        val textLength = textBytes.size
        val payloadBytes = ByteArray(1 + langLength + textLength)

        payloadBytes[0] = langLength.toByte()
        System.arraycopy(langBytes, 0, payloadBytes, 1, langLength)
        System.arraycopy(textBytes, 0, payloadBytes, 1 + langLength, textLength)

        return NdefRecord(
            NdefRecord.TNF_WELL_KNOWN,
            NdefRecord.RTD_TEXT,
            ByteArray(0),
            payloadBytes
        )
    }
}
