package com.tanguyhardion.file_vault

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager

/**
 * Switches the launcher icon between the per-accent activity aliases declared
 * in AndroidManifest.xml (`.Launcher<Accent>`).
 *
 * The switch is only recorded by [request] and applied by [applyPending] once
 * the app leaves the foreground: toggling the alias that launched the running
 * task can close the app on some launchers.
 */
object AppIconSwitcher {
    /** Must match AppAccent ids in lib/theme/app_accent.dart. */
    private val accents =
        listOf("teal", "blue", "indigo", "purple", "pink", "red", "orange", "green")
    private const val DEFAULT_ACCENT = "teal"

    private const val PREFS = "app_icon"
    private const val KEY_PENDING = "pending_accent"

    fun request(context: Context, accent: String) {
        if (accent !in accents) return
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString(KEY_PENDING, accent).apply()
    }

    fun applyPending(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val accent = prefs.getString(KEY_PENDING, null) ?: return
        val pm = context.packageManager
        // Enable the new alias before disabling the others so there is always a
        // launcher entry.
        val ordered = listOf(accent) + accents.filter { it != accent }
        for (a in ordered) {
            val component = alias(context, a)
            val enabled = a == accent
            if (isEnabled(pm, component, a) == enabled) continue
            pm.setComponentEnabledSetting(
                component,
                if (enabled) PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                else PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP,
            )
        }
        prefs.edit().remove(KEY_PENDING).apply()
    }

    private fun alias(context: Context, accent: String): ComponentName {
        val classPackage = MainActivity::class.java.name.substringBeforeLast('.')
        val name = accent.replaceFirstChar { it.uppercaseChar() }
        return ComponentName(context.packageName, "$classPackage.Launcher$name")
    }

    private fun isEnabled(pm: PackageManager, component: ComponentName, accent: String) =
        when (pm.getComponentEnabledSetting(component)) {
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
            PackageManager.COMPONENT_ENABLED_STATE_DEFAULT -> accent == DEFAULT_ACCENT
            else -> false
        }
}
