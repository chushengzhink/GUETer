package com.gueter.cszm

import android.bluetooth.BluetoothAdapter
import android.content.Context
import android.location.LocationManager
import android.net.wifi.WifiManager
import android.os.Build
import android.util.Log
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.common.api.ApiException
import com.google.android.gms.nearby.Nearby
import com.google.android.gms.nearby.connection.AdvertisingOptions
import com.google.android.gms.nearby.connection.ConnectionInfo
import com.google.android.gms.nearby.connection.ConnectionLifecycleCallback
import com.google.android.gms.nearby.connection.ConnectionResolution
import com.google.android.gms.nearby.connection.ConnectionsClient
import com.google.android.gms.nearby.connection.ConnectionsStatusCodes
import com.google.android.gms.nearby.connection.DiscoveredEndpointInfo
import com.google.android.gms.nearby.connection.DiscoveryOptions
import com.google.android.gms.nearby.connection.EndpointDiscoveryCallback
import com.google.android.gms.nearby.connection.Payload
import com.google.android.gms.nearby.connection.PayloadCallback
import com.google.android.gms.nearby.connection.PayloadTransferUpdate
import com.google.android.gms.nearby.connection.Strategy
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import org.json.JSONObject

class NearbyHandler(private val mainActivity: MainActivity, private val context: Context) {
    private val connectionsClient: ConnectionsClient = Nearby.getConnectionsClient(context)
    private val serviceId = context.packageName
    private val strategy = Strategy.P2P_CLUSTER
    private val connectedEndpoints = mutableSetOf<String>()
    private val endpointIdToUser: MutableMap<String, Pair<String, String>> = mutableMapOf()
    private val endpointMetadata: MutableMap<String, Map<String, String>> = mutableMapOf()
    private val pendingHandshake: MutableSet<String> = mutableSetOf()
    private val incomingFilePayloads = mutableMapOf<Long, Pair<Payload, String>>()
    private val incomingFileMetadata = mutableMapOf<Long, Triple<String, String, String>>()
    private var currentRoomInfo: Map<String, String> = emptyMap()

    private var discoveryEvents: EventChannel.EventSink? = null
    private var messageEventSink: EventChannel.EventSink? = null
    private var connectionEventSink: EventChannel.EventSink? = null
    private var fileEventSink: EventChannel.EventSink? = null
    private var fileTransferProgressEvents: EventChannel.EventSink? = null

    private var isDiscovering = false
    private var isAdvertising = false
    private var lastStartupOk: Boolean? = null
    private var lastStartupOperation: String? = null
    private var lastStartupCode: String? = null
    private var lastStartupMessage: String? = null

    fun setDiscoveryEventSink(sink: EventChannel.EventSink?) {
        discoveryEvents = sink
    }

    fun setMessageEventSink(sink: EventChannel.EventSink?) {
        messageEventSink = sink
    }

    fun setConnectionEventSink(sink: EventChannel.EventSink?) {
        connectionEventSink = sink
    }

    fun setFileEventSink(sink: EventChannel.EventSink?) {
        fileEventSink = sink
    }

    fun setFileTransferProgressEventSink(sink: EventChannel.EventSink?) {
        fileTransferProgressEvents = sink
    }

    fun isDiscovering(): Boolean = isDiscovering

    fun isAdvertising(): Boolean = isAdvertising

    fun isPlayServicesReady(): Boolean = isPlayServicesAvailable()

