package com.example.hestia

import android.content.Context
import android.content.res.Configuration
import androidx.annotation.StringRes
import java.util.Locale

object HestiaStrings {
    private const val FLUTTER_PREFS = "FlutterSharedPreferences"
    private const val LANGUAGE_KEY = "flutter.languageCode"
    private val supportedLanguages = setOf("uk", "ru", "en", "pl", "es", "cs", "de")

    fun get(context: Context, @StringRes id: Int): String {
        val selected = context
            .getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
            .getString(LANGUAGE_KEY, null)
        if (selected !in supportedLanguages) {
            return context.getString(id)
        }
        val configuration = Configuration(context.resources.configuration)
        configuration.setLocale(Locale.forLanguageTag(selected!!))
        return context.createConfigurationContext(configuration).getString(id)
    }
}
