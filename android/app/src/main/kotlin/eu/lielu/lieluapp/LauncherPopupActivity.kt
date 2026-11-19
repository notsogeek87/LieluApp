package eu.lielu.lieluapp

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.app.Activity
import android.content.Intent
import android.graphics.Rect
import android.os.Bundle
import android.text.TextUtils
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.ViewTreeObserver
import android.view.animation.AccelerateInterpolator
import android.view.animation.DecelerateInterpolator
import android.view.animation.OvershootInterpolator
import android.widget.FrameLayout
import android.widget.GridLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min

/**
 * Lanceur déroulant du widget « Lanceur Lielu » : sans assombrir l'écran, les icônes
 * des apps Lielu jaillissent du bouton pour se ranger dans un panneau. Un appui sur
 * une icône ouvre l'app (même logique que la grille du widget), un appui ailleurs
 * ou « retour » referme le panneau en ramenant les icônes vers le bouton.
 */
class LauncherPopupActivity : Activity() {

    private lateinit var root: FrameLayout
    private lateinit var panel: FrameLayout
    private lateinit var scroll: ScrollView
    private val cells = ArrayList<View>()
    private var anchor: Rect? = null
    private var closing = false
    private var fromRight = true
    private var fromBottom = true

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        anchor = intent.sourceBounds
        val apps = HomeWidget.load(this)
        if (apps.isEmpty()) {
            // Rien à montrer tant que le store n'a pas envoyé la liste : on l'ouvre.
            startActivity(Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            finishQuietly()
            return
        }
        setContentView(buildViews(apps))
        root.viewTreeObserver.addOnPreDrawListener(object : ViewTreeObserver.OnPreDrawListener {
            override fun onPreDraw(): Boolean {
                root.viewTreeObserver.removeOnPreDrawListener(this)
                // Les icônes peuvent sortir du panneau pendant l'animation, sauf si la
                // liste défile (sinon le contenu masqué déborderait du panneau).
                val grid = scroll.getChildAt(0)
                scroll.clipChildren = grid.height > scroll.height
                // Liste trop longue : on montre d'abord le côté du bouton (premières apps).
                if (fromBottom && grid.height > scroll.height) scroll.scrollTo(0, grid.height)
                placePanel()
                animateOpen()
                return true
            }
        })
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Nouvel appui sur le bouton pendant que le panneau est ouvert : on le referme.
        close()
    }

    // Retour à l'accueil (bouton Accueil, autre app) : le panneau ne doit pas réapparaître.
    override fun onStop() {
        super.onStop()
        if (!isFinishing) finishQuietly()
    }

    @Deprecated("Toujours appelé sans OnBackInvokedCallback déclaré")
    override fun onBackPressed() = close()

    // ------------------------------------------------------------- vues

    private fun dp(v: Float): Int = HomeWidget.dpToPx(this, v)

