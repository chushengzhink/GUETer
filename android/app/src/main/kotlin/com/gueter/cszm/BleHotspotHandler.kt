package com.gueter.cszm

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothGattServer
import android.bluetooth.BluetoothGattServerCallback
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.ParcelUuid
import android.util.Log
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.nio.charset.StandardCharsets
import java.util.UUID
import org.json.JSONObject

class BleHotspotHandler(
    private val mainActivity: MainActivity,
    private val context: Context
) {
    companion object {
        private val serviceUuid: UUID = UUID.fromString("4e8b5327-72db-4e6c-85ad-fdb1cdb40cc0")
        private val roomInfoUuid: UUID = UUID.fromString("4e8b5327-72db-4e6c-85ad-fdb1cdb40cc1")
        private val summaryUuid: UUID = UUID.fromString("4e8b5327-72db-4e6c-85ad-fdb1cdb40cc2")
        private val descriptorUuid: UUID =
            UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
    }

    private val bluetoothManager: BluetoothManager? =
        context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager

    private val bluetoothAdapter: BluetoothAdapter?
        get() = bluetoothManager?.adapter

    private val advertiser: BluetoothLeAdvertiser?
        get() = bluetoothAdapter?.bluetoothLeAdvertiser

    private val scanner: BluetoothLeScanner?
        get() = bluetoothAdapter?.bluetoothLeScanner

    private var discoveryEvents: EventChannel.EventSink? = null
    private var connectionEventSink: EventChannel.EventSink? = null

    private val discoveredDevices: MutableMap<String, MutableMap<String, Any?>> = mutableMapOf()
    private val connectedDevices: MutableMap<String, MutableMap<String, Any?>> = mutableMapOf()
    private val activeGattConnections: MutableMap<String, BluetoothGatt> = mutableMapOf()

    private var scanCallback: ScanCallback? = null
    private var advertiseCallback: AdvertiseCallback? = null
    private var gattServer: BluetoothGattServer? = null

    private var advertisedRoomPayload: String = "{}"
    private var advertisedMetadata: MutableMap<String, Any?> = mutableMapOf()
    private var isDiscovering: Boolean = false
    private var isAdvertising: Boolean = false

    fun setDiscoveryEventSink(sink: EventChannel.EventSink?) {
        discoveryEvents = sink
    }

    fun setConnectionEventSink(sink: EventChannel.EventSink?) {
        connectionEventSink = sink
    }

    fun isBleAvailable(): Boolean {
        return bluetoothAdapter != null &&
            context.packageManager.hasSystemFeature(PackageManager.FEATURE_BLUETOOTH_LE)
    }

    fun isHotspotCapable(): Boolean {
        return context.packageManager.hasSystemFeature(PackageManager.FEATURE_WIFI)
    }

    fun isDiscovering(): Boolean = isDiscovering

    fun isAdvertising(): Boolean = isAdvertising

    fun getDiscoveredUsers(): List<Map<String, Any?>> = discoveredDevices.values.map { it.toMap() }

    fun getConnectedUsers(): List<Map<String, Any?>> = connectedDevices.values.map { it.toMap() }

    fun startDiscovery(result: MethodChannel.Result) {
        if (isDiscovering) {
            result.success(
                successResult(
                    operation = "ble_discovery",
                    message = "BLE discovery is already running.",
                    code = "STATUS_ALREADY_DISCOVERING",
                    alreadyRunning = true
                )
            )
            return
        }
        if (!isBleAvailable()) {
            result.success(
                failureResult(
                    operation = "ble_discovery",
                    code = "BLE_UNAVAILABLE",
                    message = "Bluetooth LE is unavailable on this device."
                )
            )
            return
        }
        val scanner = scanner
        if (scanner == null) {
            result.success(
                failureResult(
                    operation = "ble_discovery",
                    code = "SCANNER_UNAVAILABLE",
                    message = "Bluetooth LE scanner is unavailable."
                )
            )
            return
        }

        val filters = listOf(
            ScanFilter.Builder().setServiceUuid(ParcelUuid(serviceUuid)).build()
        )
        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()

        val callback =
            object : ScanCallback() {
                override fun onScanResult(callbackType: Int, result: ScanResult) {
                    handleScanResult(result)
                }

                override fun onBatchScanResults(results: MutableList<ScanResult>) {
                    results.forEach(::handleScanResult)
                }

                override fun onScanFailed(errorCode: Int) {
                    Log.e("BleHotspotHandler", "BLE scan failed: $errorCode")
                    connectionEventSink?.success(
                        buildConnectionEventMap(
                            type = "failed",
                            id = "ble-scan",
                            name = "BLE scanner",
                            metadata = null,
                            statusText = "BLE scan failed (code=$errorCode)."
                        )
                    )
                }
            }

        try {
            scanCallback = callback
            scanner.startScan(filters, settings, callback)
            isDiscovering = true
            result.success(
                successResult(
                    operation = "ble_discovery",
                    message = "BLE discovery started successfully."
                )
            )
        } catch (e: SecurityException) {
            isDiscovering = false
            result.success(
                failureResult(
                    operation = "ble_discovery",
                    code = "MISSING_PERMISSION",
                    message = e.message ?: "Bluetooth permission is missing."
                )
            )
        } catch (e: Exception) {
            isDiscovering = false
            result.success(
                failureResult(
                    operation = "ble_discovery",
                    code = e.javaClass.simpleName,
                    message = e.message ?: "Failed to start BLE discovery."
                )
            )
        }
    }

    fun stopDiscovery() {
        try {
            scanCallback?.let { callback ->
                scanner?.stopScan(callback)
            }
        } catch (_: Exception) {
        } finally {
            scanCallback = null
            isDiscovering = false
        }
    }

    fun startAdvertising(endpointInfo: String, result: MethodChannel.Result) {
        if (isAdvertising) {
            result.success(
                successResult(
                    operation = "ble_advertising",
                    message = "BLE advertising is already running.",
                    code = "STATUS_ALREADY_ADVERTISING",
                    alreadyRunning = true
                )
            )
            return
        }
        if (!isBleAvailable()) {
            result.success(
                failureResult(
                    operation = "ble_advertising",
                    code = "BLE_UNAVAILABLE",
                    message = "Bluetooth LE is unavailable on this device."
                )
            )
            return
        }

        val advertiser = advertiser
        if (advertiser == null) {
            result.success(
                failureResult(
                    operation = "ble_advertising",
                    code = "ADVERTISER_UNAVAILABLE",
                    message = "Bluetooth LE advertiser is unavailable."
                )
            )
            return
        }

        val roomJson = JSONObject(endpointInfo)
        advertisedRoomPayload = endpointInfo
        advertisedMetadata = readRoomInfo(roomJson)
        val hotspotSsid = normalizedOptString(roomJson, "hotspotSsid", "")
        val hotspotPassword = normalizedOptString(roomJson, "hotspotPassword", "")
        if (hotspotSsid.isBlank() || hotspotPassword.isBlank()) {
            result.success(
                failureResult(
                    operation = "ble_advertising",
                    code = "HOTSPOT_CONFIG_MISSING",
                    message = "BLE + hotspot mode requires hotspot name and password."
                )
            )
            return
        }

        try {
            setupGattServer()
            val advertiseSettings = AdvertiseSettings.Builder()
                .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
                .setConnectable(true)
                .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM)
                .build()
            val summary = buildSummaryPayload(advertisedMetadata)
            val advertiseData = AdvertiseData.Builder()
                .setIncludeDeviceName(false)
                .addServiceUuid(ParcelUuid(serviceUuid))
                .addServiceData(
                    ParcelUuid(summaryUuid),
                    summary.toByteArray(StandardCharsets.UTF_8)
                )
                .build()
            val callback =
                object : AdvertiseCallback() {
                    override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
                        isAdvertising = true
                        result.success(
                            successResult(
                                operation = "ble_advertising",
                                message = "BLE hotspot room is advertising."
                            )
                        )
                    }

                    override fun onStartFailure(errorCode: Int) {
                        isAdvertising = false
                        result.success(
                            failureResult(
                                operation = "ble_advertising",
                                code = "ADVERTISE_FAIL_$errorCode",
                                message = "BLE advertising failed (code=$errorCode)."
                            )
                        )
                    }
                }
            advertiseCallback = callback
            advertiser.startAdvertising(advertiseSettings, advertiseData, callback)
        } catch (e: SecurityException) {
            isAdvertising = false
            result.success(
                failureResult(
                    operation = "ble_advertising",
                    code = "MISSING_PERMISSION",
                    message = e.message ?: "Bluetooth advertise permission is missing."
                )
            )
        } catch (e: Exception) {
            isAdvertising = false
            result.success(
                failureResult(
                    operation = "ble_advertising",
                    code = e.javaClass.simpleName,
                    message = e.message ?: "Failed to start BLE advertising."
                )
            )
        }
    }

    fun stopAdvertising() {
        try {
            advertiseCallback?.let { callback ->
                advertiser?.stopAdvertising(callback)
            }
        } catch (_: Exception) {
        } finally {
            advertiseCallback = null
            isAdvertising = false
        }
        try {
            gattServer?.close()
        } catch (_: Exception) {
        } finally {
            gattServer = null
        }
    }

    @SuppressLint("MissingPermission")
    fun connectToDevice(userId: String) {
        val metadata = discoveredDevices[userId]
        if (metadata == null) {
            connectionEventSink?.success(
                buildConnectionEventMap(
                    type = "failed",
                    id = userId,
                    name = "BLE room",
                    metadata = null,
                    statusText = "The BLE room is no longer available."
                )
            )
            return
        }

        val address = userId
        val device = bluetoothAdapter?.getRemoteDevice(address)
        if (device == null) {
            connectionEventSink?.success(
                buildConnectionEventMap(
                    type = "failed",
                    id = userId,
                    name = metadata["name"] as? String ?: "BLE room",
                    metadata = metadata,
                    statusText = "Failed to resolve the target BLE device."
                )
            )
            return
        }

        try {
            connectionEventSink?.success(
                buildConnectionEventMap(
                    type = "connecting",
                    id = address,
                    name = metadata["name"] as? String ?: "BLE room",
                    metadata = metadata,
                    statusText = "Connecting to BLE room..."
                )
            )
            val gatt =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    device.connectGatt(
                        context,
                        false,
                        createGattCallback(address),
                        BluetoothDevice.TRANSPORT_LE
                    )
                } else {
                    device.connectGatt(context, false, createGattCallback(address))
                }
            activeGattConnections[address] = gatt
        } catch (e: SecurityException) {
            connectionEventSink?.success(
                buildConnectionEventMap(
                    type = "failed",
                    id = address,
                    name = metadata["name"] as? String ?: "BLE room",
                    metadata = metadata,
                    statusText = e.message ?: "Bluetooth connect permission is missing."
                )
            )
        } catch (e: Exception) {
            connectionEventSink?.success(
                buildConnectionEventMap(
                    type = "failed",
                    id = address,
                    name = metadata["name"] as? String ?: "BLE room",
                    metadata = metadata,
                    statusText = e.message ?: "Failed to connect to BLE room."
                )
            )
        }
    }

    fun cleanup() {
        stopDiscovery()
        stopAdvertising()
        activeGattConnections.values.forEach {
            try {
                it.disconnect()
                it.close()
            } catch (_: Exception) {
            }
        }
        activeGattConnections.clear()
        discoveredDevices.clear()
        connectedDevices.clear()
        discoveryEvents = null
        connectionEventSink = null
    }

    @SuppressLint("MissingPermission")
    private fun handleScanResult(result: ScanResult) {
        val device = result.device ?: return
        val adapterAddress = try {
            bluetoothAdapter?.address
        } catch (_: SecurityException) {
            null
        }
        if (!adapterAddress.isNullOrBlank() && adapterAddress == device.address) {
            return
        }
        val summaryData =
            result.scanRecord?.getServiceData(ParcelUuid(summaryUuid))
                ?.toString(StandardCharsets.UTF_8)
        val parsed = parseSummaryPayload(summaryData)
        val address = device.address ?: return
        val name = parsed["name"] ?: device.name ?: "Nearby User"
        val roomName = parsed["roomName"] ?: "$name room"
        val metadata =
            mutableMapOf<String, Any?>(
                "id" to address,
                "userId" to address,
                "name" to name,
                "roomId" to "ble-room-$address",
                "roomName" to roomName,
                "roomType" to "ble_hotspot_pairing",
                "hostUserId" to address,
                "transportMode" to "ble_hotspot",
                "discoveryMethod" to "ble",
                "requiresManualHotspotStep" to true
            )
        val previous = discoveredDevices[address]
        discoveredDevices[address] = metadata
        if (previous != metadata) {
            discoveryEvents?.success(
                mutableMapOf<String, Any?>("type" to "found").apply { putAll(metadata) }
            )
        }
    }

    private fun createGattCallback(address: String): BluetoothGattCallback {
        return object : BluetoothGattCallback() {
            override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
                if (newState == BluetoothProfile.STATE_CONNECTED) {
                    try {
                        gatt.discoverServices()
                    } catch (e: SecurityException) {
                        emitFailureForAddress(address, e.message ?: "Bluetooth permission missing.")
                    }
                } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                    activeGattConnections.remove(address)
                    try {
                        gatt.close()
                    } catch (_: Exception) {
                    }
                }
            }

            override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
                val service = gatt.getService(serviceUuid)
                val characteristic = service?.getCharacteristic(roomInfoUuid)
                if (characteristic == null) {
                    emitFailureForAddress(address, "BLE room information is unavailable.")
                    closeGatt(address, gatt)
                    return
                }
                try {
                    gatt.readCharacteristic(characteristic)
                } catch (e: SecurityException) {
                    emitFailureForAddress(address, e.message ?: "Bluetooth permission missing.")
                    closeGatt(address, gatt)
                }
            }

            @Deprecated("Deprecated in API 33")
            override fun onCharacteristicRead(
                gatt: BluetoothGatt,
                characteristic: BluetoothGattCharacteristic,
                status: Int
            ) {
                if (characteristic.uuid != roomInfoUuid) {
                    return
                }
                val payload = characteristic.value?.toString(StandardCharsets.UTF_8).orEmpty()
                onRoomInfoRead(address, payload)
                closeGatt(address, gatt)
            }

            override fun onCharacteristicRead(
                gatt: BluetoothGatt,
                characteristic: BluetoothGattCharacteristic,
                value: ByteArray,
                status: Int
            ) {
                if (characteristic.uuid != roomInfoUuid) {
                    return
                }
                val payload = value.toString(StandardCharsets.UTF_8)
                onRoomInfoRead(address, payload)
                closeGatt(address, gatt)
            }
        }
    }

    private fun onRoomInfoRead(address: String, payload: String) {
        try {
            val metadata = discoveredDevices[address]?.toMutableMap() ?: mutableMapOf()
            val json = JSONObject(payload)
            metadata.putAll(readRoomInfo(json))
            metadata["id"] = address
            metadata["userId"] = address
            metadata["transportMode"] = "ble_hotspot"
            metadata["discoveryMethod"] = "ble"
            metadata["requiresManualHotspotStep"] = true
            metadata["hotspotSsid"] = normalizedOptString(json, "hotspotSsid", "")
            metadata["hotspotPassword"] = normalizedOptString(json, "hotspotPassword", "")
            metadata["hotspotNote"] = normalizedOptString(json, "hotspotNote", "")
            connectedDevices[address] = metadata
            discoveredDevices[address] = metadata
            connectionEventSink?.success(
                buildConnectionEventMap(
                    type = "connected",
                    id = address,
                    name = metadata["name"] as? String ?: "Nearby User",
                    metadata = metadata,
                    statusText = buildJoinMessage(metadata)
                )
            )
        } catch (e: Exception) {
            emitFailureForAddress(address, e.message ?: "Failed to read BLE room info.")
        }
    }

    private fun setupGattServer() {
        if (gattServer != null) {
            return
        }
        val manager = bluetoothManager ?: return
        gattServer =
            manager.openGattServer(
                context,
                object : BluetoothGattServerCallback() {
                    override fun onCharacteristicReadRequest(
                        device: BluetoothDevice,
                        requestId: Int,
                        offset: Int,
                        characteristic: BluetoothGattCharacteristic
                    ) {
                        if (characteristic.uuid != roomInfoUuid) {
                            gattServer?.sendResponse(
                                device,
                                requestId,
                                BluetoothGatt.GATT_FAILURE,
                                offset,
                                null
                            )
                            return
                        }
                        val raw = advertisedRoomPayload.toByteArray(StandardCharsets.UTF_8)
                        val data =
                            if (offset >= raw.size) {
                                byteArrayOf()
                            } else {
                                raw.copyOfRange(offset, raw.size)
                            }
                        gattServer?.sendResponse(
                            device,
                            requestId,
                            BluetoothGatt.GATT_SUCCESS,
                            offset,
                            data
                        )
                    }
                }
            )

        val roomInfoCharacteristic =
            BluetoothGattCharacteristic(
                roomInfoUuid,
                BluetoothGattCharacteristic.PROPERTY_READ,
                BluetoothGattCharacteristic.PERMISSION_READ
            )
        roomInfoCharacteristic.addDescriptor(
            BluetoothGattDescriptor(
                descriptorUuid,
                BluetoothGattDescriptor.PERMISSION_READ or
                    BluetoothGattDescriptor.PERMISSION_WRITE
            )
        )
        val service =
            BluetoothGattService(serviceUuid, BluetoothGattService.SERVICE_TYPE_PRIMARY).apply {
                addCharacteristic(roomInfoCharacteristic)
            }
        gattServer?.clearServices()
        gattServer?.addService(service)
    }

    private fun buildSummaryPayload(metadata: Map<String, Any?>): String {
        val name = (metadata["name"] as? String)?.trim().orEmpty().ifEmpty { "Nearby User" }
        val roomName =
            (metadata["roomName"] as? String)?.trim().orEmpty().ifEmpty { "$name room" }
        val compactName = name.take(18)
        val compactRoom = roomName.take(18)
        return "$compactName\u0001$compactRoom"
    }

    private fun parseSummaryPayload(raw: String?): Map<String, String> {
        if (raw.isNullOrBlank()) {
            return emptyMap()
        }
        val pieces = raw.split('\u0001')
        return buildMap {
            if (pieces.isNotEmpty() && pieces[0].isNotBlank()) {
                put("name", pieces[0].trim())
            }
            if (pieces.size > 1 && pieces[1].isNotBlank()) {
                put("roomName", pieces[1].trim())
            }
        }
    }

    private fun readRoomInfo(json: JSONObject): MutableMap<String, Any?> {
        val userId = normalizedOptString(json, "userId", "unknown")
        val name = normalizedOptString(json, "name", "Nearby User")
        val roomId = normalizedOptString(json, "roomId", "room-$userId")
        val roomName = normalizedOptString(json, "roomName", "$name room")
        val roomType = normalizedOptString(json, "roomType", "ble_hotspot_pairing")
        val hostUserId = normalizedOptString(json, "hostUserId", userId)
        val courseId = normalizedOptString(json, "courseId", "")
        val platform = normalizedOptString(json, "platform", "")
        return mutableMapOf(
            "name" to name,
            "roomId" to roomId,
            "roomName" to roomName,
            "roomType" to roomType,
            "hostUserId" to hostUserId,
            "courseId" to courseId,
            "platform" to platform
        )
    }

    private fun buildJoinMessage(metadata: Map<String, Any?>): String {
        val buffer = StringBuffer("Room info synced. Join the host hotspot to continue.")
        val ssid = (metadata["hotspotSsid"] as? String).orEmpty()
        val password = (metadata["hotspotPassword"] as? String).orEmpty()
        val note = (metadata["hotspotNote"] as? String).orEmpty()
        if (ssid.isNotBlank()) {
            buffer.append("\nHotspot: ").append(ssid)
        }
        if (password.isNotBlank()) {
            buffer.append("\nPassword: ").append(password)
        }
        if (note.isNotBlank()) {
            buffer.append("\nNote: ").append(note)
        }
        return buffer.toString()
    }

    private fun emitFailureForAddress(address: String, message: String) {
        val metadata = discoveredDevices[address]
        connectionEventSink?.success(
            buildConnectionEventMap(
                type = "failed",
                id = address,
                name = metadata?.get("name") as? String ?: "BLE room",
                metadata = metadata,
                statusText = message
            )
        )
    }

    private fun closeGatt(address: String, gatt: BluetoothGatt) {
        activeGattConnections.remove(address)
        try {
            gatt.disconnect()
            gatt.close()
        } catch (_: Exception) {
        }
    }

    private fun normalizedOptString(json: JSONObject, key: String, fallback: String): String {
        val raw = json.optString(key, fallback).trim()
        return if (raw.isBlank()) fallback else raw
    }

    private fun successResult(
        operation: String,
        message: String,
        code: String = "OK",
        alreadyRunning: Boolean = false
    ): Map<String, Any?> {
        return mapOf(
            "ok" to true,
            "operation" to operation,
            "statusCode" to null,
            "code" to code,
            "message" to message,
            "alreadyRunning" to alreadyRunning
        )
    }

    private fun failureResult(
        operation: String,
        code: String,
        message: String
    ): Map<String, Any?> {
        return mapOf(
            "ok" to false,
            "operation" to operation,
            "statusCode" to null,
            "code" to code,
            "message" to message,
            "alreadyRunning" to false
        )
    }

    private fun buildConnectionEventMap(
        type: String,
        id: String,
        name: String,
        metadata: Map<String, Any?>?,
        statusText: String? = null
    ): Map<String, Any?> {
        val event = mutableMapOf<String, Any?>(
            "type" to type,
            "id" to id,
            "name" to name
        )
        metadata?.let { event.putAll(it) }
        if (statusText != null) {
            event["statusText"] = statusText
        }
        return event
    }
}
