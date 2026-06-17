package com.gueter.cszm

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.verify.domain.DomainVerificationManager
import android.content.pm.verify.domain.DomainVerificationUserState
import android.net.Uri
import android.net.wifi.WifiManager
import android.os.Build
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
    private val homeWidgetSummaryChannel = "com.gueter.cszm/home_widget_summary"
    private val tronclassQqAuthCallbackChannel = "com.gueter.cszm/tronclass_qq_auth_callback"
    private val networkControlChannel = "com.gueter.cszm/network_control"

    private var multicastLock: WifiManager.MulticastLock? = null
    private lateinit var nearbyHandler: NearbyHandler
    private lateinit var bleHotspotHandler: BleHotspotHandler
    private var myUserId: String = ""
    private var myName: String = "AirChatUser"
    private var pendingTronclassQqReturnedUrl: String? = null
    private var tronclassQqAuthCallbackMethodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        nearbyHandler = NearbyHandler(this, this)
        bleHotspotHandler = BleHotspotHandler(this, this)
        captureTronclassQqReturnedUrl(intent)
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

        tronclassQqAuthCallbackMethodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            tronclassQqAuthCallbackChannel
        )
        tronclassQqAuthCallbackMethodChannel
            ?.setMethodCallHandler { call, result ->
                when (call.method) {
                    "consumeInitialCallback", "consumePendingReturnedUrl" -> {
                        result.success(consumePendingTronclassQqReturnedUrl())
                    }
                    "isTronclassQqCallbackAppLinkVerified" -> {
                        result.success(isTronclassQqCallbackAppLinkVerified())
                    }
                    "getInstalledQqOAuthBrowsers" -> {
                        result.success(getInstalledQqOAuthBrowsers())
                    }
                    "openUrlInBrowserPackage" -> {
                        val url = call.argument<String>("url")
                        val packageName = call.argument<String>("packageName")
                        result.success(openUrlInBrowserPackage(url, packageName))
                    }
                    else -> result.notImplemented()
                }
            }

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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, networkControlChannel)
            .setMethodCallHandler(MobileDataReconnectHandler(applicationContext))

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, homeWidgetSummaryChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "update" -> {
                        val data = call.arguments as? Map<*, *> ?: emptyMap<String, Any?>()
                        val prefs = applicationContext.getSharedPreferences(
                            GueterTodayWidget.PREFS,
                            Context.MODE_PRIVATE
                        ).edit()
                        prefs.putInt(
                            GueterTodayWidget.KEY_TODO_COUNT,
                            (data[GueterTodayWidget.KEY_TODO_COUNT] as? Number)?.toInt() ?: 0
                        )
                        prefs.putInt(
                            GueterTodayWidget.KEY_REVIEW_COUNT,
                            (data[GueterTodayWidget.KEY_REVIEW_COUNT] as? Number)?.toInt() ?: 0
                        )
                        prefs.putString(
                            GueterTodayWidget.KEY_NEAREST_TODO,
                            data[GueterTodayWidget.KEY_NEAREST_TODO]?.toString() ?: "暂无待办"
                        )
                        prefs.putBoolean(
                            GueterTodayWidget.KEY_NOTIFICATION_ENABLED,
                            data[GueterTodayWidget.KEY_NOTIFICATION_ENABLED] as? Boolean ?: true
                        )
                        prefs.putString(
                            GueterTodayWidget.KEY_UPDATED_AT,
                            data[GueterTodayWidget.KEY_UPDATED_AT]?.toString() ?: "--:--"
                        )
                        prefs.apply()
                        GueterTodayWidget.updateAll(applicationContext)
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

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val callbackUrl = captureTronclassQqReturnedUrl(intent)
        if (callbackUrl != null) {
            tronclassQqAuthCallbackMethodChannel?.invokeMethod("onCallback", callbackUrl)
        }
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

    private fun captureTronclassQqReturnedUrl(intent: Intent?): String? {
        val url = when (intent?.action) {
            Intent.ACTION_VIEW -> intent.data?.toString()
            Intent.ACTION_SEND -> {
                if (intent.type?.startsWith("text/") == true) {
                    intent.getStringExtra(Intent.EXTRA_TEXT)
                        ?: intent.getStringExtra(Intent.EXTRA_SUBJECT)
                } else {
                    null
                }
            }
            else -> null
        } ?: return null

        val data = extractSupportedTronclassQqReturnedUri(url) ?: return null
        val scheme = data.scheme?.lowercase() ?: return null
        val host = data.host?.lowercase() ?: return null
        val path = data.path?.lowercase() ?: return null
        val isCallback =
            (scheme == "gueter" && host == "tronclass-qq-callback") ||
                (host == "mobile.guet.edu.cn" && path == "/cas-callback") ||
                (host == "cas.guet.edu.cn" && path == "/authserver/callback") ||
                (host == "identity.guet.edu.cn" && path.contains("/broker/cas-client/endpoint")) ||
                (host == "portal.guet.edu.cn" && path == "/ywtbcallback")
        if (!isCallback) {
            return null
        }
        val returnedUrl = data.toString()
        pendingTronclassQqReturnedUrl = returnedUrl
        Log.d("MainActivity", "Captured Tronclass QQ returned url host=$host path=$path")
        return returnedUrl
    }

    private fun consumePendingTronclassQqReturnedUrl(): String? {
        val url = pendingTronclassQqReturnedUrl
        pendingTronclassQqReturnedUrl = null
        return url
    }

    private fun extractSupportedTronclassQqReturnedUri(text: String): Uri? {
        try {
            val direct = Uri.parse(text.trim())
            if (isSupportedTronclassQqReturnedUri(direct)) {
                return direct
            }
        } catch (_: Exception) {
            // Shared text is often not a URL. Fall through to URL extraction.
        }
        val regex = Regex("(?:https|gueter)://[^\\s<>\\\"']+")
        for (match in regex.findAll(text)) {
            val candidate = match.value.trim().trimEnd(')', '>', ']', '.', ',', '"', '\'')
            try {
                val uri = Uri.parse(candidate)
                if (isSupportedTronclassQqReturnedUri(uri)) {
                    return uri
                }
            } catch (_: Exception) {
                // Continue scanning other URLs.
            }
        }
        return null
    }

    private fun isSupportedTronclassQqReturnedUri(uri: Uri): Boolean {
        val scheme = uri.scheme?.lowercase() ?: return false
        val host = uri.host?.lowercase() ?: return false
        if (scheme == "gueter") {
            return host == "tronclass-qq-callback" &&
                !uri.getQueryParameter("code").isNullOrEmpty()
        }
        if (scheme != "https") {
            return false
        }
        if (uri.getQueryParameter("code").isNullOrEmpty()) {
            return false
        }
        val path = uri.path?.lowercase() ?: return false
        return (host == "mobile.guet.edu.cn" && path == "/cas-callback") ||
            (host == "cas.guet.edu.cn" && path == "/authserver/callback") ||
            (host == "identity.guet.edu.cn" && path.contains("/broker/cas-client/endpoint")) ||
            (host == "portal.guet.edu.cn" && path == "/ywtbcallback")
    }

    private fun isTronclassQqCallbackAppLinkVerified(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            return false
        }
        return try {
            val manager = getSystemService(DomainVerificationManager::class.java)
            val state = manager?.getDomainVerificationUserState(packageName) ?: return false
            val hostStates = state.hostToStateMap
            val mobileVerified = hostStates["mobile.guet.edu.cn"] == DomainVerificationUserState.DOMAIN_STATE_VERIFIED
            val casVerified = hostStates["cas.guet.edu.cn"] == DomainVerificationUserState.DOMAIN_STATE_VERIFIED
            val identityVerified = hostStates["identity.guet.edu.cn"] == DomainVerificationUserState.DOMAIN_STATE_VERIFIED
            mobileVerified || casVerified || identityVerified
        } catch (_: Exception) {
            false
        }
    }

    private fun getInstalledQqOAuthBrowsers(): List<Map<String, Any?>> {
        val probeUri = Uri.parse("https://identity.guet.edu.cn/")
        val probeIntent = Intent(Intent.ACTION_VIEW, probeUri).apply {
            addCategory(Intent.CATEGORY_BROWSABLE)
        }
        val defaultPackage = packageManager.resolveActivity(
            probeIntent,
            PackageManager.MATCH_DEFAULT_ONLY
        )?.activityInfo?.packageName
        val packageNames = linkedSetOf<String>()
        packageManager.queryIntentActivities(probeIntent, PackageManager.MATCH_DEFAULT_ONLY)
            .forEach { resolveInfo ->
                resolveInfo.activityInfo?.packageName?.let { packageNames.add(it) }
            }
        packageManager.queryIntentActivities(probeIntent, 0)
            .forEach { resolveInfo ->
                resolveInfo.activityInfo?.packageName?.let { packageNames.add(it) }
            }
        listOf(
            "com.android.chrome",
            "com.brave.browser",
            "com.microsoft.emmx",
            "org.mozilla.firefox",
            "com.tencent.mtt",
            "com.huawei.browser",
            "com.mi.globalbrowser",
            "com.sec.android.app.sbrowser"
        ).forEach { packageName ->
            if (isPackageInstalled(packageName)) {
                packageNames.add(packageName)
            }
        }
        return packageNames.mapNotNull { packageName ->
            val appInfo = try {
                packageManager.getApplicationInfo(packageName, 0)
            } catch (_: PackageManager.NameNotFoundException) {
                null
            } ?: return@mapNotNull null
            val label = packageManager.getApplicationLabel(appInfo).toString()
            mapOf(
                "packageName" to packageName,
                "displayName" to (label.ifBlank { fallbackBrowserName(packageName) }),
                "isInstalled" to true,
                "isRecommended" to (packageName == "com.android.chrome"),
                "isDefault" to (packageName == defaultPackage)
            )
        }
    }

    private fun isPackageInstalled(packageName: String): Boolean {
        return try {
            packageManager.getApplicationInfo(packageName, 0)
            true
        } catch (_: PackageManager.NameNotFoundException) {
            false
        }
    }

    private fun fallbackBrowserName(packageName: String): String {
        return when (packageName) {
            "com.android.chrome" -> "Chrome"
            "com.brave.browser" -> "Brave"
            "com.microsoft.emmx" -> "Edge"
            "org.mozilla.firefox" -> "Firefox"
            "com.tencent.mtt" -> "QQ 浏览器"
            "com.huawei.browser" -> "华为浏览器"
            "com.mi.globalbrowser" -> "小米浏览器"
            "com.sec.android.app.sbrowser" -> "三星浏览器"
            else -> packageName
        }
    }

    private fun openUrlInBrowserPackage(url: String?, packageName: String?): Boolean {
        if (url.isNullOrBlank()) {
            return false
        }
        val uri = try {
            Uri.parse(url)
        } catch (_: Exception) {
            return false
        }
        val intent = Intent(Intent.ACTION_VIEW, uri).apply {
            addCategory(Intent.CATEGORY_BROWSABLE)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (!packageName.isNullOrBlank()) {
                setPackage(packageName)
            }
        }
        return try {
            if (intent.resolveActivity(packageManager) == null) {
                false
            } else {
                startActivity(intent)
                true
            }
        } catch (e: Exception) {
            Log.w("MainActivity", "Failed to open URL in browser package=${packageName ?: "default"}")
            false
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
