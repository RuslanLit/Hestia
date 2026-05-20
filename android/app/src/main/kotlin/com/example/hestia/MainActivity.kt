package com.example.hestia

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        HestiaAlwaysReachable.markManualLaunch(this)
        android.util.Log.i("HestiaCallAction", "MainActivity onCreate ${describeIntent(intent)} hasAccept=${intent?.getStringExtra("hestia_action") == "accept_call"}")
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        android.util.Log.i("HestiaCallAction", "MainActivity onNewIntent ${describeIntent(intent)} hasAccept=${intent.getStringExtra("hestia_action") == "accept_call"}")
        android.util.Log.i("HestiaCallAction", "MainActivity onNewIntent hestia_action=${intent.getStringExtra("hestia_action") ?: "null"}")
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        android.util.Log.i("HestiaCallAction", "MainActivity handleIntent ${describeIntent(intent)}")
        val explicitAction = intent.getStringExtra("hestia_action")
        val actionStr = intent.getStringExtra("hestia_push_action") ?: buildActionFromIntent(intent, explicitAction)
        if (actionStr.isBlank()) return
        android.util.Log.i("HestiaMainActivity", "handleIntent actionStr=$actionStr")
        try {
            val action = org.json.JSONObject(actionStr)
            val callId = action.optString("callId", "")
            if (callId.isNotBlank()) {
                val actionName = explicitAction ?: if (action.optString("acceptCall", "") == "true") "accept_call" else "open_call"
                if (actionName == "accept_call" || intent.action == HestiaCallUi.ACTION_ACCEPT_CALL) {
                    android.util.Log.i("HestiaCallAction", "ACCEPT_RECEIVED_NATIVE callId=${HestiaCallUi.short(callId)}")
                    android.util.Log.i("HestiaCallAction", "ACCEPT_RECEIVED callId=${HestiaCallUi.short(callId)} receiver=MainActivity action=${intent.action ?: "null"} extras=${intent.extras?.keySet()?.joinToString(",") ?: "none"}")
                    android.util.Log.i("HestiaCallAction", "NATIVE_ACCEPT_RECEIVED callId=${HestiaCallUi.short(callId)}")
                    HestiaCallUi.setCallState(this, callId, HestiaCallUi.CallStateValue.ACCEPTING, "notification_accept")
                    android.util.Log.i("HestiaCallAction", "native call state set accepting callId=${HestiaCallUi.short(callId)}")
                    HestiaCallUi.cancelCallNotification(this, callId)
                    android.util.Log.i("HestiaCallAction", "notification cancelled callId=${HestiaCallUi.short(callId)}")
                    HestiaCallUi.closeCallUi(this, callId, "accepted")
                    action.put("acceptCall", "true")
                    HestiaCallUi.storePendingActionReplacingCall(this, action)
                    android.util.Log.i("HestiaCallAction", "MainActivity launched with accept_call callId=${HestiaCallUi.short(callId)}")
                } else {
                    android.util.Log.i("HestiaCallAction", "OPEN_RECEIVED callId=${HestiaCallUi.short(callId)} receiver=MainActivity action=${intent.action ?: "null"} extras=${intent.extras?.keySet()?.joinToString(",") ?: "none"}")
                    HestiaCallUi.storePendingActionReplacingCall(this, action)
                }
                
                if (actionName == "decline_call") {
                    val cancelIntent = Intent(this, HestiaForegroundService::class.java).apply {
                        this.action = HestiaForegroundService.ACTION_CANCEL_CALL
                        putExtra("callId", callId)
                    }
                    startService(cancelIntent)
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("HestiaMainActivity", "Failed to handle intent action", e)
        }
    }

    private fun buildActionFromIntent(intent: Intent, explicitAction: String?): String {
        val callId = intent.getStringExtra(HestiaCallUi.EXTRA_CALL_ID) ?: ""
        if (callId.isBlank()) return ""
        val payload = org.json.JSONObject()
            .put("type", "call")
            .put("callId", callId)
            .put("fromUserId", intent.getStringExtra(HestiaCallUi.EXTRA_FROM_USER_ID) ?: "")
            .put("fromNickname", intent.getStringExtra(HestiaCallUi.EXTRA_FROM_NICKNAME) ?: "")
            .put("video", intent.getBooleanExtra(HestiaCallUi.EXTRA_VIDEO, false).toString())
            .put("timestamp", intent.getLongExtra(HestiaCallUi.EXTRA_SERVER_TIMESTAMP, 0L).toString())
            .put("ttlMs", intent.getLongExtra(HestiaCallUi.EXTRA_TTL_MS, 45_000L).toString())
        if (explicitAction == "accept_call") payload.put("acceptCall", "true")
        return payload.toString()
    }

    private fun describeIntent(intent: Intent?): String {
        if (intent == null) return "intent=null"
        return "action=${intent.action ?: "null"} component=${intent.component?.className ?: "none"} extras=${intent.extras?.keySet()?.joinToString(",") ?: "none"} hestia_action=${intent.getStringExtra("hestia_action") ?: "null"}"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "hestia/android_wakeup"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isGooglePlayServicesAvailable" -> {
                    result.success(isPackageInstalled("com.google.android.gms"))
                }
                "isIgnoringBatteryOptimizations" -> {
                    val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                    result.success(powerManager.isIgnoringBatteryOptimizations(packageName))
                }
                "requestIgnoreBatteryOptimizations" -> {
                    result.success(HestiaAlwaysReachable.requestIgnoreBatteryOptimizations(this))
                }
                "readAlwaysReachableDiagnostics" -> {
                    result.success(HestiaAlwaysReachable.diagnostics(this))
                }
                "scheduleAlwaysReachableWatchdog" -> {
                    HestiaAlwaysReachable.scheduleWatchdog(this)
                    result.success(true)
                }
                "canUseFullScreenIntent" -> {
                    result.success(HestiaCallUi.canUseFullScreenIntent(this))
                }
                "openFullScreenIntentSettings" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= 34) {
                            startActivity(Intent(HestiaCallUi.ACTION_MANAGE_FULL_SCREEN).apply {
                                data = Uri.parse("package:$packageName")
                            })
                        } else {
                            startActivity(Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:$packageName")
                            })
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        android.util.Log.e("HestiaMainActivity", "open full screen settings failed", e)
                        result.success(false)
                    }
                }
                "showIncomingCallNotification" -> {
                    val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                    val action = org.json.JSONObject()
                        .put("type", "call")
                        .put("callId", args["callId"] as? String ?: "")
                        .put("fromUserId", args["fromUserId"] as? String ?: "")
                        .put("fromNickname", args["fromNickname"] as? String ?: "")
                        .put("video", (args["video"] ?: "false").toString())
                        .put("timestamp", (args["serverTimestamp"] ?: args["timestamp"] ?: "").toString())
                        .put("ttlMs", (args["ttlMs"] ?: "").toString())
                    result.success(HestiaCallUi.showIncomingCallNotification(this, action))
                }
                "updateAppState" -> {
                    val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                    HestiaCallUi.updateAppState(this, args["state"] as? String ?: "unknown")
                    result.success(true)
                }
                "updateCallState" -> {
                    val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                    val callId = args["callId"] as? String ?: ""
                    val state = when (args["state"] as? String ?: "") {
                        "ringing" -> HestiaCallUi.CallStateValue.RINGING
                        "accepting" -> HestiaCallUi.CallStateValue.ACCEPTING
                        "connecting" -> HestiaCallUi.CallStateValue.CONNECTING
                        "active" -> HestiaCallUi.CallStateValue.ACTIVE
                        "declined" -> HestiaCallUi.CallStateValue.DECLINED
                        "cancelled" -> HestiaCallUi.CallStateValue.CANCELLED
                        "missed" -> HestiaCallUi.CallStateValue.MISSED
                        "ended" -> HestiaCallUi.CallStateValue.ENDED
                        else -> null
                    }
                    if (state != null) {
                        HestiaCallUi.setCallState(this, callId, state, args["source"] as? String ?: "flutter")
                    }
                    result.success(state != null)
                }
                "startForegroundSocketService" -> {
                    val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                    val intent = Intent(this, HestiaForegroundService::class.java).apply {
                        action = HestiaForegroundService.ACTION_START
                        putExtra(HestiaForegroundService.EXTRA_WS_URL, args["wsUrl"] as? String ?: "")
                        putExtra(HestiaForegroundService.EXTRA_USER_ID, args["userId"] as? String ?: "")
                        putExtra(HestiaForegroundService.EXTRA_NICKNAME, args["nickname"] as? String ?: "")
                        putExtra(HestiaForegroundService.EXTRA_AUTH_TOKEN, args["authToken"] as? String ?: "")
                        putExtra(HestiaForegroundService.EXTRA_PUBLIC_KEY, args["publicKey"] as? String ?: "")
                        putExtra(HestiaForegroundService.EXTRA_DEVICE_ID, args["deviceId"] as? String ?: "")
                        putExtra(HestiaForegroundService.EXTRA_APP_VERSION, args["appVersion"] as? String ?: "")
                    }
                    startForegroundService(intent)
                    result.success(true)
                }
                "stopForegroundSocketService" -> {
                    val intent = Intent(this, HestiaForegroundService::class.java).apply {
                        action = HestiaForegroundService.ACTION_STOP
                    }
                    startService(intent)
                    result.success(true)
                }
                "drainForegroundServiceActions" -> {
                    val actions = drainForegroundServiceActions()
                    android.util.Log.i("HestiaCallAction", "drainForegroundServiceActions deliveredCount=${actions.size}")
                    result.success(actions)
                }
                "cancelCallNotification" -> {
                    val callId = call.argument<String>("callId") ?: ""
                    android.util.Log.i("HestiaMainActivity", "cancelCallNotification MethodChannel called for callId=$callId")
                    if (callId.isNotBlank()) {
                        HestiaCallUi.cancelCallNotification(this, callId)
                        HestiaCallUi.closeCallUi(this, callId, "cancelled")
                        
                        // Also notify foreground service to clear seenCallIds
                        val cancelIntent = Intent(this, HestiaForegroundService::class.java).apply {
                            action = HestiaForegroundService.ACTION_CANCEL_CALL
                            putExtra("callId", callId)
                        }
                        startService(cancelIntent)
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isPackageInstalled(packageName: String): Boolean {
        return try {
            packageManager.getPackageInfo(packageName, 0)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun drainForegroundServiceActions(): List<String> {
        val prefs = getSharedPreferences(HestiaForegroundService.HANDOFF_PREFS, Context.MODE_PRIVATE)
        val raw = prefs.getString(HestiaForegroundService.KEY_PENDING_ACTIONS, "[]") ?: "[]"
        prefs.edit().remove(HestiaForegroundService.KEY_PENDING_ACTIONS).apply()
        return try {
            val array = JSONArray(raw)
            List(array.length()) { index -> array.optString(index) }.filter { it.isNotBlank() }.also { items ->
                for (item in items) {
                    val callId = try {
                        org.json.JSONObject(item).optString("callId", "")
                    } catch (_: Exception) {
                        ""
                    }
                    if (callId.isNotBlank()) {
                        android.util.Log.i("HestiaCallAction", "action delivered to Flutter callId=${HestiaCallUi.short(callId)}")
                    }
                }
            }
        } catch (_: Exception) {
            emptyList()
        }
    }

}
