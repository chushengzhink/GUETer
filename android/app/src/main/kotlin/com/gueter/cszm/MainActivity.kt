package com.gueter.cszm

import android.content.Context
import android.content.Intent
import android.net.wifi.WifiManager
import android.os.Bundle
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val multicastChannel = "course_helper/local_transfer/multicast"
    private val airChatChannel = "airchat/connection"
    private val discoveryEventChannel = "airchat/discoveryEvents"
    private val messageEventChannel = "airchat/messageEvents"
    private val connectionEventChannel = "airchat/connectionEvents"
    private val fileEventChannel = "airchat/fileEvents"
    private val fileProgressEventChannel = "airchat/fileTransferProgressEvents"

    private var multicastLock: WifiManager.MulticastLock? = null
    private lateinit var nearbyHandler: NearbyHandler
    private lateinit var bleHotspotHandler: BleHotspotHandler
    private var myUserId: String = ""
    private var myName: String = "AirChatUser"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        nearbyHandler = NearbyHandler(this, this)
        bleHotspotHandler = BleHotspotHandler(this, this)
        try {
            val locationClientClass = Class.forName("com.baidu.location.LocationClient")
            val setAgreePrivacyMethod =
                locationClientClass.getMethod("setAgreePrivacy", Boolean::class.javaPrimitiveType)
            setAgreePrivacyMethod.invoke(null, true)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, multicastChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "acquire" -> {
                        try {
                            acquireMulticastLock()
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("multicast_acquire_failed", e.message, null)
                        }
                    }
                    "release" -> {
                        releaseMulticastLock()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, airChatChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startDiscovery" -> {
                        myName = call.argument<String>("name") ?: "AirChatUser"
                        myUserId = call.argument<String>("userId") ?: ""
                        val transportMode = call.argument<String>("transportMode") ?: resolveTransportMode()
                        if (myUserId.isEmpty()) {
                            result.error("INVALID_ARGUMENT", "User ID cannot be empty", null)
                            return@setMethodCallHandler
                        }
                        if (transportMode == "ble_hotspot") {
                            bleHotspotHandler.startDiscovery(result)
                        } else {
                            nearbyHandler.startDiscovery(result)
                        }
                    }
                    "stopDiscovery" -> {
                        when (call.argument<String>("transportMode")) {
                            "ble_hotspot" -> bleHotspotHandler.stopDiscovery()
                            "nearby_connections" -> nearbyHandler.stopDiscovery()
                            else -> {
                                bleHotspotHandler.stopDiscovery()
                                nearbyHandler.stopDiscovery()
                            }
                        }
                        result.success(null)
                    }
                    "startAdvertising" -> {
                        val endpointInfo = call.argument<String>("endpointInfo")
                            ?: "{\"name\":\"AirChatUser\",\"userId\":\"unknown\"}"
                        val transportMode = call.argument<String>("transportMode") ?: resolveTransportMode()
                        if (transportMode == "ble_hotspot") {
                            bleHotspotHandler.startAdvertising(endpointInfo, result)
                        } else {
                            nearbyHandler.startAdvertising(endpointInfo, result)
                        }
                    }
                    "stopAdvertising" -> {
                        when (call.argument<String>("transportMode")) {
                            "ble_hotspot" -> bleHotspotHandler.stopAdvertising()
                            "nearby_connections" -> nearbyHandler.stopAdvertising()
                            else -> {
                                bleHotspotHandler.stopAdvertising()
                                nearbyHandler.stopAdvertising()
                            }
                        }
                        result.success(null)
                    }
                    "sendMessage" -> {
                        val userId = call.argument<String>("userId")
                        val message = call.argument<String>("message")
                        if (userId != null && message != null) {
                            result.success(nearbyHandler.sendMessage(userId, message))
                        } else {
                            result.error("INVALID_ARGUMENT", "User ID and message required", null)
                        }
                    }
                    "sendControlMessage" -> {
                        val userId = call.argument<String>("userId")
                        val action = call.argument<String>("action")
                        val payload = call.argument<Map<String, Any?>>("payload")
                        if (userId != null && action != null && payload != null) {
                            result.success(nearbyHandler.sendControlMessage(userId, action, payload))
                        } else {
                            result.error(
                                "INVALID_ARGUMENT",
                                "userId, action and payload required",
                                null
                            )
                        }
                    }
                    "connectToDevice" -> {
                        val userId = call.argument<String>("userId")
                        val transportMode = call.argument<String>("transportMode") ?: resolveTransportMode()
                        if (userId != null) {
                            if (transportMode == "ble_hotspot") {
                                bleHotspotHandler.connectToDevice(userId)
                            } else {
                                nearbyHandler.connectToDevice(userId)
                            }
                            result.success(null)
                        } else {
                            result.error("INVALID_ARGUMENT", "User ID required", null)
                        }
                    }
                    "getEndpointIdForUserId" -> {
                        val userId = call.argument<String>("userId")
                        if (userId != null) {
                            result.success(nearbyHandler.getEndpointIdForUserId(userId))
                        } else {
                            result.error("INVALID_ARGUMENT", "User ID required", null)
                        }
                    }
                    "sendFile" -> {
                        val userId = call.argument<String>("userId")
                        val filePath = call.argument<String>("filePath")
                        val fileName = call.argument<String>("fileName")
                        if (userId != null && filePath != null && fileName != null) {
                            result.success(nearbyHandler.sendFile(userId, filePath, fileName))
                        } else {
                            result.error(
                                "INVALID_ARGUMENT",
                                "userId, filePath and fileName required",
                                null
                            )
                        }
                    }
                    "getConnectedUsers" -> result.success(
                        nearbyHandler.getConnectedUsers() + bleHotspotHandler.getConnectedUsers()
                    )
                    "getDiscoveredUsers" -> result.success(
                        nearbyHandler.getDiscoveredUsers() + bleHotspotHandler.getDiscoveredUsers()
                    )
                    "getEnvironmentStatus" -> result.success(buildEnvironmentStatus())
                    "openSystemSettings" -> {
                        openSystemSettings()
                        result.success(true)
                    }
                    "openHotspotSettings" -> {
                        openHotspotSettings()
                        result.success(true)
                    }
                    "openWifiSettings" -> {
                        openWifiSettings()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, discoveryEventChannel)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    nearbyHandler.setDiscoveryEventSink(events)
                    bleHotspotHandler.setDiscoveryEventSink(events)
                }

                override fun onCancel(arguments: Any?) {
                    nearbyHandler.setDiscoveryEventSink(null)
                    bleHotspotHandler.setDiscoveryEventSink(null)
                }
            })

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, messageEventChannel)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    nearbyHandler.setMessageEventSink(events)
                }

                override fun onCancel(arguments: Any?) {
                    nearbyHandler.setMessageEventSink(null)
                }
            })

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, connectionEventChannel)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    nearbyHandler.setConnectionEventSink(events)
                    bleHotspotHandler.setConnectionEventSink(events)
                }

                override fun onCancel(arguments: Any?) {
                    nearbyHandler.setConnectionEventSink(null)
                    bleHotspotHandler.setConnectionEventSink(null)
                }
            })

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, fileEventChannel)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    nearbyHandler.setFileEventSink(events)
                }

                override fun onCancel(arguments: Any?) {
                    nearbyHandler.setFileEventSink(null)
                }
            })

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, fileProgressEventChannel)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    nearbyHandler.setFileTransferProgressEventSink(events)
                }

                override fun onCancel(arguments: Any?) {
                    nearbyHandler.setFileTransferProgressEventSink(null)
                }
            })
    }

    fun getMyUserIdAndName(): Pair<String, String> {
        return Pair(myUserId, myName)
    }

    override fun onDestroy() {
        releaseMulticastLock()
        nearbyHandler.cleanup()
        bleHotspotHandler.cleanup()
        Log.d("MainActivity", "Cleaning up native resources")
        super.onDestroy()
    }

    private fun openSystemSettings() {
        val intent = Intent(Settings.ACTION_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }

    private fun openHotspotSettings() {
        val intent = try {
            Intent().apply {
                setClassName("com.android.settings", "com.android.settings.TetherSettings")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
        } catch (_: Exception) {
            Intent(Settings.ACTION_WIRELESS_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
        }
        startActivity(intent)
    }

    private fun openWifiSettings() {
        val intent = Intent(Settings.ACTION_WIFI_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }

    private fun acquireMulticastLock() {
        if (multicastLock?.isHeld == true) {
            return
        }
        val wifiManager =
            applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        multicastLock = wifiManager.createMulticastLock(
            "course_helper_local_transfer"
        ).apply {
            setReferenceCounted(true)
            acquire()
        }
    }

    private fun releaseMulticastLock() {
        multicastLock?.let {
            if (it.isHeld) {
                it.release()
            }
        }
        multicastLock = null
    }

    private fun resolveTransportMode(): String {
        return when {
            nearbyHandler.isPlayServicesReady() -> "nearby_connections"
            bleHotspotHandler.isBleAvailable() && bleHotspotHandler.isHotspotCapable() -> "ble_hotspot"
            else -> "unsupported"
        }
    }

    private fun buildEnvironmentStatus(): Map<String, Any?> {
        val nearbyStatus = nearbyHandler.getEnvironmentStatus()
        return nearbyStatus + mapOf(
            "transportMode" to resolveTransportMode(),
            "bleAvailable" to bleHotspotHandler.isBleAvailable(),
            "hotspotCapable" to bleHotspotHandler.isHotspotCapable(),
            "requiresManualHotspotStep" to (resolveTransportMode() == "ble_hotspot"),
            "discoveryRunning" to (nearbyHandler.isDiscovering() || bleHotspotHandler.isDiscovering()),
            "advertisingRunning" to (nearbyHandler.isAdvertising() || bleHotspotHandler.isAdvertising())
        )
    }
}
