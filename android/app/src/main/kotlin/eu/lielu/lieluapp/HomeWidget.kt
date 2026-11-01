package eu.lielu.lieluapp

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import org.json.JSONArray

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

    /** Fiche demandée depuis le widget avant que Flutter ne soit prêt (démarrage à froid). */
    @Volatile
    private var pendingLaunch: String? = null

    fun setPendingLaunch(id: String?) {
        if (id != null) pendingLaunch = id
    }

    fun takePendingLaunch(): String? = pendingLaunch.also { pendingLaunch = null }

    fun save(context: Context, itemsJson: String) {
        JSONArray(itemsJson) // refuse un JSON invalide avant de l'enregistrer
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString(KEY_ITEMS, itemsJson).apply()
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