    fun startDiscovery(result: MethodChannel.Result) {
        if (isDiscovering) {
            result.success(
                successResult(
                    operation = "discovery",
                    message = "Discovery is already running.",
                    code = "STATUS_ALREADY_DISCOVERING",
                    alreadyRunning = true
                )
            )
            return
        }

        Log.d("NearbyHandler", "Starting discovery with serviceId=$serviceId")
        connectionsClient.startDiscovery(
            serviceId,
            object : EndpointDiscoveryCallback() {
                override fun onEndpointFound(
                    endpointId: String,
                    info: DiscoveredEndpointInfo
                ) {
                    try {
                        val json = JSONObject(info.endpointName)
                        val userId = normalizedOptString(json, "userId", endpointId)
                        val name = normalizedOptString(json, "name", "Unknown")
                        val metadata = readRoomInfo(json, userId)
                        endpointIdToUser.entries.removeIf { it.value.first == userId }
                        endpointMetadata.entries.removeIf { it.value["userId"] == userId }
                        endpointIdToUser[endpointId] = Pair(userId, name)
                        endpointMetadata[endpointId] = metadata
                        if (!connectedEndpoints.contains(endpointId)) {
                            discoveryEvents?.success(foundEventMap(userId, name, metadata))
                        }
                    } catch (_: Exception) {
                        endpointIdToUser[endpointId] = Pair(endpointId, info.endpointName)
                        endpointMetadata[endpointId] = emptyMap()
                        discoveryEvents?.success(
                            mapOf(
                                "type" to "found",
                                "id" to endpointId,
                                "name" to info.endpointName
                            )
                        )
                    }
                }

                override fun onEndpointLost(endpointId: String) {
                    val userId = endpointIdToUser[endpointId]?.first ?: endpointId
                    if (!connectedEndpoints.contains(endpointId)) {
                        endpointIdToUser.remove(endpointId)
                        endpointMetadata.remove(endpointId)
                        pendingHandshake.remove(endpointId)
                        discoveryEvents?.success(mapOf("type" to "lost", "id" to userId))
                    }
                }
            },
            DiscoveryOptions.Builder().setStrategy(strategy).build()
        ).addOnSuccessListener {
            isDiscovering = true
            val response = successResult(
                operation = "discovery",
                message = "Discovery started successfully."
            )
            rememberStartupResult(response)
            result.success(response)
        }.addOnFailureListener { throwable ->
            isDiscovering = false
            val response = failureResult(
                operation = "discovery",
                throwable = throwable,
                fallbackMessage = "Failed to start discovery."
            )
            rememberStartupResult(response)
            result.success(response)
        }
    }

    fun stopDiscovery() {
        connectionsClient.stopDiscovery()
        isDiscovering = false
    }

    fun startAdvertising(endpointInfo: String, result: MethodChannel.Result) {
        if (isAdvertising) {
            result.success(
                successResult(
                    operation = "advertising",
                    message = "Advertising is already running.",
                    code = "STATUS_ALREADY_ADVERTISING",
                    alreadyRunning = true
                )
            )
            return
        }

        currentRoomInfo = try {
            val json = JSONObject(endpointInfo)
            readRoomInfo(json, normalizedOptString(json, "userId", "unknown"))
        } catch (_: Exception) {
            emptyMap()
        }

        connectionsClient.startAdvertising(
            endpointInfo,
            serviceId,
            advertiserLifecycleCallback(),
            AdvertisingOptions.Builder().setStrategy(strategy).build()
        ).addOnSuccessListener {
            isAdvertising = true
            val response = successResult(
                operation = "advertising",
                message = "Advertising started successfully."
            )
            rememberStartupResult(response)
            result.success(response)
        }.addOnFailureListener { throwable ->
            isAdvertising = false
            val response = failureResult(
                operation = "advertising",
                throwable = throwable,
                fallbackMessage = "Failed to start advertising."
            )
            rememberStartupResult(response)
            result.success(response)
        }
    }

    fun stopAdvertising() {
        try {
            notifyRoomClosed()
            connectionsClient.stopAdvertising()
        } catch (e: Exception) {
            connectionEventSink?.error("ADVERTISING_ERROR", e.message, e)
        } finally {
            isAdvertising = false
            currentRoomInfo = emptyMap()
        }
    }

    fun connectToDevice(userId: String) {
        val endpointId = getEndpointIdForUserId(userId) ?: return
        if (connectedEndpoints.contains(endpointId)) {
            connectionEventSink?.success(
                mapOf(
                    "type" to "connected",
                    "id" to userId,
                    "name" to (endpointIdToUser[endpointId]?.second ?: "Unknown")
                )
            )
            return
        }

        try {
            connectionsClient.requestConnection(
                endpointIdToUser[endpointId]?.second ?: "AirChatUser",
                endpointId,
                requesterLifecycleCallback(userId)
            )
        } catch (e: Exception) {
            connectionEventSink?.error("CONNECTION_ERROR", e.message, e)
        }
    }

    fun sendMessage(userId: String, message: String): Long? {
        val endpointId = getEndpointIdForUserId(userId) ?: return null
        val (myUserId, myName) = mainActivity.getMyUserIdAndName()
        val payload = Payload.fromBytes(
            JSONObject(
                mapOf("userId" to myUserId, "name" to myName, "message" to message)
            ).toString().toByteArray()
        )
        connectionsClient.sendPayload(endpointId, payload)
        return payload.id
    }

