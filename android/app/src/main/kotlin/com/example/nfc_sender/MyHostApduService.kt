package com.example.nfc_sender

import android.nfc.cardemulation.HostApduService
import android.os.Bundle
import android.util.Log

class MyHostApduService : HostApduService() {

    private val APDU_SELECT = byteArrayOf(
        0x00.toByte(), 0xA4.toByte(), 0x04.toByte(), 0x00.toByte(),
        0x07.toByte(), 0xD2.toByte(), 0x76.toByte(), 0x00.toByte(),
        0x00.toByte(), 0x85.toByte(), 0x01.toByte(), 0x01.toByte(),
        0x00.toByte()
    )

    private val CAPABILITY_CONTAINER_FILE = byteArrayOf(
        0x00, 0x0F, // CCI Length
        0x20, // Mapping Version 2.0
        0x00, 0x3B, // MLe (Max R-APDU data size) - 59 bytes
        0x00, 0x34, // MLc (Max C-APDU data size) - 52 bytes
        0x04, // T & L of NDEF File Control TLV
        0x06, // Length
        0xE1.toByte(), 0x04, // File Identifier
        0x00, 0x32, // Max NDEF size (hit limit)
        0x00, // Read Access (Free)
        0x00  // Write Access (Free)
    )

    private val NDEF_SELECT_OK = byteArrayOf(0x90.toByte(), 0x00.toByte())
    private val NDEF_READ_BINARY = 0xB0.toByte()
    private val NDEF_SELECT_FILE = 0xA4.toByte()

    override fun processCommandApdu(commandApdu: ByteArray?, extras: Bundle?): ByteArray {
        if (commandApdu == null) return ByteArray(0)

        // select aid
        if (commandApdu.size >= APDU_SELECT.size && commandApdu.sliceArray(0 until APDU_SELECT.size).contentEquals(APDU_SELECT)) {
            return NDEF_SELECT_OK
        }

        // select file (CC or NDEF)
        if (commandApdu[1] == NDEF_SELECT_FILE) {
            if (commandApdu[2] == 0x00.toByte() && commandApdu[3] == 0x0C.toByte()) {
                 // Select CC
                 return NDEF_SELECT_OK
            } else if (commandApdu[2] == 0x00.toByte() && commandApdu[3] == 0x0C.toByte()) {
                 return NDEF_SELECT_OK
            }
             // Assume any file select is OK for now (E103 or E104)
            return NDEF_SELECT_OK
        }

        // Read Binary
        if (commandApdu[1] == NDEF_READ_BINARY) {
            val offset = (commandApdu[2].toInt() and 0xFF) * 256 + (commandApdu[3].toInt() and 0xFF)
            val le = commandApdu[4].toInt() and 0xFF
            
            val payload = NfcDataStore.messageToTransmit
            // We need to wrap payload in NDEF File format: [Len High] [Len Low] [Payload]
            
            if (payload == null) return byteArrayOf(0x6A, 0x82.toByte()) // File not found

            val fullResponse = ByteArray(2 + payload.size)
            fullResponse[0] = ((payload.size shr 8) and 0xFF).toByte()
            fullResponse[1] = (payload.size and 0xFF).toByte()
            System.arraycopy(payload, 0, fullResponse, 2, payload.size)
            
            if (offset >= fullResponse.size) {
                 return byteArrayOf(0x6A, 0x82.toByte())
            }
            
            val lenToRead = Math.min(le, fullResponse.size - offset)
            val response = ByteArray(lenToRead + 2)
            System.arraycopy(fullResponse, offset, response, 0, lenToRead)
            response[lenToRead] = 0x90.toByte()
            response[lenToRead + 1] = 0x00.toByte()
            return response
        }

        return byteArrayOf(0x6F, 0x00) // Unknown
    }

    override fun onDeactivated(reason: Int) { }
}
