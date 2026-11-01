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
    private const val KEY_ICON_DP = "iconDp"
    private const val KEY_TRANSPARENCY = "transparency"
    private const val KEY_VERSION = "version"

    /** Fiche demandée depuis le widget avant que Flutter ne soit prêt (démarrage à froid). */
    @Volatile
    private var pendingLaunch: String? = null

    fun setPendingLaunch(id: String?) {
        if (id != null) pendingLaunch = id
    }

    fun takePendingLaunch(): String? = pendingLaunch.also { pendingLaunch = null }

    /** Jeton transmis au store pour ouvrir le réglage du widget. */
    const val SETTINGS_TOKEN = "::widget-settings"

    const val DEFAULT_ICON_DP = 56
    const val DEFAULT_TRANSPARENCY = 10

    /**
     * Enregistre les données envoyées par le store : `{"iconDp": 56, "items": [...]}`
     * (un simple tableau reste accepté). Chaque envoi incrémente une version qui
     * force le widget à relire la liste, même si le lanceur garde l'ancienne en cache.
     */
    fun save(context: Context, payload: String) {
        val trimmed = payload.trim()
        val items: JSONArray
        var iconDp = DEFAULT_ICON_DP
        var transparency = DEFAULT_TRANSPARENCY
        if (trimmed.startsWith("{")) {
            val o = JSONObject(trimmed)
            items = o.optJSONArray("items") ?: JSONArray()
            transparency = o.optInt("transparency", DEFAULT_TRANSPARENCY)
            iconDp = when {
                o.has("iconDp") -> o.optInt("iconDp", DEFAULT_ICON_DP)
                o.optString("size") == "small" -> 40
                o.optString("size") == "large" -> 80
                else -> DEFAULT_ICON_DP
            }
        } else {
            items = JSONArray(trimmed)
        }
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.edit()
            .putString(KEY_ITEMS, items.toString())
            .putInt(KEY_ICON_DP, iconDp.coerceIn(24, 160))
            .putInt(KEY_TRANSPARENCY, transparency.coerceIn(0, 100))
            .putLong(KEY_VERSION, prefs.getLong(KEY_VERSION, 0) + 1)
            // commit (synchrone) : le widget relit ces valeurs juste après.
            .commit()
    }

    /** Taille des icônes choisie dans le store, en dp. */
    fun iconDp(context: Context): Int =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getInt(KEY_ICON_DP, DEFAULT_ICON_DP)

    /** Opacité du fond (0 à 255) d'après la transparence choisie dans le store. */
    fun backgroundAlpha(context: Context): Int {
        val t = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getInt(KEY_TRANSPARENCY, DEFAULT_TRANSPARENCY)
        return ((100 - t) * 255 + 50) / 100
    }

    fun version(context: Context): Long =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getLong(KEY_VERSION, 0)

    fun dpToPx(context: Context, dp: Float): Int =
        (dp * context.resources.displayMetrics.density + 0.5f).toInt()

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
