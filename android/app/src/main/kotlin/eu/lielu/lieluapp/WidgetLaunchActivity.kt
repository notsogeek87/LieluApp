package eu.lielu.lieluapp

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle

/**
 * Relais invisible d'un appui sur une case du widget : ouvre l'app installée,
 * l'app web dans le navigateur, ou sinon la fiche de l'app dans le store.
 */
class WidgetLaunchActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            startActivity(target())
        } catch (_: Exception) {
            startActivity(storeIntent(intent.getStringExtra(EXTRA_ID)))
        }
        finish()
    }

    private fun target(): Intent {
        val id = intent.getStringExtra(EXTRA_ID)
        val pkg = intent.getStringExtra(EXTRA_PACKAGE)
        val url = intent.getStringExtra(EXTRA_URL)
        pkg?.let { packageManager.getLaunchIntentForPackage(it) }?.let {
            return it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        if (url != null && url.startsWith("https://")) {
            return Intent(Intent.ACTION_VIEW, Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        return storeIntent(id)
    }

    private fun storeIntent(id: String?): Intent =
        Intent(this, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            .apply { if (id != null) putExtra(MainActivity.EXTRA_OPEN_APP, id) }

    companion object {
        const val EXTRA_ID = "eu.lielu.lieluapp.widget.ID"
        const val EXTRA_PACKAGE = "eu.lielu.lieluapp.widget.PACKAGE"
        const val EXTRA_URL = "eu.lielu.lieluapp.widget.URL"
    }
}