    fun sendControlMessage(userId: String, action: String, payload: Map<String, Any?>): Long? {
        val endpointId = getEndpointIdForUserId(userId) ?: return null
        val (myUserId, myName) = mainActivity.getMyUserIdAndName()
        val body = mutableMapOf<String, Any?>(
            "kind" to "control",
            "action" to action,
            "userId" to myUserId,
            "name" to myName
        )
        body.putAll(payload)
        val messagePayload = Payload.fromBytes(JSONObject(body).toString().toByteArray())
        connectionsClient.sendPayload(endpointId, messagePayload)
        return messagePayload.id
    }

    fun sendFile(userId: String, filePath: String, fileName: String): Long? {
        val endpointId = getEndpointIdForUserId(userId) ?: return null
        val file = File(filePath)
        if (!file.exists()) {
            return null
        }
        val payload = Payload.fromFile(file)
        payload.setFileName(fileName)
        connectionsClient.sendPayload(endpointId, payload)
        return payload.id
    }

    fun getEndpointIdForUserId(userId: String): String? {
        return endpointIdToUser.entries.firstOrNull { it.value.first == userId }?.key
    }

    fun getConnectedUsers(): List<Map<String, String>> {
        return connectedEndpoints.mapNotNull { endpointId ->
            val pair = endpointIdToUser[endpointId] ?: return@mapNotNull null
            buildUserMap(pair.first, pair.second, endpointMetadata[endpointId], true)
        }
    }

    fun getDiscoveredUsers(): List<Map<String, String>> {
        return endpointIdToUser.map { (endpointId, info) ->
            buildUserMap(info.first, info.second, endpointMetadata[endpointId], false)
        }
    }

    fun getEnvironmentStatus(): Map<String, Any?> {
        return mapOf(
            "sdkInt" to Build.VERSION.SDK_INT,
            "locationServicesEnabled" to isLocationServicesEnabled(),
            "bluetoothEnabled" to isBluetoothEnabled(),
            "wifiEnabled" to isWifiEnabled(),
            "playServicesAvailable" to isPlayServicesAvailable(),
            "nearbySupported" to true,
            "discoveryRunning" to isDiscovering,
            "advertisingRunning" to isAdvertising,
            "lastNearbyOk" to lastStartupOk,
            "lastNearbyOperation" to lastStartupOperation,
            "lastNearbyCode" to lastStartupCode,
            "lastNearbyMessage" to lastStartupMessage,
            "serviceId" to serviceId
        )
    }

    fun cleanup() {
        try {
            stopDiscovery()
            stopAdvertising()
            connectedEndpoints.toList().forEach { endpointId ->
                connectionsClient.disconnectFromEndpoint(endpointId)
            }
            connectedEndpoints.clear()
            endpointIdToUser.clear()
            pendingHandshake.clear()
            endpointMetadata.clear()
            incomingFilePayloads.clear()
            incomingFileMetadata.clear()
            discoveryEvents = null
            messageEventSink = null
            connectionEventSink = null
            fileEventSink = null
            fileTransferProgressEvents = null
        } catch (e: Exception) {
            Log.e("NearbyHandler", "Cleanup error: ${e.message}")
        }
    }

    private fun advertiserLifecycleCallback(): ConnectionLifecycleCallback {
        return object : ConnectionLifecycleCallback() {
            override fun onConnectionInitiated(endpointId: String, connectionInfo: ConnectionInfo) {
                pendingHandshake.add(endpointId)
                connectionsClient.acceptConnection(endpointId, payloadCallback())
            }

            override fun onConnectionResult(endpointId: String, result: ConnectionResolution) {
                val pair = endpointIdToUser[endpointId] ?: Pair(endpointId, "Unknown")
                if (result.status.isSuccess) {
                    connectedEndpoints.add(endpointId)
                    connectionEventSink?.success(
                        buildConnectionEventMap("connected", pair.first, pair.second, endpointMetadata[endpointId])
                    )
                } else {
                    connectionEventSink?.success(
                        buildConnectionEventMap(
                            "failed",
                            pair.first,
                            pair.second,
                            endpointMetadata[endpointId],
                            result.status.statusCode,
                            readableNearbyStatus(result.status.statusCode, "Connection failed.")
                        )
                    )
                }
            }

            override fun onDisconnected(endpointId: String) {
                connectedEndpoints.remove(endpointId)
                val pair = endpointIdToUser[endpointId] ?: Pair(endpointId, "Unknown")
                connectionEventSink?.success(
                    buildConnectionEventMap("disconnected", pair.first, pair.second, endpointMetadata[endpointId])
                )
            }
        }
    }

