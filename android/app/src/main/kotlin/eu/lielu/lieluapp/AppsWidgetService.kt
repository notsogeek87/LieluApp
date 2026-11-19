package eu.lielu.lieluapp

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.os.Build
import android.util.TypedValue
import android.widget.RemoteViews
import android.widget.RemoteViewsService

/** Fournit les cases de la grille du widget. */
class AppsWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        AppsWidgetFactory(applicationContext)
}

class AppsWidgetFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private var apps: List<WidgetApp> = emptyList()
    private var iconDp: Int = HomeWidget.DEFAULT_ICON_DP
    private var iconPx: Int = SIZE
    private val icons = HashMap<String, Bitmap>()

    override fun onCreate() {}

    // Appelé hors du thread UI : on peut y lire les préférences et décoder les icônes.
    override fun onDataSetChanged() {
        apps = HomeWidget.load(context)
        iconDp = HomeWidget.iconDp(context)
        // Bitmap à la taille affichée (plafonnée pour rester légère à transmettre).
        val px = HomeWidget.dpToPx(context, iconDp.toFloat()).coerceIn(48, MAX_ICON_PX)
        if (px != iconPx) icons.clear()
        iconPx = px
        // Icônes préparées ici (hors thread UI) : getViewAt répond tout de suite et
        // le lanceur n'affiche pas de case « Chargement… » qui ferait clignoter la grille.
        val ids = apps.mapTo(HashSet()) { it.id }
        icons.keys.retainAll(ids)
        apps.forEach { icon(it) }
    }

    override fun onDestroy() {
        icons.clear()
    }

    override fun getCount(): Int = apps.size

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_app_item)
        val app = apps.getOrNull(position) ?: return views
        val installed = app.packageName != null &&
            context.packageManager.getLaunchIntentForPackage(app.packageName) != null
        val active = installed || app.url != null
        views.setTextViewText(R.id.app_name, app.name)
        views.setImageViewBitmap(R.id.app_icon, icon(app))
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            views.setViewLayoutWidth(R.id.app_icon, iconDp.toFloat(), TypedValue.COMPLEX_UNIT_DIP)
            views.setViewLayoutHeight(R.id.app_icon, iconDp.toFloat(), TypedValue.COMPLEX_UNIT_DIP)
        }
        views.setTextViewTextSize(
            R.id.app_name, TypedValue.COMPLEX_UNIT_SP, (iconDp * 0.2f).coerceIn(10f, 16f),
        )
        // Apps non installées en retrait : un appui ouvre leur fiche dans le store.
        views.setInt(R.id.app_icon, "setImageAlpha", if (active) 255 else 110)
        views.setTextColor(R.id.app_name, if (active) 0xF2FFFFFF.toInt() else 0x8CFFFFFF.toInt())
        views.setContentDescription(
            R.id.app_item,
            if (active) app.name else "${app.name} (non installée)",
        )
        views.setOnClickFillInIntent(
            R.id.app_item,
            Intent()
                .putExtra(WidgetLaunchActivity.EXTRA_ID, app.id)
                .putExtra(WidgetLaunchActivity.EXTRA_PACKAGE, app.packageName)
                .putExtra(WidgetLaunchActivity.EXTRA_URL, app.url),
        )
        return views
    }

    // Case vide transparente (et non le « Chargement… » par défaut d'Android).
    override fun getLoadingView(): RemoteViews = RemoteViews(context.packageName, R.layout.widget_app_item)
    override fun getViewTypeCount(): Int = 1
    // Identifiants stables : la grille réutilise ses cases au lieu de tout redessiner.
    override fun getItemId(position: Int): Long =
        apps.getOrNull(position)?.id?.hashCode()?.toLong() ?: position.toLong()
    override fun hasStableIds(): Boolean = true

    private fun icon(app: WidgetApp): Bitmap = icons.getOrPut(app.id) {
        WidgetIcons.icon(context, app, iconPx)
    }

    private companion object {
        const val SIZE = 128
        const val MAX_ICON_PX = 320
    }
}
