package eu.lielu.lieluapp

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BitmapShader
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
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
        iconPx = HomeWidget.dpToPx(context, iconDp.toFloat()).coerceIn(48, MAX_ICON_PX)
        icons.clear()
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

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = false

    // ------------------------------------------------------------- icônes

    private fun icon(app: WidgetApp): Bitmap = icons.getOrPut(app.id) {
        bundledIcon(app.id)?.let { rounded(it) } ?: installedIcon(app.packageName) ?: letterIcon(app)
    }

    /** Logo embarqué dans l'APK par Flutter (catalog/icons/<id>.png). */
    private fun bundledIcon(id: String): Bitmap? = try {
        context.assets.open("flutter_assets/catalog/icons/$id.png").use { input ->
            BitmapFactory.decodeStream(input)
        }
    } catch (_: Exception) {
        null
    }

    /** Icône de lanceur de l'app installée. */
    private fun installedIcon(pkg: String?): Bitmap? {
        if (pkg == null) return null
        return try {
            val drawable = context.packageManager.getApplicationIcon(pkg)
            val bmp = Bitmap.createBitmap(iconPx, iconPx, Bitmap.Config.ARGB_8888)
            drawable.setBounds(0, 0, iconPx, iconPx)
            drawable.draw(Canvas(bmp))
            bmp
        } catch (_: Exception) {
            null
        }
    }

    /** Coins arrondis comme dans le store (rayon de 26 %). */
    private fun rounded(src: Bitmap): Bitmap {
        val scaled = Bitmap.createScaledBitmap(src, iconPx, iconPx, true)
        val out = Bitmap.createBitmap(iconPx, iconPx, Bitmap.Config.ARGB_8888)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = BitmapShader(scaled, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP)
        }
        val r = iconPx * 0.26f
        Canvas(out).drawRoundRect(RectF(0f, 0f, iconPx.toFloat(), iconPx.toFloat()), r, r, paint)
        return out
    }

    /** Pastille colorée avec l'initiale, couleurs dérivées de l'identifiant (comme le store). */
    private fun letterIcon(app: WidgetApp): Bitmap {
        val (c1, c2) = PALETTES[app.id.sumOf { it.code } % PALETTES.size]
        val out = Bitmap.createBitmap(iconPx, iconPx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(out)
        val size = iconPx.toFloat()
        val bg = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = LinearGradient(0f, 0f, size, size, c1, c2, Shader.TileMode.CLAMP)
        }
        canvas.drawRoundRect(RectF(0f, 0f, size, size), size * 0.26f, size * 0.26f, bg)
        val text = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            textSize = size * 0.46f
            typeface = Typeface.DEFAULT_BOLD
            textAlign = Paint.Align.CENTER
        }
        val letter = app.name.firstOrNull()?.uppercase() ?: "?"
        val y = size / 2 - (text.descent() + text.ascent()) / 2
        canvas.drawText(letter, size / 2, y, text)
        return out
    }

    private companion object {
        const val SIZE = 128
        const val MAX_ICON_PX = 320
        val PALETTES = listOf(
            0xFF7B61FF.toInt() to 0xFF4F8CFF.toInt(),
            0xFFFF8A5B.toInt() to 0xFFFFC857.toInt(),
            0xFF3DDC97.toInt() to 0xFF2BB5C8.toInt(),
            0xFFFF6B9A.toInt() to 0xFF9B5DE5.toInt(),
            0xFF5B8DEF.toInt() to 0xFF38D6C4.toInt(),
        )
    }
}
