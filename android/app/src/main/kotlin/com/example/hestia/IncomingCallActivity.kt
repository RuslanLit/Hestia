package com.example.hestia

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Color
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import org.json.JSONObject

class IncomingCallActivity : Activity() {
    private val handler = Handler(Looper.getMainLooper())
    private var callId = ""
    private var fromUserId = ""
    private var fromNickname = ""
    private var video = false
    private var serverTimestamp = 0L
    private var ttlMs = 45_000L
    private var openedAtMs = 0L
    private var payload = "{}"
    private var player: MediaPlayer? = null
    private var closed = false

    private val closeReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action != HestiaCallUi.ACTION_CLOSE_CALL_UI) return
            val incomingCallId = intent.getStringExtra(HestiaCallUi.EXTRA_CALL_ID) ?: ""
            if (incomingCallId == callId) {
                finishCallUi(intent.getStringExtra("reason") ?: "closed")
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        applyLockScreenFlags()
        readIntent(intent)
        openedAtMs = System.currentTimeMillis()
        Log.i(HestiaCallUi.TAG, "IncomingCallActivity opened callId=${HestiaCallUi.short(callId)}")
        registerCloseReceiver()
        setContentView(buildUi())
        startRinging()
        scheduleExpiry()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        readIntent(intent)
        Log.i(HestiaCallUi.TAG, "IncomingCallActivity opened callId=${HestiaCallUi.short(callId)}")
    }

    override fun onDestroy() {
        stopRinging("activity_finish")
        try {
            unregisterReceiver(closeReceiver)
        } catch (_: Exception) {
        }
        handler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }

    private fun readIntent(intent: Intent?) {
        if (intent == null) return
        callId = intent.getStringExtra(HestiaCallUi.EXTRA_CALL_ID) ?: ""
        fromUserId = intent.getStringExtra(HestiaCallUi.EXTRA_FROM_USER_ID) ?: ""
        fromNickname = intent.getStringExtra(HestiaCallUi.EXTRA_FROM_NICKNAME) ?: ""
        video = intent.getBooleanExtra(HestiaCallUi.EXTRA_VIDEO, false)
        val receivedAtMs = System.currentTimeMillis()
        val rawServerTimestamp = intent.getLongExtra(HestiaCallUi.EXTRA_SERVER_TIMESTAMP, 0L)
        val normalizedServerTimestamp =
            if (rawServerTimestamp > 0L) rawServerTimestamp else receivedAtMs
        serverTimestamp = normalizedServerTimestamp
        val rawTtlMs = intent.getLongExtra(HestiaCallUi.EXTRA_TTL_MS, 45_000L)
        ttlMs = if (rawTtlMs > 0L) rawTtlMs else 45_000L
        Log.i(
            "HestiaCallAction",
            "call receivedAtMs=$receivedAtMs serverTimestamp=$rawServerTimestamp ttlMs=$rawTtlMs normalized ttlMs=$ttlMs normalized ageMs=${(receivedAtMs - serverTimestamp).coerceAtLeast(0L)}",
        )
        payload = intent.getStringExtra("hestia_push_action") ?: JSONObject()
            .put("type", "call")
            .put("callId", callId)
            .put("fromUserId", fromUserId)
            .put("fromNickname", fromNickname)
            .put("video", video.toString())
            .put("timestamp", serverTimestamp.toString())
            .put("ttlMs", ttlMs.toString())
            .toString()
    }

    private fun applyLockScreenFlags() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD,
            )
        }
        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_ALLOW_LOCK_WHILE_SCREEN_ON,
        )
    }

    private fun registerCloseReceiver() {
        val filter = IntentFilter(HestiaCallUi.ACTION_CLOSE_CALL_UI)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(closeReceiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(closeReceiver, filter)
        }
    }

    private fun buildUi(): View {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(48, 72, 48, 72)
            setBackgroundColor(Color.rgb(15, 23, 42))
        }
        val title = TextView(this).apply {
            text = if (video) {
                HestiaStrings.get(this@IncomingCallActivity, R.string.incoming_video_call)
            } else {
                HestiaStrings.get(this@IncomingCallActivity, R.string.incoming_voice_call)
            }
            textSize = 22f
            setTextColor(Color.rgb(226, 232, 240))
            gravity = Gravity.CENTER
        }
        val caller = TextView(this).apply {
            text = fromNickname.ifBlank {
                HestiaStrings.get(this@IncomingCallActivity, R.string.hestia_call_fallback)
            }
            textSize = 34f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            setPadding(0, 24, 0, 48)
        }
        val actions = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
        }
        val decline = Button(this).apply {
            text = HestiaStrings.get(this@IncomingCallActivity, R.string.decline)
            setOnClickListener { decline() }
        }
        val accept = Button(this).apply {
            text = HestiaStrings.get(this@IncomingCallActivity, R.string.accept)
            setOnClickListener { accept() }
        }
        actions.addView(decline, LinearLayout.LayoutParams(0, 128, 1f).apply { marginEnd = 16 })
        actions.addView(accept, LinearLayout.LayoutParams(0, 128, 1f).apply { marginStart = 16 })
        root.addView(title, LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        root.addView(caller, LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        root.addView(actions, LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        return root
    }

    private fun startRinging() {
        try {
            player = MediaPlayer().apply {
                setDataSource(this@IncomingCallActivity, Uri.parse("android.resource://$packageName/raw/ringtone"))
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build(),
                )
                isLooping = true
                prepare()
                start()
            }
            Log.i(HestiaCallUi.TAG, "ringtone start source=IncomingCallActivity callId=${HestiaCallUi.short(callId)}")
        } catch (error: Exception) {
            Log.w(HestiaCallUi.TAG, "ringtone start failed callId=${HestiaCallUi.short(callId)} error=${error.message}")
        }
        try {
            val pattern = longArrayOf(0, 700, 250, 700, 250, 1200)
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(VibrationEffect.createWaveform(pattern, 0))
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(pattern, 0)
            }
        } catch (_: Exception) {
        }
    }

    private fun stopRinging(reason: String) {
        try {
            player?.stop()
            player?.release()
        } catch (_: Exception) {
        }
        player = null
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).cancel()
            } else {
                @Suppress("DEPRECATION")
                (getSystemService(Context.VIBRATOR_SERVICE) as Vibrator).cancel()
            }
        } catch (_: Exception) {
        }
        Log.i(HestiaCallUi.TAG, "ringtone stop reason=$reason callId=${HestiaCallUi.short(callId)}")
    }

    private fun scheduleExpiry() {
        val ageMs = (System.currentTimeMillis() - serverTimestamp).coerceAtLeast(0L)
        val freshCall = ageMs < MIN_VISIBLE_RING_MS
        val expired = ageMs > ttlMs && !freshCall
        Log.i(
            HestiaCallUi.TAG,
            "expiry check callId=${HestiaCallUi.short(callId)} ageMs=$ageMs ttlMs=$ttlMs expired=$expired",
        )
        if (freshCall) {
            Log.i(HestiaCallUi.TAG, "activity kept alive reason=fresh_call callId=${HestiaCallUi.short(callId)}")
        }
        if (expired) {
            val delayForMinimumWindow = (MIN_VISIBLE_RING_MS - (System.currentTimeMillis() - openedAtMs)).coerceAtLeast(0L)
            handler.postDelayed({
                if (!closed) {
                    Log.i(HestiaCallUi.TAG, "call expired callId=${HestiaCallUi.short(callId)}")
                    finishCallUi("real_timeout")
                }
            }, delayForMinimumWindow)
            return
        }
        val delayMs = (ttlMs - ageMs).coerceAtLeast(MIN_VISIBLE_RING_MS)
        handler.postDelayed({
            if (!closed) {
                Log.i(HestiaCallUi.TAG, "call expired callId=${HestiaCallUi.short(callId)}")
                finishCallUi("real_timeout")
            }
        }, delayMs)
    }

    private fun accept() {
        Log.i(HestiaCallUi.TAG, "accept tapped callId=${HestiaCallUi.short(callId)}")
        HestiaCallUi.setCallState(this, callId, HestiaCallUi.CallStateValue.ACCEPTING, "fullscreen_accept")
        stopRinging("accept")
        val action = JSONObject(payload).put("acceptCall", "true")
        HestiaCallUi.storePendingActionReplacingCall(this, action)
        startActivity(HestiaCallUi.mainActivityIntent(this, action, accept = true))
        finishCallUi("accept")
    }

    private fun decline() {
        Log.i(HestiaCallUi.TAG, "decline tapped callId=${HestiaCallUi.short(callId)}")
        HestiaCallUi.setCallState(this, callId, HestiaCallUi.CallStateValue.DECLINED, "fullscreen_decline")
        stopRinging("decline")
        val rejectAction = JSONObject(payload).put("type", "reject_call")
        HestiaCallUi.storePendingActionReplacingCall(this, rejectAction)
        startService(Intent(this, HestiaForegroundService::class.java).apply {
            action = HestiaForegroundService.ACTION_DECLINE_CALL
            putExtra("callId", callId)
            putExtra("fromUserId", fromUserId)
        })
        startActivity(HestiaCallUi.mainActivityIntent(this, rejectAction))
        finishCallUi("decline")
    }

    private fun finishCallUi(reason: String) {
        if (closed) return
        closed = true
        stopRinging(reason)
        if (callId.isNotBlank()) {
            HestiaCallUi.cancelCallNotification(this, callId)
        }
        finishAndRemoveTask()
        val normalizedReason = when (reason) {
            "remote_hangup" -> "hangup"
            "accepted" -> "accept"
            "declined" -> "decline"
            "expired" -> "real_timeout"
            else -> reason
        }
        Log.i(HestiaCallUi.TAG, "activity closed reason=$normalizedReason callId=${HestiaCallUi.short(callId)}")
        Log.i(HestiaCallUi.TAG, "IncomingCallActivity closed reason=$normalizedReason callId=${HestiaCallUi.short(callId)}")
    }

    companion object {
        private const val MIN_VISIBLE_RING_MS = 5_000L
    }
}
