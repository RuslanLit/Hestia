package com.example.hestia

import android.app.NotificationManager
import android.app.NotificationChannel
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import org.json.JSONObject

object HestiaCallUi {
    const val TAG = "HestiaCallUi"
    const val ACTION_CLOSE_CALL_UI = "org.hestiachat.messenger.action.CLOSE_CALL_UI"
    const val ACTION_MANAGE_FULL_SCREEN = "android.settings.MANAGE_APP_USE_FULL_SCREEN_INTENT"
    const val ACTION_ACCEPT_CALL = "org.hestiachat.messenger.action.ACCEPT_CALL"
    const val ACTION_OPEN_CALL = "org.hestiachat.messenger.action.OPEN_CALL"
    const val EXTRA_CALL_ID = "callId"
    const val EXTRA_FROM_USER_ID = "fromUserId"
    const val EXTRA_FROM_NICKNAME = "fromNickname"
    const val EXTRA_VIDEO = "video"
    const val EXTRA_SERVER_TIMESTAMP = "serverTimestamp"
    const val EXTRA_TTL_MS = "ttlMs"

    enum class CallStateValue {
        RINGING,
        ACCEPTING,
        CONNECTING,
        ACTIVE,
        DECLINED,
        CANCELLED,
        MISSED,
        ENDED,
    }

    fun incomingActivityIntent(context: Context, action: JSONObject): Intent =
        Intent(context, IncomingCallActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(EXTRA_CALL_ID, action.optString("callId", ""))
            putExtra(EXTRA_FROM_USER_ID, action.optString("fromUserId", ""))
            putExtra(EXTRA_FROM_NICKNAME, action.optString("fromNickname", ""))
            putExtra(EXTRA_VIDEO, action.optString("video") == "true" || action.optBoolean("video", false))
            putExtra(EXTRA_SERVER_TIMESTAMP, action.optLong("timestamp", action.optLong("serverTimestamp", 0L)))
            putExtra(EXTRA_TTL_MS, action.optLong("ttlMs", 45_000L))
            putExtra("hestia_push_action", action.toString())
        }

    fun mainActivityIntent(context: Context, action: JSONObject, accept: Boolean = false): Intent {
        val payload = JSONObject(action.toString())
        if (accept) payload.put("acceptCall", "true")
        return Intent(context, MainActivity::class.java).apply {
            this.action = if (accept) ACTION_ACCEPT_CALL else ACTION_OPEN_CALL
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("hestia_action", if (accept) "accept_call" else "open_call")
            putExtra(EXTRA_CALL_ID, payload.optString("callId", ""))
            putExtra(EXTRA_FROM_USER_ID, payload.optString("fromUserId", ""))
            putExtra(EXTRA_FROM_NICKNAME, payload.optString("fromNickname", ""))
            putExtra(EXTRA_VIDEO, payload.optString("video") == "true" || payload.optBoolean("video", false))
            putExtra(EXTRA_SERVER_TIMESTAMP, payload.optLong("timestamp", payload.optLong("serverTimestamp", 0L)))
            putExtra(EXTRA_TTL_MS, payload.optLong("ttlMs", 45_000L))
            putExtra("hestia_push_action", payload.toString())
        }
    }

