package com.gueter.cszm

import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.InputStreamReader

class MobileDataReconnectHandler(private val context: Context) : MethodChannel.MethodCallHandler {
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getCapability" -> result.success(getCapability())
            "restartMobileData" -> restartMobileData(result)
            "openNetworkSettings" -> {
                openNetworkSettings()
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun getCapability(): Map<String, Any?> {
        return if (canUseRootShell()) {
            mapOf(
                "mode" to "privilegedAuto",
                "message" to "检测到 root shell，可尝试自动重启移动数据",
                "canOpenSettings" to true
            )
        } else {
            mapOf(
                "mode" to "manualAssist",
                "message" to "普通应用无法直接开关移动数据，请手动完成开-关-开",
                "canOpenSettings" to true
            )
        }
    }

    private fun restartMobileData(result: MethodChannel.Result) {
        Thread {
            if (!canUseRootShell()) {
                postSuccess(result,
                    mapOf(
                        "success" to false,
                        "message" to "当前设备不具备自动开关移动数据权限"
                    )
                )
                return@Thread
            }

            val ok = try {
                runRootCommand("svc data enable")
                Thread.sleep(1200)
                runRootCommand("svc data disable")
                Thread.sleep(1800)
                runRootCommand("svc data enable")
                waitForCellular(12000)
            } catch (_: Exception) {
                false
            }

            postSuccess(result,
                mapOf(
                    "success" to ok,
                    "message" to if (ok) "移动数据已重启" else "移动数据重启后未检测到蜂窝网络"
                )
            )
        }.start()
    }

    private fun postSuccess(result: MethodChannel.Result, value: Any?) {
        mainHandler.post { result.success(value) }
    }

    private fun openNetworkSettings() {
        val intent = Intent(Settings.ACTION_WIRELESS_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
    }

    private fun canUseRootShell(): Boolean {
        return try {
            val output = runRootCommand("id", timeoutMs = 1500)
            output.contains("uid=0")
        } catch (_: Exception) {
            false
        }
    }

    private fun runRootCommand(command: String, timeoutMs: Long = 5000): String {
        val process = Runtime.getRuntime().exec(arrayOf("su", "-c", command))
        val completed = process.waitFor(timeoutMs, java.util.concurrent.TimeUnit.MILLISECONDS)
        if (!completed) {
            process.destroyForcibly()
            throw IllegalStateException("root command timeout")
        }
        val output = BufferedReader(InputStreamReader(process.inputStream)).readText()
        val error = BufferedReader(InputStreamReader(process.errorStream)).readText()
        if (process.exitValue() != 0) {
            throw IllegalStateException(error.ifBlank { "root command failed" })
        }
        return output
    }

    private fun waitForCellular(timeoutMs: Long): Boolean {
        val connectivity = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val deadline = System.currentTimeMillis() + timeoutMs
        while (System.currentTimeMillis() < deadline) {
            val network = connectivity.activeNetwork
            val caps = connectivity.getNetworkCapabilities(network)
            if (caps != null &&
                caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) &&
                caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            ) {
                return true
            }
            Thread.sleep(500)
        }
        return false
    }
}
