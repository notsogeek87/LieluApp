package eu.lielu.lieluapp

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.Build
import android.widget.RemoteViews

/**
 * Widget « Lanceur Lielu » : un simple bouton discret. Un appui ouvre
 * [LauncherPopupActivity], qui déploie les icônes des apps Lielu depuis le bouton.
 */
class LauncherWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        // Mutable : le lanceur y ajoute la position du bouton (sourceBounds), d'où
        // part l'animation. L'intent est explicite, il ne peut pas être détourné.
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) flags = flags or PendingIntent.FLAG_MUTABLE
        val open = PendingIntent.getActivity(
            context, 3,
            Intent(context, LauncherPopupActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            flags,
        )
        for (id in ids) {
            val views = RemoteViews(context.packageName, R.layout.widget_launcher)
            views.setOnClickPendingIntent(R.id.launcher_button, open)
            manager.updateAppWidget(id, views)
        }
    }
}
