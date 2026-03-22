package com.example.voice_recording_app_gui

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.Manifest
import android.telephony.TelephonyManager
import androidx.core.content.ContextCompat

/**
 * Auto-starts/stops background call monitoring based on call state.
 */
class CallReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != TelephonyManager.ACTION_PHONE_STATE_CHANGED) return

        val state = intent.getStringExtra(TelephonyManager.EXTRA_STATE) ?: return
        if (!CallMonitorPrefs.isEnabled(context)) return
        if (!hasRequiredPermissions(context)) return

        when (state) {
            TelephonyManager.EXTRA_STATE_OFFHOOK -> startMonitoringService(context)
            TelephonyManager.EXTRA_STATE_IDLE -> stopMonitoringService(context)
        }
    }

    private fun startMonitoringService(context: Context) {
        val serviceIntent = Intent(context, CallMonitoringService::class.java).apply {
            action = CallMonitoringService.ACTION_START
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            ContextCompat.startForegroundService(context, serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }

    private fun stopMonitoringService(context: Context) {
        val serviceIntent = Intent(context, CallMonitoringService::class.java).apply {
            action = CallMonitoringService.ACTION_STOP
        }
        context.startService(serviceIntent)
    }

    private fun hasRequiredPermissions(context: Context): Boolean {
        val hasRecordAudio = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.RECORD_AUDIO,
        ) == PackageManager.PERMISSION_GRANTED
        val hasPhoneState = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.READ_PHONE_STATE,
        ) == PackageManager.PERMISSION_GRANTED
        return hasRecordAudio && hasPhoneState
    }
}