    private fun buildViews(apps: List<WidgetApp>): View {
        val iconPx = dp(ICON_DP)
        val metrics = resources.displayMetrics
        fromRight = anchor?.let { it.centerX() > metrics.widthPixels / 2 } ?: true
        fromBottom = anchor?.let { it.centerY() > metrics.heightPixels / 2 } ?: true
        // Colonnes : 4 au plus, moins si l'écran est étroit ou s'il y a peu d'apps.
        val fit = (resources.displayMetrics.widthPixels - 2 * dp(MARGIN_DP) - dp(24f)) / dp(CELL_DP)
        val columns = min(apps.size, fit.coerceIn(1, MAX_COLUMNS))
        val rows = (apps.size + columns - 1) / columns
        val grid = GridLayout(this).apply {
            columnCount = columns
            rowCount = rows
            useDefaultMargins = false
        }
        // Pratique au pouce : les premières apps sont au plus près du bouton, puis
        // la grille s'en éloigne (rangées vers le haut si le bouton est en bas,
        // colonnes vers la gauche s'il est à droite).
        apps.forEachIndexed { i, app ->
            val cell = cell(app, iconPx)
            val r = i / columns
            val c = i % columns
            val row = if (fromBottom) rows - 1 - r else r
            val col = if (fromRight) columns - 1 - c else c
            grid.addView(
                cell,
                GridLayout.LayoutParams(GridLayout.spec(row), GridLayout.spec(col)).apply { width = dp(CELL_DP) },
            )
            cells += cell
        }
        scroll = ScrollView(this).apply {
            isVerticalScrollBarEnabled = false
            overScrollMode = View.OVER_SCROLL_NEVER
            clipChildren = false
            clipToPadding = false
            addView(grid)
        }
        panel = FrameLayout(this).apply {
            setBackgroundResource(R.drawable.launcher_panel_background)
            setPadding(dp(8f), dp(10f), dp(8f), dp(6f))
            elevation = dp(12f).toFloat()
            isClickable = true // un appui entre deux icônes ne ferme pas le panneau
            clipChildren = false
            alpha = 0f
            addView(scroll, FrameLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        }
        // Pas de voile : l'écran d'accueil reste tel quel autour du panneau.
        root = FrameLayout(this).apply {
            clipChildren = false
            setOnClickListener { close() }
            addView(
                panel,
                FrameLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                    gravity = Gravity.TOP or Gravity.START
                    setMargins(dp(MARGIN_DP), dp(TOP_MARGIN_DP), dp(MARGIN_DP), dp(TOP_MARGIN_DP))
                },
            )
        }
        return root
    }

