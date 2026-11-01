package eu.lielu.lieluapp

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle

/**
 * Réglage du widget proposé par Android (ajout du widget, ou « Paramètres du widget »
 * au long appui sur Android 12+) : valide le widget puis ouvre la page « Widget
 * d'accueil » du store (ordre et taille des icônes).
 */
class WidgetConfigureActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val widgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID,
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID
        setResult(RESULT_OK, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId))
        startActivity(
            Intent(this, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                .putExtra(MainActivity.EXTRA_OPEN_APP, HomeWidget.SETTINGS_TOKEN),
        )
        finish()
    }
}
