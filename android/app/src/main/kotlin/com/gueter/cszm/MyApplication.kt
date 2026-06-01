package com.gueter.cszm

import android.app.Application
import android.util.Log
import com.baidu.mapapi.CoordType
import com.baidu.mapapi.SDKInitializer

class MyApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        try {
            SDKInitializer.setAgreePrivacy(applicationContext, true)
            SDKInitializer.initialize(applicationContext)
            SDKInitializer.setCoordType(CoordType.BD09LL)
        } catch (error: Throwable) {
            Log.e(
                "MyApplication",
                "Baidu SDK init failed during app startup; continuing without eager map init.",
                error
            )
        }
    }
}