    fun fullScreenPendingIntent(context: Context, action: JSONObject): PendingIntent =
        PendingIntent.getActivity(
            context,
            notificationId(action.optString("callId", "hestia_fullscreen"), 8300),
            incomingActivityIntent(context, action),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    fun openAppPendingIntent(context: Context, action: JSONObject, accept: Boolean = false): PendingIntent =
        PendingIntent.getActivity(
            context,
            notificationId(action.optString("callId", action.optString("messageId", "hestia")), if (accept) 8101 else 8100),
            mainActivityIntent(context, action, accept),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    fun describeIntent(intent: Intent): String =
        "target=${intent.component?.className ?: "implicit"} action=${intent.action ?: "null"} extras=${intent.extras?.keySet()?.joinToString(",") ?: "none"}"

    fun canUseFullScreenIntent(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < 34) return true
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return nm.canUseFullScreenIntent()
    }

    fun closeCallUi(context: Context, callId: String, reason: String) {
        if (callId.isBlank()) return
        Log.i(TAG, if (reason == "remote_hangup") "remote hangup closed callId=${short(callId)}" else "close requested reason=$reason callId=${short(callId)}")
        context.sendBroadcast(Intent(ACTION_CLOSE_CALL_UI).apply {
            setPackage(context.packageName)
            putExtra(EXTRA_CALL_ID, callId)
            putExtra("reason", reason)
        })
    }

    fun cancelCallNotification(context: Context, callId: String): Boolean {
        if (callId.isBlank()) return false
        val id = notificationId(callId, 8001)
        Log.i(TAG, "cancel call notification requested callId=${short(callId)} notificationId=$id")
        val prefs = context.getSharedPreferences(HestiaForegroundService.HANDOFF_PREFS, Context.MODE_PRIVATE)
        val raw = prefs.getString(HestiaForegroundService.KEY_CANCELLED_CALL_NOTIFICATION_IDS, "[]") ?: "[]"
        val array = try {
            JSONArray(raw)
        } catch (_: Exception) {
            JSONArray()
        }
        for (i in 0 until array.length()) {
            if (array.optString(i) == callId) {
                Log.i(TAG, "duplicate cancel ignored callId=${short(callId)}")
                return false
            }
        }
        notificationManager(context).cancel(id)
        removeActiveCallNotification(context, callId)
        array.put(callId)
        while (array.length() > 80) array.remove(0)
        prefs.edit().putString(HestiaForegroundService.KEY_CANCELLED_CALL_NOTIFICATION_IDS, array.toString()).apply()
        Log.i(TAG, "cancel call notification success callId=${short(callId)}")
        return true
    }

    private fun removeActiveCallNotification(context: Context, callId: String) {
        val prefs = context.getSharedPreferences(HestiaForegroundService.HANDOFF_PREFS, Context.MODE_PRIVATE)
        val raw = prefs.getString(HestiaForegroundService.KEY_ACTIVE_CALL_NOTIFICATION_IDS, "[]") ?: "[]"
        val array = try {
            JSONArray(raw)
        } catch (_: Exception) {
            JSONArray()
        }
        val next = JSONArray()
        for (i in 0 until array.length()) {
            val value = array.optString(i)
            if (value.isNotBlank() && value != callId) next.put(value)
        }
        prefs.edit().putString(HestiaForegroundService.KEY_ACTIVE_CALL_NOTIFICATION_IDS, next.toString()).apply()
    }

    fun showIncomingCallNotification(context: Context, action: JSONObject): Boolean {
        val callId = action.optString("callId", "")
        if (callId.isBlank()) return false
        Log.i(TAG, "show call notification requested callId=${short(callId)} source=native")
        if (isCallNotificationActive(context, callId)) {
            Log.i("HestiaCallAction", "duplicate notification suppressed callId=${short(callId)}")
            return false
        }
        val state = callState(context, callId)
        if (isAppForeground(context)) {
            Log.i(TAG, "show call notification suppressed callId=${short(callId)} reason=foreground_app")
            return false
        }
        if (state == CallStateValue.ACCEPTING || state == CallStateValue.CONNECTING || state == CallStateValue.ACTIVE) {
            Log.i(TAG, "show call notification suppressed callId=${short(callId)} reason=already_accepting_or_active")
            return false
        }
        storePendingAction(context, action)
        setCallState(context, callId, CallStateValue.RINGING, "native_show")
        markCallNotificationShown(context, callId)
        ensureCallChannel(context)
        Log.i(TAG, "fullScreenIntent requested callId=${short(callId)}")
        val canUseFullScreen = canUseFullScreenIntent(context)
        Log.i(TAG, "canUseFullScreenIntent=$canUseFullScreen")
        val caller = action.optString("fromNickname", "")
        val title = if (action.optString("video") == "true" || action.optBoolean("video", false)) {
            HestiaStrings.get(context, R.string.incoming_video_call)
        } else {
            HestiaStrings.get(context, R.string.incoming_call)
        }
        val openIntent = mainActivityIntent(context, action, accept = false)
        val acceptIntent = mainActivityIntent(context, action, accept = true)
        val declineIntent = Intent(context, HestiaForegroundService::class.java).apply {
            this.action = HestiaForegroundService.ACTION_DECLINE_CALL
            putExtra("callId", action.optString("callId", ""))
            putExtra("fromUserId", action.optString("fromUserId", ""))
        }
        val openRequestCode = notificationId(callId, 8100)
        val acceptRequestCode = notificationId(callId, 8101)
        val declineRequestCode = notificationId(callId, 8200)
        Log.i(
            "HestiaCallAction",
            "CREATE_NOTIFICATION callId=${short(callId)} notificationId=${notificationId(callId, 8001)} " +
                "acceptRequestCode=$acceptRequestCode declineRequestCode=$declineRequestCode openRequestCode=$openRequestCode " +
                "acceptTarget=${acceptIntent.component?.className ?: "implicit"} acceptAction=${acceptIntent.action ?: "null"} acceptExtras=${acceptIntent.extras?.keySet()?.joinToString(",") ?: "none"} " +
                "declineTarget=${declineIntent.component?.className ?: "implicit"} declineAction=${declineIntent.action ?: "null"} declineExtras=${declineIntent.extras?.keySet()?.joinToString(",") ?: "none"} " +
                "openTarget=${openIntent.component?.className ?: "implicit"} openAction=${openIntent.action ?: "null"} openExtras=${openIntent.extras?.keySet()?.joinToString(",") ?: "none"}",
        )
        val notification = NotificationCompat.Builder(context, CALL_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.sym_call_incoming)
            .setContentTitle(title)
            .setContentText(caller.ifBlank { HestiaStrings.get(context, R.string.hestia_call_fallback) })
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setVibrate(CALL_VIBRATION_PATTERN)
            .setSound(ringtoneUri(context))
            .setContentIntent(
                PendingIntent.getActivity(
                    context,
                    openRequestCode,
                    openIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
            )
            .setFullScreenIntent(fullScreenPendingIntent(context, action), canUseFullScreen)
            .addAction(
                android.R.drawable.sym_action_call,
                HestiaStrings.get(context, R.string.accept),
                PendingIntent.getActivity(
                    context,
                    acceptRequestCode,
                    acceptIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                ),
            )
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                HestiaStrings.get(context, R.string.decline),
                PendingIntent.getService(
                    context,
                    declineRequestCode,
                    declineIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                ),
            )
            .addAction(
                android.R.drawable.ic_menu_view,
                HestiaStrings.get(context, R.string.open_app),
                PendingIntent.getActivity(
                    context,
                    openRequestCode,
                    openIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                ),
            )
            .build()
        val id = notificationId(callId, 8001)
        notificationManager(context).notify(id, notification)
        Log.i(TAG, "call notification shown callId=${short(callId)} notificationId=$id")
        if (!canUseFullScreen) {
            Log.i(TAG, "fallback heads-up notification used reason=fullscreen_intent_disabled callId=${short(callId)}")
        }
        return true
    }

    fun setCallState(context: Context, callId: String, state: CallStateValue, source: String) {
        if (callId.isBlank()) return
        val prefs = context.getSharedPreferences(HestiaForegroundService.HANDOFF_PREFS, Context.MODE_PRIVATE)
        val key = "${HestiaForegroundService.KEY_CALL_STATE_PREFIX}$callId"
        val old = prefs.getString(key, null)
        val next = state.name.lowercase()
        if (old == next) return
        prefs.edit().putString(key, next).apply()
        Log.i(TAG, "call state transition callId=${short(callId)} old=${old ?: "absent"} new=$next source=$source")
    }

    fun callState(context: Context, callId: String): CallStateValue? {
        if (callId.isBlank()) return null
        val raw = context.getSharedPreferences(HestiaForegroundService.HANDOFF_PREFS, Context.MODE_PRIVATE)
            .getString("${HestiaForegroundService.KEY_CALL_STATE_PREFIX}$callId", null)
            ?: return null
        return when (raw) {
            "ringing" -> CallStateValue.RINGING
            "accepting" -> CallStateValue.ACCEPTING
            "connecting" -> CallStateValue.CONNECTING
            "active" -> CallStateValue.ACTIVE
            "declined" -> CallStateValue.DECLINED
            "cancelled" -> CallStateValue.CANCELLED
            "missed" -> CallStateValue.MISSED
            "ended" -> CallStateValue.ENDED
            else -> null
        }
    }

    fun updateAppState(context: Context, state: String) {
        context.getSharedPreferences(HestiaForegroundService.HANDOFF_PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(HestiaForegroundService.KEY_APP_STATE, state)
            .apply()
    }

    private fun isAppForeground(context: Context): Boolean {
        val state = context.getSharedPreferences(HestiaForegroundService.HANDOFF_PREFS, Context.MODE_PRIVATE)
            .getString(HestiaForegroundService.KEY_APP_STATE, "unknown")
        return state == "resumed" || state == "inactive"
    }

    private fun declinePendingIntent(context: Context, action: JSONObject): PendingIntent {
        val intent = Intent(context, HestiaForegroundService::class.java).apply {
            this.action = HestiaForegroundService.ACTION_DECLINE_CALL
            putExtra("callId", action.optString("callId", ""))
            putExtra("fromUserId", action.optString("fromUserId", ""))
        }
        return PendingIntent.getService(
            context,
            notificationId(action.optString("callId", "hestia_decline"), 8200),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun ensureCallChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CALL_CHANNEL_ID,
            HestiaStrings.get(context, R.string.calls_channel),
            NotificationManager.IMPORTANCE_HIGH,
        )
        channel.enableVibration(true)
        channel.vibrationPattern = CALL_VIBRATION_PATTERN
        channel.setSound(
            ringtoneUri(context),
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build(),
        )
        notificationManager(context).createNotificationChannel(channel)
    }

    private fun notificationManager(context: Context): NotificationManager =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    private fun ringtoneUri(context: Context): Uri =
        Uri.parse("android.resource://${context.packageName}/raw/ringtone")

    fun storePendingAction(context: Context, action: JSONObject) {
        val prefs = context.getSharedPreferences(HestiaForegroundService.HANDOFF_PREFS, Context.MODE_PRIVATE)
        val raw = prefs.getString(HestiaForegroundService.KEY_PENDING_ACTIONS, "[]") ?: "[]"
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
        while (array.length() > 50) array.remove(0)
        prefs.edit().putString(HestiaForegroundService.KEY_PENDING_ACTIONS, array.toString()).apply()
    }

    fun storePendingActionReplacingCall(context: Context, action: JSONObject) {
        val callId = action.optString("callId", "")
        val prefs = context.getSharedPreferences(HestiaForegroundService.HANDOFF_PREFS, Context.MODE_PRIVATE)
        val raw = prefs.getString(HestiaForegroundService.KEY_PENDING_ACTIONS, "[]") ?: "[]"
        val existing = try {
            JSONArray(raw)
        } catch (_: Exception) {
            JSONArray()
        }
        val next = JSONArray()
        var duplicate = false
        val encoded = action.toString()
        for (i in 0 until existing.length()) {
            val item = existing.optString(i)
            if (item == encoded) duplicate = true
            val itemCallId = try {
                JSONObject(item).optString("callId", "")
            } catch (_: Exception) {
                ""
            }
            if (callId.isBlank() || itemCallId != callId) next.put(item)
        }
        if (duplicate) {
            Log.i("HestiaCallAction", "duplicate action ignored callId=${short(callId)}")
        }
        next.put(action.toString())
        prefs.edit().putString(HestiaForegroundService.KEY_PENDING_ACTIONS, next.toString()).apply()
        Log.i("HestiaCallAction", "action stored pending callId=${short(callId)}")
    }

    fun markCallNotificationShown(context: Context, callId: String) {
        val prefs = context.getSharedPreferences(HestiaForegroundService.HANDOFF_PREFS, Context.MODE_PRIVATE)
        val raw = prefs.getString(HestiaForegroundService.KEY_CANCELLED_CALL_NOTIFICATION_IDS, "[]") ?: "[]"
        val array = try {
            JSONArray(raw)
        } catch (_: Exception) {
            JSONArray()
        }
        val next = JSONArray()
        for (i in 0 until array.length()) {
            val value = array.optString(i)
            if (value.isNotBlank() && value != callId) next.put(value)
        }
        val activeRaw = prefs.getString(HestiaForegroundService.KEY_ACTIVE_CALL_NOTIFICATION_IDS, "[]") ?: "[]"
        val active = try {
            JSONArray(activeRaw)
        } catch (_: Exception) {
            JSONArray()
        }
        var exists = false
        for (i in 0 until active.length()) {
            if (active.optString(i) == callId) exists = true
        }
        if (!exists) active.put(callId)
        prefs.edit()
            .putString(HestiaForegroundService.KEY_CANCELLED_CALL_NOTIFICATION_IDS, next.toString())
            .putString(HestiaForegroundService.KEY_ACTIVE_CALL_NOTIFICATION_IDS, active.toString())
            .apply()
    }

    private fun isCallNotificationActive(context: Context, callId: String): Boolean {
        val raw = context.getSharedPreferences(HestiaForegroundService.HANDOFF_PREFS, Context.MODE_PRIVATE)
            .getString(HestiaForegroundService.KEY_ACTIVE_CALL_NOTIFICATION_IDS, "[]") ?: "[]"
        val array = try {
            JSONArray(raw)
        } catch (_: Exception) {
            JSONArray()
        }
        for (i in 0 until array.length()) {
            if (array.optString(i) == callId) return true
        }
        return false
    }

    fun notificationId(value: String, fallback: Int): Int {
        val hash = if (value.isBlank()) fallback else value.hashCode()
        return hash and 0x7fffffff
    }

    fun short(value: String): String =
        if (value.isBlank()) "none" else if (value.length <= 8) value else "${value.substring(0, 8)}..."

    private const val CALL_CHANNEL_ID = "hestia_calls"
    private val CALL_VIBRATION_PATTERN = longArrayOf(0, 700, 250, 700, 250, 1200)
}
