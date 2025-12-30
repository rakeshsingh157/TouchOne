package com.example.nfc_sender

import android.content.Intent
import android.nfc.NdefMessage
import android.nfc.NdefRecord
import android.nfc.NfcAdapter
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.nio.charset.Charset

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.nfc_sender/nfc"
    private var nfcAdapter: NfcAdapter? = null
    private var methodChannel: MethodChannel? = null

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
        handleNfcIntent(intent)
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
                    // Send to Flutter side
                    methodChannel?.invokeMethod("nfcReceived", mapOf(
                        "type" to "URL",
                        "data" to uri.toString()
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
                            
                            methodChannel?.invokeMethod("nfcReceived", mapOf(
                                "type" to "TEXT",
                                "data" to payload
                            ))
                        }
                    }
                }
            }
            NfcAdapter.ACTION_TAG_DISCOVERED -> {
                methodChannel?.invokeMethod("nfcReceived", mapOf(
                    "type" to "TAG",
                    "data" to "NFC Tag Detected"
                ))
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
