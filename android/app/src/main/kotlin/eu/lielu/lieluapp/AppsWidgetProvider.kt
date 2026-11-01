package eu.lielu.lieluapp

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.widget.RemoteViews

/**
 * Widget « Applications Lielu » : grille de toutes les apps du catalogue, dans
 * l'ordre choisi par l'utilisateur dans le store (Paramètres → Widget d'accueil).
 */
class AppsWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        updateAll(context, manager, ids)
        @Suppress("DEPRECATION")
        manager.notifyAppWidgetViewDataChanged(ids, R.id.widget_grid)
    }

    companion object {
        private const val EXTRA_VERSION = "eu.lielu.lieluapp.widget.VERSION"

        private fun flags(mutable: Boolean): Int {
            var f = PendingIntent.FLAG_UPDATE_CURRENT
            if (mutable && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) f = f or PendingIntent.FLAG_MUTABLE
            if (!mutable && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) f = f or PendingIntent.FLAG_IMMUTABLE
            return f
        }

        fun updateAll(context: Context, manager: AppWidgetManager, ids: IntArray) {
            val openStore = PendingIntent.getActivity(
                context, 0,
                Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                flags(mutable = false),
            )
            // Modèle complété par chaque case de la grille (setOnClickFillInIntent) : doit être mutable.
            val itemTemplate = PendingIntent.getActivity(
                context, 1,
                Intent(context, WidgetLaunchActivity::class.java),
                flags(mutable = true),
            )
            for (id in ids) {
                val views = RemoteViews(context.packageName, HomeWidget.widgetLayout(context))
                val adapter = Intent(context, AppsWidgetService::class.java).apply {
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
                    // Intent unique par widget ET par version des données : à chaque envoi
                    // du store (ordre, taille, catalogue), le lanceur crée un nouvel
                    // adaptateur au lieu de réafficher sa liste en cache.
                    putExtra(EXTRA_VERSION, HomeWidget.version(context))
                    data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
                }
                @Suppress("DEPRECATION")
                views.setRemoteAdapter(R.id.widget_grid, adapter)
                views.setEmptyView(R.id.widget_grid, R.id.widget_empty)
                views.setPendingIntentTemplate(R.id.widget_grid, itemTemplate)
                views.setOnClickPendingIntent(R.id.widget_header, openStore)
                views.setOnClickPendingIntent(R.id.widget_empty, openStore)
                manager.updateAppWidget(id, views)
            }
        }
    }
}
