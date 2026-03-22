package com.example.voice_recording_app_gui

import android.content.Context

object CallMonitorPrefs {
    private const val PREFS_NAME = "FlutterSharedPreferences"
    private const val KEY_ENABLED = "flutter.call_monitor_enabled"
    private const val KEY_CHUNK_SECONDS = "flutter.call_monitor_chunk_seconds"
    private const val KEY_VIBRATE_ALERT = "flutter.call_monitor_vibrate_alert"

    const val DEFAULT_CHUNK_SECONDS = 12

    fun isEnabled(context: Context): Boolean {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getBoolean(KEY_ENABLED, false)
    }

    fun chunkSeconds(context: Context): Int {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val value = prefs.getInt(KEY_CHUNK_SECONDS, DEFAULT_CHUNK_SECONDS)
        return value.coerceIn(8, 30)
    }

    fun vibrateAlert(context: Context): Boolean {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getBoolean(KEY_VIBRATE_ALERT, true)
    }
}
