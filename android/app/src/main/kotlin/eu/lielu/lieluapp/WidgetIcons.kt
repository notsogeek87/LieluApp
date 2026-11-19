package eu.lielu.lieluapp

import android.content.Context
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

/** Icônes des apps Lielu, partagées par la grille du widget et le lanceur déroulant. */
object WidgetIcons {

    /** Logo du store, sinon icône de l'app installée, sinon pastille avec l'initiale. */
    fun icon(context: Context, app: WidgetApp, px: Int): Bitmap =
        bundledIcon(context, app.id)?.let { rounded(it, px) }
            ?: installedIcon(context, app.packageName, px)
            ?: letterIcon(app, px)

    /** Logo embarqué dans l'APK par Flutter (catalog/icons/<id>.png). */
    private fun bundledIcon(context: Context, id: String): Bitmap? = try {
        context.assets.open("flutter_assets/catalog/icons/$id.png").use { input ->
            BitmapFactory.decodeStream(input)
        }
    } catch (_: Exception) {
        null
    }

    /** Icône de lanceur de l'app installée. */
    private fun installedIcon(context: Context, pkg: String?, px: Int): Bitmap? {
        if (pkg == null) return null
        return try {
            val drawable = context.packageManager.getApplicationIcon(pkg)
            val bmp = Bitmap.createBitmap(px, px, Bitmap.Config.ARGB_8888)
            drawable.setBounds(0, 0, px, px)
            drawable.draw(Canvas(bmp))
            bmp
        } catch (_: Exception) {
            null
        }
    }

    /** Coins arrondis comme dans le store (rayon de 26 %). */
    private fun rounded(src: Bitmap, px: Int): Bitmap {
        val scaled = Bitmap.createScaledBitmap(src, px, px, true)
        val out = Bitmap.createBitmap(px, px, Bitmap.Config.ARGB_8888)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = BitmapShader(scaled, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP)
        }
        val r = px * 0.26f
        Canvas(out).drawRoundRect(RectF(0f, 0f, px.toFloat(), px.toFloat()), r, r, paint)
        return out
    }

    /** Pastille colorée avec l'initiale, couleurs dérivées de l'identifiant (comme le store). */
    private fun letterIcon(app: WidgetApp, px: Int): Bitmap {
        val (c1, c2) = PALETTES[app.id.sumOf { it.code } % PALETTES.size]
        val out = Bitmap.createBitmap(px, px, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(out)
        val size = px.toFloat()
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

    private val PALETTES = listOf(
        0xFF7B61FF.toInt() to 0xFF4F8CFF.toInt(),
        0xFFFF8A5B.toInt() to 0xFFFFC857.toInt(),
        0xFF3DDC97.toInt() to 0xFF2BB5C8.toInt(),
        0xFFFF6B9A.toInt() to 0xFF9B5DE5.toInt(),
        0xFF5B8DEF.toInt() to 0xFF38D6C4.toInt(),
    )
}