    private fun cell(app: WidgetApp, iconPx: Int): View {
        val installed = app.packageName != null &&
            packageManager.getLaunchIntentForPackage(app.packageName) != null
        val active = installed || app.url != null
        return LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(2f), dp(6f), dp(2f), dp(8f))
            isClickable = true
            isFocusable = true
            contentDescription = if (active) app.name else getString(R.string.launcher_not_installed, app.name)
            setOnClickListener { launch(app, this) }
            addView(
                ImageView(this@LauncherPopupActivity).apply {
                    setImageBitmap(WidgetIcons.icon(this@LauncherPopupActivity, app, iconPx))
                    imageAlpha = if (active) 255 else 110
                    elevation = dp(3f).toFloat()
                },
                LinearLayout.LayoutParams(iconPx, iconPx),
            )
            addView(
                TextView(this@LauncherPopupActivity).apply {
                    text = app.name
                    textSize = 11f
                    setTextColor(if (active) 0xF2FFFFFF.toInt() else 0x8CFFFFFF.toInt())
                    gravity = Gravity.CENTER
                    maxLines = 1
                    ellipsize = TextUtils.TruncateAt.END
                },
                LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
                    .apply { topMargin = dp(4f) },
            )
        }
    }

    // ------------------------------------------------------------- placement

    /** Centre du bouton dans le repère de [root] (ou centre de l'écran à défaut). */
    private fun anchorInRoot(): Pair<Float, Float> {
        val a = anchor ?: return root.width / 2f to root.height / 2f
        val loc = IntArray(2).also(root::getLocationOnScreen)
        return (a.exactCenterX() - loc[0]) to (a.exactCenterY() - loc[1])
    }

    /**
     * Panneau collé au bouton : au-dessus s'il est en bas de l'écran (sinon en dessous),
     * aligné sur son bord droit s'il est à droite (sinon sur son bord gauche).
     */
    private fun placePanel() {
        val (ax, ay) = anchorInRoot()
        val w = panel.width
        val h = panel.height
        val margin = dp(MARGIN_DP).toFloat()
        val top = dp(TOP_MARGIN_DP).toFloat()
        val gap = dp(8f).toFloat()
        val half = (anchor?.width() ?: 0) / 2f
        val halfH = (anchor?.height() ?: 0) / 2f
        val x = when {
            anchor == null -> (root.width - w) / 2f
            fromRight -> ax + half - w
            else -> ax - half
        }.coerceIn(margin, max(margin, root.width - w - margin))
        val y = when {
            anchor == null -> (root.height - h) / 2f
            fromBottom -> ay - halfH - gap - h
            else -> ay + halfH + gap
        }.coerceIn(top, max(top, root.height - h - top))
        // Les marges du FrameLayout ont déjà décalé le panneau : on les compense.
        panel.translationX = x - panel.left
        panel.translationY = y - panel.top
        // Le panneau grandit depuis le bouton.
        panel.pivotX = (ax - x).coerceIn(0f, w.toFloat())
        panel.pivotY = (ay - y).coerceIn(0f, h.toFloat())
    }

    /** Décalage qui ramène le centre d'une case sur le bouton. */
    private fun offsetToAnchor(cell: View): Pair<Float, Float> {
        val (ax, ay) = anchorInRoot()
        val loc = IntArray(2).also(cell::getLocationOnScreen)
        val rootLoc = IntArray(2).also(root::getLocationOnScreen)
        val cx = loc[0] - rootLoc[0] + cell.width / 2f
        val cy = loc[1] - rootLoc[1] + cell.height / 2f
        return (ax - cx) to (ay - cy)
    }

    // ------------------------------------------------------------- animations

    private fun animateOpen() {
        // Les icônes partent du bouton, les plus proches d'abord, avec un léger rebond.
        // (Décalages mesurés avant de rétrécir le panneau, qui fausserait les positions.)
        val maxDist = cells.maxOf { c ->
            val (dx, dy) = offsetToAnchor(c); hypot(dx, dy)
        }.coerceAtLeast(1f)
        cells.forEach { c ->
            val (dx, dy) = offsetToAnchor(c)
            val dist = hypot(dx, dy)
            c.translationX = dx
            c.translationY = dy
            c.scaleX = 0.2f
            c.scaleY = 0.2f
            c.alpha = 0f
            c.animate()
                .translationX(0f).translationY(0f).scaleX(1f).scaleY(1f).alpha(1f)
                .setStartDelay((60 + 160 * dist / maxDist).toLong())
                .setDuration(420)
                .setInterpolator(OvershootInterpolator(1.2f))
                .start()
        }
        panel.scaleX = 0.4f
        panel.scaleY = 0.4f
        panel.animate().alpha(1f).scaleX(1f).scaleY(1f)
            .setDuration(300).setInterpolator(DecelerateInterpolator(2f)).start()
    }

    /** Referme : les icônes rentrent dans le bouton et le panneau se replie. */
    private fun close() {
        if (closing) return
        closing = true
        root.isClickable = false
        cells.forEach { c ->
            val (dx, dy) = offsetToAnchor(c)
            c.animate().cancel()
            c.animate()
                .translationX(c.translationX + dx).translationY(c.translationY + dy)
                .scaleX(0.2f).scaleY(0.2f).alpha(0f)
                .setStartDelay(0).setDuration(200)
                .setInterpolator(AccelerateInterpolator(1.5f))
                .start()
        }
        panel.animate().cancel()
        panel.animate().alpha(0f).scaleX(0.4f).scaleY(0.4f)
            .setStartDelay(40).setDuration(200).setInterpolator(AccelerateInterpolator(1.5f))
            .setListener(object : AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: Animator) = finishQuietly()
            })
            .start()
    }

    /** Petit enfoncement de l'icône, puis ouverture de l'app (via le relais du widget). */
    private fun launch(app: WidgetApp, cell: View) {
        if (closing) return
        closing = true
        cell.animate().cancel()
        cell.animate().scaleX(0.88f).scaleY(0.88f).setStartDelay(0).setDuration(90)
            .withEndAction {
                startActivity(
                    Intent(this, WidgetLaunchActivity::class.java)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        .putExtra(WidgetLaunchActivity.EXTRA_ID, app.id)
                        .putExtra(WidgetLaunchActivity.EXTRA_PACKAGE, app.packageName)
                        .putExtra(WidgetLaunchActivity.EXTRA_URL, app.url),
                )
                finishQuietly()
            }
            .start()
    }

    @Suppress("DEPRECATION")
    private fun finishQuietly() {
        if (isFinishing) return
        finish()
        overridePendingTransition(0, 0)
    }

    private companion object {
        const val ICON_DP = 48f
        const val CELL_DP = 70f
        const val MAX_COLUMNS = 4
        const val MARGIN_DP = 8f
        const val TOP_MARGIN_DP = 16f
    }
}