    private fun requesterLifecycleCallback(userId: String): ConnectionLifecycleCallback {
        return object : ConnectionLifecycleCallback() {
            override fun onConnectionInitiated(endpointId: String, connectionInfo: ConnectionInfo) {
                connectionsClient.acceptConnection(endpointId, payloadCallback())
            }

            override fun onConnectionResult(endpointId: String, result: ConnectionResolution) {
                val pair = endpointIdToUser[endpointId] ?: Pair(endpointId, "Unknown")
                if (result.status.isSuccess) {
                    connectedEndpoints.add(endpointId)
                    val (myUserId, myName) = mainActivity.getMyUserIdAndName()
                    val handshake = JSONObject(
                        mapOf("userId" to myUserId, "name" to myName)
                    ).toString()
                    connectionsClient.sendPayload(
                        endpointId,
                        Payload.fromBytes(handshake.toByteArray())
                    )
                    connectionEventSink?.success(
                        buildConnectionEventMap("connected", userId, pair.second, endpointMetadata[endpointId])
                    )
                } else {
                    connectionEventSink?.success(
                        buildConnectionEventMap(
                            "failed",
                            userId,
                            pair.second,
                            endpointMetadata[endpointId],
                            result.status.statusCode,
                            readableNearbyStatus(result.status.statusCode, "Connection failed.")
                        )
                    )
                }
            }

            override fun onDisconnected(endpointId: String) {
                connectedEndpoints.remove(endpointId)
                val pair = endpointIdToUser[endpointId] ?: Pair(endpointId, "Unknown")
                connectionEventSink?.success(
                    buildConnectionEventMap("disconnected", userId, pair.second, endpointMetadata[endpointId])
                )
            }
        }
    }

    private fun payloadCallback(): PayloadCallback {
        return object : PayloadCallback() {
            override fun onPayloadReceived(endpointId: String, payload: Payload) {
                if (payload.type == Payload.Type.FILE) {
                    incomingFilePayloads[payload.id] = Pair(payload, endpointId)
                    val pair = endpointIdToUser[endpointId] ?: Pair(endpointId, "Unknown")
                    incomingFileMetadata[payload.id] = Triple(endpointId, pair.first, pair.second)
                    return
                }

                payload.asBytes()?.let { data ->
                    try {
                        val json = JSONObject(String(data))
                        val inUserId = normalizedOptString(json, "userId", endpointId)
                        val name = normalizedOptString(json, "name", "Unknown")
                        val message = normalizedOptString(json, "message", "")
                        val kind = normalizedOptString(json, "kind", "")
                        val action = normalizedOptString(json, "action", "")

                        if (pendingHandshake.contains(endpointId)) {
                            endpointIdToUser[endpointId] = Pair(inUserId, name)
                            endpointMetadata[endpointId] = readRoomInfo(json, inUserId)
                            pendingHandshake.remove(endpointId)
                            connectionEventSink?.success(
                                buildConnectionEventMap("connected", inUserId, name, endpointMetadata[endpointId])
                            )
                        }

                        if (kind == "control" && action.isNotEmpty()) {
                            val event = mutableMapOf<String, Any?>(
                                "type" to "control",
                                "from" to inUserId,
                                "name" to name,
                                "action" to action,
                                "roomId" to normalizedOptString(json, "roomId", ""),
                                "roomName" to normalizedOptString(json, "roomName", ""),
                                "roomType" to normalizedOptString(json, "roomType", ""),
                                "hostUserId" to normalizedOptString(json, "hostUserId", ""),
                                "courseId" to normalizedOptString(json, "courseId", ""),
                                "platform" to normalizedOptString(json, "platform", ""),
                                "message" to normalizedOptString(json, "message", ""),
                                "payloadId" to payload.id
                            )
                            messageEventSink?.success(event)
                        } else if (message.isNotEmpty()) {
                            messageEventSink?.success(
                                mapOf(
                                    "from" to inUserId,
                                    "payloadId" to payload.id,
                                    "name" to name,
                                    "message" to message
                                )
                            )
                        }
                    } catch (e: Exception) {
                        Log.e("NearbyHandler", "Payload parse error: ${e.message}")
                    }
                }
            }

            override fun onPayloadTransferUpdate(endpointId: String, update: PayloadTransferUpdate) {
                fileTransferProgressEvents?.success(
                    mapOf(
                        "payloadId" to update.payloadId,
                        "bytesTransferred" to update.bytesTransferred,
                        "totalBytes" to update.totalBytes,
                        "status" to update.status
                    )
                )

                if (update.status == PayloadTransferUpdate.Status.SUCCESS) {
                    val pair = incomingFilePayloads.remove(update.payloadId)
                    val meta = incomingFileMetadata.remove(update.payloadId)
                    if (pair != null && meta != null) {
                        val payload = pair.first
                        val userId = meta.second
                        val name = meta.third
                        val uri = payload.asFile()?.asUri()
                        if (uri != null) {
                            val fileName = uri.lastPathSegment
                                ?.substringAfterLast('/')
                                ?.ifBlank { null }
                                ?: "received_file_${update.payloadId}"
                            val inputStream = context.contentResolver.openInputStream(uri)
                            val outputFile = File(context.filesDir, fileName)
                            inputStream?.use { input ->
                                outputFile.outputStream().use { output ->
                                    input.copyTo(output)
                                }
                            }
                            fileEventSink?.success(
                                mapOf(
                                    "payloadId" to update.payloadId,
                                    "from" to userId,
                                    "name" to name,
                                    "filePath" to outputFile.absolutePath,
                                    "type" to resolveFileType(outputFile),
                                    "fileName" to fileName
                                )
                            )
                        }
                    }
                }
            }
        }
    }

