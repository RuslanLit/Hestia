package com.example.hestia

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import org.json.JSONObject
import java.util.concurrent.TimeUnit

object HestiaAlwaysReachable {
    private const val TAG = "HestiaAlwaysReachable"
    private const val PREFS = "hestia_always_reachable_diagnostics"
    private const val WORK_NAME = "hestia_always_reachable_watchdog"
    private const val KEY_SERVICE_RUNNING = "service_running"
    private const val KEY_WS_CONNECTED = "websocket_connected"
    private const val KEY_WS_AUTHENTICATED = "websocket_authenticated"
    private const val KEY_LAST_RESTART_REASON = "last_restart_reason"
    private const val KEY_BOOT_RECEIVER_FIRED = "boot_receiver_fired"
    private const val KEY_WATCHDOG_LAST_CHECK = "watchdog_last_check"
    private const val KEY_SERVICE_KILLED_RESTARTED_COUNT = "service_killed_restarted_count"
    private const val KEY_ANDROID_STOPPED_WARNING = "android_stopped_warning"
    private var processServiceAlive = false

    fun scheduleWatchdog(context: Context) {
        try {
            val request = PeriodicWorkRequestBuilder<HestiaWatchdogWorker>(15, TimeUnit.MINUTES)
                .build()
            WorkManager.getInstance(context.applicationContext).enqueueUniquePeriodicWork(
                WORK_NAME,
                ExistingPeriodicWorkPolicy.KEEP,
                request,
            )
            Log.i(TAG, "watchdog scheduled")
        } catch (error: Exception) {
            Log.w(TAG, "watchdog schedule failed error=${error.message}")
        }
    }

    fun markServiceRunning(context: Context, running: Boolean, unexpected: Boolean = false) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        processServiceAlive = running
        val edit = prefs.edit().putBoolean(KEY_SERVICE_RUNNING, running)
        if (unexpected) {
            val count = prefs.getInt(KEY_SERVICE_KILLED_RESTARTED_COUNT, 0) + 1
            edit.putInt(KEY_SERVICE_KILLED_RESTARTED_COUNT, count)
                .putBoolean(KEY_ANDROID_STOPPED_WARNING, true)
                .putString(KEY_LAST_RESTART_REASON, "android_stopped_background_service")
        }
        edit.apply()
        Log.i(TAG, "foreground service running=$running unexpected=$unexpected")
    }

    fun markManualLaunch(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (prefs.getBoolean(KEY_SERVICE_RUNNING, false) && !processServiceAlive) {
            val count = prefs.getInt(KEY_SERVICE_KILLED_RESTARTED_COUNT, 0) + 1
            prefs.edit()
                .putBoolean(KEY_SERVICE_RUNNING, false)
                .putBoolean(KEY_ANDROID_STOPPED_WARNING, true)
                .putInt(KEY_SERVICE_KILLED_RESTARTED_COUNT, count)
                .putString(KEY_LAST_RESTART_REASON, "android_stopped_background_service")
                .apply()
            Log.i(TAG, "stale foreground service detected on manual launch")
        }
    }

    fun markSocketState(context: Context, connected: Boolean, authenticated: Boolean) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putBoolean(KEY_WS_CONNECTED, connected)
            .putBoolean(KEY_WS_AUTHENTICATED, authenticated)
            .apply()
        Log.i(TAG, "websocket connected=$connected authenticated=$authenticated")
    }

    fun markLastRestartReason(context: Context, reason: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString(KEY_LAST_RESTART_REASON, reason)
            .apply()
    }

    fun markBootReceiverFired(context: Context, action: String?) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putBoolean(KEY_BOOT_RECEIVER_FIRED, true)
            .putString(KEY_LAST_RESTART_REASON, "boot_receiver_${action ?: "unknown"}")
            .apply()
        Log.i(TAG, "boot receiver fired action=${action ?: "unknown"}")
    }

    fun markWatchdogCheck(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putLong(KEY_WATCHDOG_LAST_CHECK, System.currentTimeMillis())
            .apply()
        Log.i(TAG, "watchdog last check updated")
    }

    fun diagnostics(context: Context): Map<String, Any> {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        return mapOf(
            "foregroundServiceRunning" to processServiceAlive,
            "websocketConnected" to prefs.getBoolean(KEY_WS_CONNECTED, false),
            "websocketAuthenticated" to prefs.getBoolean(KEY_WS_AUTHENTICATED, false),
            "lastRestartReason" to (prefs.getString(KEY_LAST_RESTART_REASON, "none") ?: "none"),
            "batteryOptimizationIgnored" to powerManager.isIgnoringBatteryOptimizations(context.packageName),
            "bootReceiverFired" to prefs.getBoolean(KEY_BOOT_RECEIVER_FIRED, false),
            "watchdogLastCheck" to prefs.getLong(KEY_WATCHDOG_LAST_CHECK, 0L),
            "serviceKilledRestartedCount" to prefs.getInt(KEY_SERVICE_KILLED_RESTARTED_COUNT, 0),
            "androidStoppedWarning" to prefs.getBoolean(KEY_ANDROID_STOPPED_WARNING, false),
        )
    }

    fun diagnosticsJson(context: Context): String =
        JSONObject(diagnostics(context)).toString()

    fun requestIgnoreBatteryOptimizations(context: Context): Boolean {
        return try {
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = Uri.parse("package:${context.packageName}")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            context.startActivity(intent)
            true
        } catch (error: Exception) {
            Log.w(TAG, "battery optimization request failed error=${error.message}")
            try {
                val fallback = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.parse("package:${context.packageName}")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                context.startActivity(fallback)
                true
            } catch (_: Exception) {
                false
            }
        }
    }
}
