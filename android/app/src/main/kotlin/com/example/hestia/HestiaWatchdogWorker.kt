package com.example.hestia

import android.content.Context
import android.util.Log
import androidx.work.Worker
import androidx.work.WorkerParameters

class HestiaWatchdogWorker(
    appContext: Context,
    workerParams: WorkerParameters,
) : Worker(appContext, workerParams) {
    override fun doWork(): Result {
        HestiaAlwaysReachable.markWatchdogCheck(applicationContext)
        val started = HestiaForegroundService.startAlwaysReachable(
            applicationContext,
            "workmanager_watchdog",
        )
        Log.i("HestiaAlwaysReachable", "watchdog check started=$started")
        return Result.success()
    }
}