    private fun rememberStartupResult(result: Map<String, Any?>) {
        lastStartupOk = result["ok"] as? Boolean
        lastStartupOperation = result["operation"] as? String
        lastStartupCode = result["code"] as? String
        lastStartupMessage = result["message"] as? String
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
        throwable: Throwable,
        fallbackMessage: String
    ): Map<String, Any?> {
        val apiException = throwable as? ApiException
        val statusCode = apiException?.statusCode
        val code = if (statusCode == null) {
            throwable.javaClass.simpleName
        } else {
            ConnectionsStatusCodes.getStatusCodeString(statusCode)
        }
        return mapOf(
            "ok" to false,
            "operation" to operation,
            "statusCode" to statusCode,
            "code" to code,
            "message" to readableNearbyStatus(statusCode, throwable.message ?: fallbackMessage),
            "alreadyRunning" to false
        )
    }

    private fun readableNearbyStatus(statusCode: Int?, fallbackMessage: String): String {
        if (statusCode == null) {
            return fallbackMessage
        }
        return when (ConnectionsStatusCodes.getStatusCodeString(statusCode)) {
            "MISSING_PERMISSION_NEARBY_WIFI_DEVICES" ->
                "Nearby Wi-Fi Devices permission is missing on Android 13+."
            "MISSING_PERMISSION_ACCESS_FINE_LOCATION" ->
                "Precise location permission is required."
            "MISSING_PERMISSION_ACCESS_COARSE_LOCATION" ->
                "Location permission is required."
            "MISSING_PERMISSION_ACCESS_WIFI_STATE" ->
                "Wi-Fi state permission is missing."
            "MISSING_PERMISSION_BLUETOOTH_SCAN" ->
                "Bluetooth scan permission is missing."
            "MISSING_PERMISSION_BLUETOOTH_CONNECT" ->
                "Bluetooth connect permission is missing."
            "MISSING_PERMISSION_BLUETOOTH_ADVERTISE" ->
                "Bluetooth advertise permission is missing."
            "STATUS_ALREADY_DISCOVERING" ->
                "Discovery is already running."
            "STATUS_ALREADY_ADVERTISING" ->
                "Advertising is already running."
            "API_CONNECTION_FAILED_ALREADY_IN_USE" ->
                "Nearby is already in use by another app or session."
            "RADIO_ERROR" ->
                "Bluetooth or Wi-Fi radio is unavailable."
            "NETWORK_NOT_CONNECTED" ->
                "Network stack is not ready. Try enabling Wi-Fi and Bluetooth."
            else -> "$fallbackMessage (code=${ConnectionsStatusCodes.getStatusCodeString(statusCode)})"
        }
    }

