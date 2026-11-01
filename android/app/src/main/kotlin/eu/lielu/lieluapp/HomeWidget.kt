package eu.lielu.lieluapp

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/** Une application affichée par le widget d'écran d'accueil. */
data class WidgetApp(
    val id: String,
    val name: String,
    /** applicationId Android ; null pour une application web. */
    val packageName: String?,
    /** Adresse HTTPS d'une application web. */
    val url: String?,
)

/**
 * Stockage de la liste (déjà ordonnée par l'utilisateur dans le store) et
 * rafraîchissement des widgets posés sur l'écran d'accueil.
 */
object HomeWidget {
    private const val PREFS = "lielu_home_widget"
    private const val KEY_ITEMS = "items"
    private const val KEY_SIZE = "size"
    private const val KEY_VERSION = "version"

    /** Fiche demandée depuis le widget avant que Flutter ne soit prêt (démarrage à froid). */
    @Volatile
    private var pendingLaunch: String? = null

    fun setPendingLaunch(id: String?) {
        if (id != null) pendingLaunch = id
    }

    fun takePendingLaunch(): String? = pendingLaunch.also { pendingLaunch = null }

    /**
     * Enregistre les données envoyées par le store : `{"size": "...", "items": [...]}`
     * (un simple tableau reste accepté). Chaque envoi incrémente une version qui
     * force le widget à relire la liste, même si le lanceur garde l'ancienne en cache.
     */
    fun save(context: Context, payload: String) {
        val trimmed = payload.trim()
        val items: JSONArray
        var size = "medium"
        if (trimmed.startsWith("{")) {
            val o = JSONObject(trimmed)
            items = o.optJSONArray("items") ?: JSONArray()
            size = o.optString("size", "medium")
        } else {
            items = JSONArray(trimmed)
        }
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.edit()
            .putString(KEY_ITEMS, items.toString())
            .putString(KEY_SIZE, size)
            .putLong(KEY_VERSION, prefs.getLong(KEY_VERSION, 0) + 1)
            // commit (synchrone) : le widget relit ces valeurs juste après.
            .commit()
    }

    fun size(context: Context): String =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY_SIZE, "medium")
            ?: "medium"

    fun version(context: Context): Long =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getLong(KEY_VERSION, 0)

    /** Gabarit du widget selon la taille choisie. */
    fun widgetLayout(context: Context): Int = when (size(context)) {
        "small" -> R.layout.widget_apps_small
        "large" -> R.layout.widget_apps_large
        else -> R.layout.widget_apps
    }

    /** Gabarit d'une case selon la taille choisie. */
    fun itemLayout(context: Context): Int = when (size(context)) {
        "small" -> R.layout.widget_app_item_small
        "large" -> R.layout.widget_app_item_large
        else -> R.layout.widget_app_item
    }

    fun load(context: Context): List<WidgetApp> {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_ITEMS, null) ?: return emptyList()
        return try {
            val array = JSONArray(raw)
            (0 until array.length()).mapNotNull { i ->
                val o = array.optJSONObject(i) ?: return@mapNotNull null
                val id = o.optString("id").takeIf { it.isNotEmpty() } ?: return@mapNotNull null
                WidgetApp(
                    id = id,
                    name = o.optString("name", id),
                    packageName = o.optString("packageName").takeIf { it.isNotEmpty() },
                    url = o.optString("url").takeIf { it.startsWith("https://") },
                )
            }
        } catch (_: Exception) {
            emptyList()
        }
    }

    /** Redessine tous les widgets posés (cadre + grille). */
    fun refresh(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, AppsWidgetProvider::class.java))
        if (ids.isEmpty()) return
        AppsWidgetProvider.updateAll(context, manager, ids)
        @Suppress("DEPRECATION")
        manager.notifyAppWidgetViewDataChanged(ids, R.id.widget_grid)
    }
}
