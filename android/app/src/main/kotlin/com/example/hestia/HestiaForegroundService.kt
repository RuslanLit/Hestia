package com.example.hestia

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.TimeUnit
import kotlin.math.min

class HestiaForegroundService : Service() {
    private val client = OkHttpClient.Builder()
        .pingInterval(25, TimeUnit.SECONDS)
        .retryOnConnectionFailure(true)
        .build()
    private var webSocket: WebSocket? = null
    private var reconnectAttempts = 0
    private var stopping = false
    private var socketConnected = false
    private var socketAuthenticated = false
    private var socketConnectedAtMs = 0L
    private var socketLastServerActivityAtMs = 0L
    private var socketAuthenticatedAtMs = 0L
    private var socketUserId = ""
    private var socketDeviceId = ""
    private var socketWsUrl = ""
    private var socketRole = ""
    private var reconnectScheduled = false
    private val seenCallIds = LinkedHashSet<String>()

    override fun onCreate() {
        super.onCreate()
        createChannels()
        startForeground(BACKGROUND_NOTIFICATION_ID, backgroundNotification())
        HestiaAlwaysReachable.markServiceRunning(this, true)
        log("service created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                log("stop requested")
                stopping = true
                HestiaAlwaysReachable.markLastRestartReason(this, "logout_stop")
                webSocket?.close(1000, "logout")
                clearSocketState()
                getSharedPreferences(CONFIG_PREFS, MODE_PRIVATE).edit().clear().apply()
                HestiaAlwaysReachable.markSocketState(this, connected = false, authenticated = false)
                HestiaAlwaysReachable.markServiceRunning(this, false)
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_DECLINE_CALL -> {
                val callId = intent.getStringExtra("callId") ?: ""
                val fromUserId = intent.getStringExtra("fromUserId") ?: ""
                Log.i("HestiaCallAction", "DECLINE_RECEIVED callId=${short(callId)} receiver=HestiaForegroundService action=${intent.action ?: "null"} extras=${intent.extras?.keySet()?.joinToString(",") ?: "none"}")
                log("decline requested callId=${short(callId)} fromUserId=${short(fromUserId)}")
                if (callId.isNotBlank() && !markNativeCallHandled(callId)) {
                    Log.i(HestiaCallUi.TAG, "duplicate ignored callId=${HestiaCallUi.short(callId)}")
                    return START_STICKY
                }
                if (callId.isNotBlank() && fromUserId.isNotBlank()) {
                    HestiaCallUi.setCallState(this, callId, HestiaCallUi.CallStateValue.DECLINED, "notification_decline")
                    Log.i(HestiaCallUi.TAG, "notification decline callId=${HestiaCallUi.short(callId)}")
                    val reject = JSONObject()
                        .put("type", "call_reject")
                        .put("callId", callId)
                        .put("toUserId", fromUserId)
                        .put("reason", "declined")
                    webSocket?.send(reject.toString())
                    HestiaCallUi.cancelCallNotification(this, callId)
                    HestiaCallUi.closeCallUi(this, callId, "declined")
                }
                connectIfReady()
            }
            ACTION_CANCEL_CALL -> {
                val callId = intent.getStringExtra("callId") ?: ""
                log("cancel requested callId=${short(callId)}")
                if (callId.isNotBlank()) {
                    synchronized(seenCallIds) {
                        seenCallIds.remove(callId)
                    }
                    HestiaCallUi.cancelCallNotification(this, callId)
                    HestiaCallUi.closeCallUi(this, callId, "cancelled")
                    HestiaCallUi.setCallState(this, callId, HestiaCallUi.CallStateValue.CANCELLED, "native_cancel")
                }
            }
            ACTION_START, null -> {
                stopping = false
                storeConfig(intent)
                HestiaAlwaysReachable.markLastRestartReason(
                    this,
                    intent?.getStringExtra(EXTRA_RESTART_REASON) ?: "explicit_start",
                )
                HestiaAlwaysReachable.scheduleWatchdog(this)
                connectIfReady()
            }
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        log("service destroyed")
        webSocket?.close(1000, "destroyed")
        clearSocketState()
        HestiaAlwaysReachable.markSocketState(this, connected = false, authenticated = false)
        HestiaAlwaysReachable.markServiceRunning(this, false, unexpected = !stopping)
        super.onDestroy()
    }

    private fun connectIfReady() {
        val config = loadConfig()
        if (!config.ready) {
            log("websocket skipped reason=missing_config")
            HestiaAlwaysReachable.markSocketState(this, connected = false, authenticated = false)
            return
        }
        if (webSocket != null) {
            val reusable = existingSocketReusable(config)
            val lastFrameAgeMs = socketAge(socketLastServerActivityAtMs)
            val lastAuthOkAgeMs = socketAge(socketAuthenticatedAtMs)
            Log.i(
                ANDROID_WS_TAG,
                "websocket exists check open=$socketConnected authenticated=$socketAuthenticated " +
                    "lastFrameAgeMs=$lastFrameAgeMs lastAuthOkAgeMs=$lastAuthOkAgeMs " +
                    "role=${socketRole.ifBlank { "unknown" }} expectedRole=foreground_service " +
                    "userMatch=${socketUserId == config.userId} deviceMatch=${socketDeviceId == config.deviceId} " +
                    "urlMatch=${socketWsUrl == config.wsUrl}",
            )
            if (reusable) {
                log("websocket already exists")
                return
            }
            val reason = staleSocketReason(config)
            Log.i(ANDROID_WS_TAG, "stale websocket detected reason=$reason")
            closeStaleWebSocket(reason)
        }
        Log.i(ANDROID_WS_TAG, "reconnecting foreground websocket")
        log("websocket connecting url=${config.wsUrl}")
        reconnectScheduled = false
        HestiaAlwaysReachable.markSocketState(this, connected = false, authenticated = false)
        val request = Request.Builder().url(config.wsUrl).build()
        webSocket = client.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                if (this@HestiaForegroundService.webSocket !== webSocket) {
                    webSocket.close(1000, "superseded")
                    return
                }
                reconnectAttempts = 0
                socketConnected = true
                socketAuthenticated = false
                socketConnectedAtMs = System.currentTimeMillis()
                socketLastServerActivityAtMs = socketConnectedAtMs
                socketAuthenticatedAtMs = 0L
                socketUserId = config.userId
                socketDeviceId = config.deviceId
                socketWsUrl = config.wsUrl
                socketRole = "foreground_service"
                log("websocket connected")
                Log.i(ANDROID_WS_TAG, "websocket connected role=foreground_service")
                HestiaAlwaysReachable.markSocketState(this@HestiaForegroundService, connected = true, authenticated = false)
                val auth = JSONObject()
                    .put("type", "auth")
                    .put("userId", config.userId)
                    .put("nickname", config.nickname)
                    .put("authToken", config.authToken)
                    .put("publicKey", config.publicKey)
                    .put("deviceId", config.deviceId)
                    .put("deviceName", "Android foreground service")
                    .put("platform", "android")
                    .put("pushMode", "foreground_service")
                    .put("socketRole", "foreground_service")
                    .put("appVersion", config.appVersion)
                webSocket.send(auth.toString())
                Log.i(ANDROID_WS_TAG, "auth sent role=foreground_service userId=${short(config.userId)} deviceId=${short(config.deviceId)}")
                log("auth sent userId=${short(config.userId)} deviceId=${short(config.deviceId)}")
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                handleFrame(text)
            }

            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                Log.i(ANDROID_WS_TAG, "websocket closed/onDone code=$code reason=$reason")
                log("socket closed code=$code reason=$reason")
                val currentSocket = this@HestiaForegroundService.webSocket === webSocket
                if (currentSocket) {
                    clearSocketState()
                    HestiaAlwaysReachable.markSocketState(this@HestiaForegroundService, connected = false, authenticated = false)
                }
                if (currentSocket && !stopping && !reason.contains("Duplicate foreground service socket", ignoreCase = true)) {
                    scheduleReconnect("socket_closed")
                }
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                Log.i(ANDROID_WS_TAG, "websocket error=${t.message ?: t.javaClass.simpleName}")
                log("socket error=${t.message ?: t.javaClass.simpleName}")
                val currentSocket = this@HestiaForegroundService.webSocket === webSocket
                if (currentSocket) {
                    clearSocketState()
                    HestiaAlwaysReachable.markSocketState(this@HestiaForegroundService, connected = false, authenticated = false)
                }
                if (currentSocket && !stopping) scheduleReconnect("socket_failure")
            }
        })
    }

    private fun handleFrame(text: String) {
        socketLastServerActivityAtMs = System.currentTimeMillis()
        val json = try {
            JSONObject(text)
        } catch (error: Exception) {
            log("incoming frame invalid_json error=${error.message}")
            return
        }
        val type = json.optString("type", "unknown")
        log("incoming frame type=$type")
        when (type) {
            "auth_ok" -> {
                socketAuthenticated = true
                socketAuthenticatedAtMs = System.currentTimeMillis()
                log("auth_ok")
                Log.i(ANDROID_WS_TAG, "auth_ok received userId=${short(socketUserId)} role=${socketRole.ifBlank { "unknown" }}")
                HestiaAlwaysReachable.markSocketState(this, connected = true, authenticated = true)
            }
            "call_offer_init" -> handleCallOffer(json)
            "call_offer" -> handleCallOffer(json)
            "call_hangup" -> handleCallHangup(json)
            "new_message" -> showMessageNotification(json)
        }
    }

    private fun handleCallOffer(json: JSONObject) {
        val frameType = json.optString("type", "unknown")
        val callId = json.optString("callId", "")
        val fromUserId = json.optString("fromUserId", "")
        log("incoming call frame received type=$frameType callId=${short(callId)} fromUserId=${short(fromUserId)}")
        if (callId.isBlank()) {
            log("incoming call ignored reason=missing_callId type=$frameType")
            return
        }
        val existingState = HestiaCallUi.callState(this, callId)
        if (existingState == HestiaCallUi.CallStateValue.ACCEPTING ||
            existingState == HestiaCallUi.CallStateValue.CONNECTING ||
            existingState == HestiaCallUi.CallStateValue.ACTIVE) {
            log("duplicate call_offer ignored callId=${short(callId)} reason=already_accepting_or_active")
            Log.i(HestiaCallUi.TAG, "duplicate call_offer ignored callId=${HestiaCallUi.short(callId)} reason=already_accepting_or_active")
            return
        }
        synchronized(seenCallIds) {
            if (seenCallIds.contains(callId)) {
                log("duplicate call ignored callId=${short(callId)} type=$frameType")
            Log.i(HestiaCallUi.TAG, "duplicate ignored callId=${HestiaCallUi.short(callId)}")
                return
            }
            seenCallIds.add(callId)
            while (seenCallIds.size > 40) {
                seenCallIds.remove(seenCallIds.first())
            }
        }
        val timestamp = normalizeTimestamp(json)
        val ttlMs = json.optLong("ttlMs", json.optLong("callOfferTtlMs", 45_000L))
        // Relax the TTL verification to tolerate up to 5 minutes of clock drift
        val effectiveTtlMs = if (ttlMs > 300_000L) ttlMs else 300_000L
        Log.i(
            "HestiaCallAction",
            "call receivedAtMs=${System.currentTimeMillis()} serverTimestamp=$timestamp ttlMs=$ttlMs normalized ttlMs=$ttlMs normalized ageMs=${(System.currentTimeMillis() - timestamp).coerceAtLeast(0L)}",
        )
        if (System.currentTimeMillis() - timestamp > effectiveTtlMs) {
            log("incoming call ignored reason=expired callId=${short(callId)} type=$frameType")
            return
        }
        val action = JSONObject()
            .put("type", "call")
            .put("callId", callId)
            .put("fromUserId", fromUserId)
            .put("fromNickname", json.optString("fromNickname", ""))
            .put("video", json.optBoolean("video", false).toString())
            .put("timestamp", timestamp.toString())
            .put("ttlMs", ttlMs.toString())
        storePendingAction(action)
        log("call handoff to main app callId=${short(callId)}")
        HestiaCallUi.showIncomingCallNotification(this, action)
    }

    private fun handleCallHangup(json: JSONObject) {
        val callId = json.optString("callId", "")
        log("call hangup received callId=${short(callId)}")
        if (callId.isNotBlank()) {
            synchronized(seenCallIds) {
                seenCallIds.remove(callId)
            }
            HestiaCallUi.cancelCallNotification(this, callId)
            HestiaCallUi.closeCallUi(this, callId, "remote_hangup")
            HestiaCallUi.setCallState(this, callId, HestiaCallUi.CallStateValue.CANCELLED, "remote_hangup")
        }
    }

    private fun showMessageNotification(json: JSONObject) {
        val message = json.optJSONObject("message")
        val messageId = message?.optString("id", "") ?: ""
        val fromUserId = message?.optString("fromUserId", "") ?: ""
        val fromNickname = message?.optString("fromNickname", "") ?: ""
        val action = JSONObject()
            .put("type", "message")
            .put("messageId", messageId)
            .put("fromUserId", fromUserId)
            .put("fromNickname", fromNickname)
        storePendingAction(action)
        val title = if (fromNickname.isBlank()) HestiaStrings.get(this, R.string.hestia_brand) else fromNickname
        val notification = NotificationCompat.Builder(this, MESSAGE_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_notify_chat)
            .setContentTitle(title)
            .setContentText(HestiaStrings.get(this, R.string.new_message))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setContentIntent(openAppIntent(action))
            .setAutoCancel(true)
            .build()
        notificationManager.notify(notificationId(messageId.ifBlank { fromUserId }, 9001), notification)
        log("notification shown type=message messageId=${short(messageId)}")
    }

    private fun showIncomingCallNotification(action: JSONObject) {
        val callId = action.optString("callId", "")
        log("incoming call notification/fullscreen requested callId=${short(callId)}")
        Log.i(HestiaCallUi.TAG, "fullScreenIntent requested callId=${HestiaCallUi.short(callId)}")
        val caller = action.optString("fromNickname", "")
        val title = if (action.optString("video") == "true") {
            HestiaStrings.get(this, R.string.incoming_video_call)
        } else {
            HestiaStrings.get(this, R.string.incoming_call)
        }
        val body = caller.ifBlank { HestiaStrings.get(this, R.string.hestia_call_fallback) }
        val canUseFullScreen = HestiaCallUi.canUseFullScreenIntent(this)
        Log.i(HestiaCallUi.TAG, "canUseFullScreenIntent=$canUseFullScreen")
        HestiaCallUi.markCallNotificationShown(this, callId)
        val contentIntent = HestiaCallUi.openAppPendingIntent(this, action)
        val fullScreenIntent = HestiaCallUi.fullScreenPendingIntent(this, action)
        val acceptIntent = HestiaCallUi.mainActivityIntent(this, copyAction(action), accept = true)
        val declineIntent = Intent(this, HestiaForegroundService::class.java).apply {
            this.action = ACTION_DECLINE_CALL
            putExtra("callId", action.optString("callId", ""))
            putExtra("fromUserId", action.optString("fromUserId", ""))
        }
        val openIntent = HestiaCallUi.mainActivityIntent(this, action, accept = false)
        Log.i(
            "HestiaCallAction",
            "CREATE_NOTIFICATION_OLD_PATH callId=${short(callId)} notificationId=${notificationId(callId, 8001)} " +
                "acceptRequestCode=${notificationId(callId, 8101)} declineRequestCode=${notificationId(callId, 8200)} openRequestCode=${notificationId(callId, 8100)} " +
                "acceptTarget=${acceptIntent.component?.className ?: "implicit"} acceptAction=${acceptIntent.action ?: "null"} acceptExtras=${acceptIntent.extras?.keySet()?.joinToString(",") ?: "none"} " +
                "declineTarget=${declineIntent.component?.className ?: "implicit"} declineAction=${declineIntent.action ?: "null"} declineExtras=${declineIntent.extras?.keySet()?.joinToString(",") ?: "none"} " +
                "openTarget=${openIntent.component?.className ?: "implicit"} openAction=${openIntent.action ?: "null"} openExtras=${openIntent.extras?.keySet()?.joinToString(",") ?: "none"}",
        )
        val notification = NotificationCompat.Builder(this, CALL_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.sym_call_incoming)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setVibrate(longArrayOf(0, 700, 250, 700, 250, 1200))
            .setSound(ringtoneUri())
            .setContentIntent(contentIntent)
            .setFullScreenIntent(fullScreenIntent, canUseFullScreen)
            .addAction(android.R.drawable.sym_action_call, HestiaStrings.get(this, R.string.accept), HestiaCallUi.openAppPendingIntent(this, copyAction(action), accept = true))
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, HestiaStrings.get(this, R.string.decline), declineIntent(action))
            .addAction(android.R.drawable.ic_menu_view, HestiaStrings.get(this, R.string.open_app), contentIntent)
            .build()
        val id = notificationId(callId, 8001)
        notificationManager.notify(id, notification)
        Log.i(HestiaCallUi.TAG, "call notification shown callId=${HestiaCallUi.short(callId)} notificationId=$id")
        if (!canUseFullScreen) {
            Log.i(HestiaCallUi.TAG, "fallback heads-up notification used reason=fullscreen_intent_disabled callId=${HestiaCallUi.short(callId)}")
            log("call UI handoff failure reason=fullscreen_intent_disabled callId=${short(callId)}")
        } else {
            log("call UI handoff success callId=${short(callId)}")
        }
        log("incoming call notification show success callId=${short(callId)}")
    }

    private fun openAppIntent(action: JSONObject): PendingIntent {
        storePendingAction(action)
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("hestia_push_action", action.toString())
        }
        return PendingIntent.getActivity(
            this,
            notificationId(action.optString("callId", action.optString("messageId", "hestia")), 8100),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun declineIntent(action: JSONObject): PendingIntent {
        val intent = Intent(this, HestiaForegroundService::class.java).apply {
            this.action = ACTION_DECLINE_CALL
            putExtra("callId", action.optString("callId", ""))
            putExtra("fromUserId", action.optString("fromUserId", ""))
        }
        return PendingIntent.getService(
            this,
            notificationId(action.optString("callId", "hestia_decline"), 8200),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun copyAction(action: JSONObject): JSONObject =
        JSONObject(action.toString())

    private fun storePendingAction(action: JSONObject) {
        val prefs = getSharedPreferences(HANDOFF_PREFS, MODE_PRIVATE)
        val raw = prefs.getString(KEY_PENDING_ACTIONS, "[]") ?: "[]"
        val array = try {
            JSONArray(raw)
        } catch (_: Exception) {
            JSONArray()
        }
        val encoded = action.toString()
        for (i in 0 until array.length()) {
            if (array.optString(i) == encoded) return
        }
        array.put(encoded)
        while (array.length() > 50) {
            array.remove(0)
        }
        prefs.edit().putString(KEY_PENDING_ACTIONS, array.toString()).apply()
    }

    private fun existingSocketReusable(config: ServiceConfig): Boolean =
        staleSocketReason(config) == null

    private fun staleSocketReason(config: ServiceConfig): String? {
        if (webSocket == null) return "missing_socket"
        if (!socketConnected) return "not_connected"
        if (!socketAuthenticated) return "not_authenticated"
        if (socketUserId != config.userId) return "user_changed"
        if (socketDeviceId != config.deviceId) return "device_changed"
        if (socketWsUrl != config.wsUrl) return "server_url_changed"
        if (socketRole != "foreground_service") return "wrong_socket_role"
        val lastServerActivityAgeMs = socketAge(socketLastServerActivityAtMs)
        if (lastServerActivityAgeMs > SOCKET_FRESHNESS_TTL_MS) {
            Log.i(
                ANDROID_WS_TAG,
                "heartbeat timeout; reconnect required lastFrameAgeMs=$lastServerActivityAgeMs thresholdMs=$SOCKET_FRESHNESS_TTL_MS",
            )
            return "heartbeat_timeout"
        }
        val authAgeMs = socketAge(socketAuthenticatedAtMs)
        if (authAgeMs > AUTH_FRESHNESS_TTL_MS) return "auth_stale"
        return null
    }

    private fun closeStaleWebSocket(reason: String?) {
        val socket = webSocket
        Log.i(ANDROID_WS_TAG, "closing stale websocket reason=${reason ?: "unknown"}")
        clearSocketState()
        HestiaAlwaysReachable.markSocketState(this, connected = false, authenticated = false)
        try {
            socket?.close(1001, "stale_${reason ?: "unknown"}")
        } catch (error: Exception) {
            Log.i(ANDROID_WS_TAG, "stale websocket close failed reason=${reason ?: "unknown"} error=${error.message}")
            socket?.cancel()
        }
    }

    private fun clearSocketState() {
        webSocket = null
        socketConnected = false
        socketAuthenticated = false
        socketConnectedAtMs = 0L
        socketLastServerActivityAtMs = 0L
        socketAuthenticatedAtMs = 0L
        socketUserId = ""
        socketDeviceId = ""
        socketWsUrl = ""
        socketRole = ""
    }

    private fun socketAge(timestampMs: Long): Long =
        if (timestampMs <= 0L) Long.MAX_VALUE else (System.currentTimeMillis() - timestampMs).coerceAtLeast(0L)

    private fun scheduleReconnect(reason: String) {
        if (reconnectScheduled || stopping) {
            Log.i(ANDROID_WS_TAG, "reconnect already scheduled reason=$reason stopping=$stopping")
            return
        }
        val delayMs = min(30_000L, 2_000L * (reconnectAttempts + 1))
        reconnectAttempts += 1
        reconnectScheduled = true
        HestiaAlwaysReachable.markLastRestartReason(this, reason)
        Log.i(ANDROID_WS_TAG, "reconnect backoff ms=$delayMs reason=$reason attempt=$reconnectAttempts")
        log("socket reconnect scheduled delayMs=$delayMs reason=$reason")
        android.os.Handler(mainLooper).postDelayed({
            reconnectScheduled = false
            connectIfReady()
        }, delayMs)
    }

    private fun storeConfig(intent: Intent?) {
        if (intent == null) return
        val edit = getSharedPreferences(CONFIG_PREFS, MODE_PRIVATE).edit()
        for (key in CONFIG_KEYS) {
            val value = intent.getStringExtra(key)
            if (!value.isNullOrBlank()) edit.putString(key, value)
        }
        edit.apply()
    }

    private fun loadConfig(): ServiceConfig {
        val prefs = getSharedPreferences(CONFIG_PREFS, MODE_PRIVATE)
        return ServiceConfig(
            wsUrl = prefs.getString(EXTRA_WS_URL, "") ?: "",
            userId = prefs.getString(EXTRA_USER_ID, "") ?: "",
            nickname = prefs.getString(EXTRA_NICKNAME, "") ?: "",
            authToken = prefs.getString(EXTRA_AUTH_TOKEN, "") ?: "",
            publicKey = prefs.getString(EXTRA_PUBLIC_KEY, "") ?: "",
            deviceId = prefs.getString(EXTRA_DEVICE_ID, "") ?: "",
            appVersion = prefs.getString(EXTRA_APP_VERSION, "") ?: "",
        )
    }

    private fun backgroundNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            BACKGROUND_NOTIFICATION_ID,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, BACKGROUND_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_notify_sync)
            .setContentTitle(HestiaStrings.get(this, R.string.hestia_brand))
            .setContentText(HestiaStrings.get(this, R.string.background_connection_active))
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setContentIntent(pendingIntent)
            .build()
    }

    private fun createChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        notificationManager.createNotificationChannel(
            NotificationChannel(BACKGROUND_CHANNEL_ID, HestiaStrings.get(this, R.string.background_connection_channel), NotificationManager.IMPORTANCE_LOW)
        )
        notificationManager.createNotificationChannel(
            NotificationChannel(MESSAGE_CHANNEL_ID, HestiaStrings.get(this, R.string.messages_channel), NotificationManager.IMPORTANCE_HIGH)
        )
        val callChannel = NotificationChannel(CALL_CHANNEL_ID, HestiaStrings.get(this, R.string.calls_channel), NotificationManager.IMPORTANCE_HIGH)
        callChannel.enableVibration(true)
        callChannel.vibrationPattern = longArrayOf(0, 700, 250, 700, 250, 1200)
        callChannel.setSound(
            ringtoneUri(),
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build(),
        )
        notificationManager.createNotificationChannel(callChannel)
    }

    private fun normalizeTimestamp(json: JSONObject): Long {
        val raw = json.optLong("timestamp", json.optLong("serverTimestamp", json.optLong("callCreatedAt", 0L)))
        return if (raw in 1..9_999_999_999L) raw * 1000L else if (raw > 0) raw else System.currentTimeMillis()
    }

    private fun notificationId(value: String, fallback: Int): Int {
        val hash = if (value.isBlank()) fallback else value.hashCode()
        return hash and 0x7fffffff
    }

    private fun ringtoneUri(): Uri =
        Uri.parse("android.resource://$packageName/raw/ringtone")

    private val notificationManager: NotificationManager
        get() = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    private fun log(message: String) {
        Log.i(TAG, "HestiaFgService $message")
    }

    private fun markNativeCallHandled(callId: String): Boolean {
        val prefs = getSharedPreferences(HANDOFF_PREFS, MODE_PRIVATE)
        val raw = prefs.getString(KEY_HANDLED_CALL_IDS, "[]") ?: "[]"
        val array = try {
            JSONArray(raw)
        } catch (_: Exception) {
            JSONArray()
        }
        for (i in 0 until array.length()) {
            if (array.optString(i) == callId) return false
        }
        array.put(callId)
        while (array.length() > 50) array.remove(0)
        prefs.edit().putString(KEY_HANDLED_CALL_IDS, array.toString()).apply()
        return true
    }

    private fun short(value: String): String =
        if (value.isBlank()) "none" else if (value.length <= 8) value else "${value.substring(0, 8)}..."

    private data class ServiceConfig(
        val wsUrl: String,
        val userId: String,
        val nickname: String,
        val authToken: String,
        val publicKey: String,
        val deviceId: String,
        val appVersion: String,
    ) {
        val ready: Boolean
            get() = wsUrl.isNotBlank() && userId.isNotBlank() && authToken.isNotBlank() && deviceId.isNotBlank()
    }

    companion object {
        const val ACTION_START = "org.hestiachat.messenger.action.START_FG_SOCKET"
        const val ACTION_STOP = "org.hestiachat.messenger.action.STOP_FG_SOCKET"
        const val ACTION_DECLINE_CALL = "org.hestiachat.messenger.action.DECLINE_CALL"
        const val ACTION_CANCEL_CALL = "org.hestiachat.messenger.action.CANCEL_CALL"
        const val EXTRA_WS_URL = "wsUrl"
        const val EXTRA_USER_ID = "userId"
        const val EXTRA_NICKNAME = "nickname"
        const val EXTRA_AUTH_TOKEN = "authToken"
        const val EXTRA_PUBLIC_KEY = "publicKey"
        const val EXTRA_DEVICE_ID = "deviceId"
        const val EXTRA_APP_VERSION = "appVersion"
        const val EXTRA_RESTART_REASON = "restartReason"
        const val HANDOFF_PREFS = "hestia_foreground_service_handoff"
        const val KEY_PENDING_ACTIONS = "pending_actions"
        const val KEY_HANDLED_CALL_IDS = "handled_call_ids"
        const val KEY_CANCELLED_CALL_NOTIFICATION_IDS = "cancelled_call_notification_ids"
        const val KEY_ACTIVE_CALL_NOTIFICATION_IDS = "active_call_notification_ids"
        const val KEY_CALL_STATE_PREFIX = "call_state_"
        const val KEY_APP_STATE = "app_state"
        const val CONFIG_PREFS = "hestia_foreground_service_config"
        private const val TAG = "HestiaFgService"
        private const val ANDROID_WS_TAG = "AndroidWs"
        private const val SOCKET_FRESHNESS_TTL_MS = 90_000L
        private const val AUTH_FRESHNESS_TTL_MS = 15 * 60_000L
        private const val BACKGROUND_NOTIFICATION_ID = 7001
        private const val BACKGROUND_CHANNEL_ID = "hestia_background_service"
        private const val MESSAGE_CHANNEL_ID = "hestia_messages"
        private const val CALL_CHANNEL_ID = "hestia_calls"
        private val CONFIG_KEYS = listOf(
            EXTRA_WS_URL,
            EXTRA_USER_ID,
            EXTRA_NICKNAME,
            EXTRA_AUTH_TOKEN,
            EXTRA_PUBLIC_KEY,
            EXTRA_DEVICE_ID,
            EXTRA_APP_VERSION,
        )

        fun hasStoredConfig(context: Context): Boolean {
            val prefs = context.getSharedPreferences(CONFIG_PREFS, Context.MODE_PRIVATE)
            return (prefs.getString(EXTRA_WS_URL, "") ?: "").isNotBlank() &&
                (prefs.getString(EXTRA_USER_ID, "") ?: "").isNotBlank() &&
                (prefs.getString(EXTRA_AUTH_TOKEN, "") ?: "").isNotBlank() &&
                (prefs.getString(EXTRA_DEVICE_ID, "") ?: "").isNotBlank()
        }

        fun startAlwaysReachable(context: Context, reason: String): Boolean {
            if (!hasStoredConfig(context)) {
                Log.i(TAG, "always reachable start skipped reason=missing_config source=$reason")
                return false
            }
            val intent = Intent(context, HestiaForegroundService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_RESTART_REASON, reason)
            }
            return try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
                HestiaAlwaysReachable.markLastRestartReason(context, reason)
                Log.i(TAG, "always reachable start requested reason=$reason")
                true
            } catch (error: Exception) {
                HestiaAlwaysReachable.markLastRestartReason(context, "start_blocked_$reason")
                Log.w(TAG, "always reachable start blocked reason=$reason error=${error.message}")
                false
            }
        }
    }
}