    private fun isLocationServicesEnabled(): Boolean {
        return try {
            val locationManager =
                context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
            locationManager?.isLocationEnabled == true
        } catch (_: Exception) {
            false
        }
    }

    private fun isBluetoothEnabled(): Boolean {
        return try {
            BluetoothAdapter.getDefaultAdapter()?.isEnabled == true
        } catch (_: SecurityException) {
            false
        } catch (_: Exception) {
            false
        }
    }

    private fun isWifiEnabled(): Boolean {
        return try {
            val wifiManager =
                context.applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
            wifiManager?.isWifiEnabled == true
        } catch (_: SecurityException) {
            false
        } catch (_: Exception) {
            false
        }
    }

    private fun isPlayServicesAvailable(): Boolean {
        val status = GoogleApiAvailability.getInstance().isGooglePlayServicesAvailable(context)
        return status == ConnectionResult.SUCCESS
    }

    private fun resolveFileType(file: File): String {
        val ext = file.extension.lowercase()
        return when (ext) {
            "jpg", "jpeg", "png", "gif", "bmp", "webp" -> "image"
            "mp4", "mov", "avi", "mkv", "webm" -> "video"
            else -> "file"
        }
    }

    private fun readRoomInfo(json: JSONObject, defaultUserId: String): Map<String, String> {
        val roomId = normalizedOptString(json, "roomId", "")
        val roomName = normalizedOptString(json, "roomName", "")
        val roomType = normalizedOptString(json, "roomType", "nearby_pairing")
        val hostUserId = normalizedOptString(json, "hostUserId", defaultUserId)
        val courseId = normalizedOptString(json, "courseId", "")
        val platform = normalizedOptString(json, "platform", "")
        return mapOf(
            "userId" to defaultUserId,
            "roomId" to roomId,
            "roomName" to roomName,
            "roomType" to roomType,
            "hostUserId" to hostUserId,
            "courseId" to courseId,
            "platform" to platform
        )
    }

    private fun foundEventMap(userId: String, name: String, metadata: Map<String, String>): Map<String, Any?> {
        val event = mutableMapOf<String, Any?>(
            "type" to "found",
            "id" to userId,
            "name" to name
        )
        event.putAll(metadata)
        return event
    }

    private fun buildConnectionEventMap(
        type: String,
        userId: String,
        name: String,
        metadata: Map<String, String>?,
        status: Int? = null,
        statusText: String? = null
    ): Map<String, Any?> {
        val event = mutableMapOf<String, Any?>(
            "type" to type,
            "id" to userId,
            "name" to name
        )
        metadata?.let { event.putAll(it) }
        if (status != null) {
            event["status"] = status
        }
        if (statusText != null) {
            event["statusText"] = statusText
        }
        return event
    }

    private fun buildUserMap(
        userId: String,
        name: String,
        metadata: Map<String, String>?,
        isConnected: Boolean
    ): Map<String, String> {
        val result = mutableMapOf(
            "id" to userId,
            "name" to name,
            "isConnected" to isConnected.toString()
        )
        metadata?.let { result.putAll(it) }
        return result
    }

    private fun normalizedOptString(json: JSONObject, key: String, fallback: String): String {
        val value = json.optString(key, fallback).trim()
        if (value.isEmpty() || value.equals("null", ignoreCase = true)) {
            return fallback
        }
        return value
    }

    private fun notifyRoomClosed() {
        if (connectedEndpoints.isEmpty() || currentRoomInfo.isEmpty()) {
            return
        }
        val (myUserId, myName) = mainActivity.getMyUserIdAndName()
        val body = JSONObject(
            mapOf(
                "kind" to "control",
                "action" to "room_closed",
                "userId" to myUserId,
                "name" to myName,
                "roomId" to (currentRoomInfo["roomId"] ?: ""),
                "roomName" to (currentRoomInfo["roomName"] ?: ""),
                "roomType" to (currentRoomInfo["roomType"] ?: ""),
                "hostUserId" to (currentRoomInfo["hostUserId"] ?: myUserId),
                "courseId" to (currentRoomInfo["courseId"] ?: ""),
                "platform" to (currentRoomInfo["platform"] ?: ""),
                "message" to "The host closed the nearby room."
            )
        ).toString().toByteArray()
        val payload = Payload.fromBytes(body)
        connectedEndpoints.forEach { endpointId ->
            connectionsClient.sendPayload(endpointId, payload)
        }
    }
}
