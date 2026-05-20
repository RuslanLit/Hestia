package com.example.hestia

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class HestiaBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action
        HestiaAlwaysReachable.markBootReceiverFired(context, action)
        Log.i("HestiaAlwaysReachable", "boot receiver fired action=${action ?: "unknown"}")
        HestiaAlwaysReachable.scheduleWatchdog(context)
        HestiaForegroundService.startAlwaysReachable(context, "boot_${action ?: "unknown"}")
    }
}
