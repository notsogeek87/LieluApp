package eu.lielu.lieluapp

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterFragmentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Démarrage depuis une case du widget (app non installée) : Flutter demandera la fiche.
        if (savedInstanceState == null) {
            HomeWidget.setPendingLaunch(intent?.getStringExtra(EXTRA_OPEN_APP))
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        intent.getStringExtra(EXTRA_OPEN_APP)?.let(StoreChannel::emitWidgetLaunch)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ApkInstallerChannel.register(flutterEngine, this)
        StoreChannel.register(flutterEngine, this)
    }

    companion object {
        const val EXTRA_OPEN_APP = "eu.lielu.lieluapp.OPEN_APP"
    }
}
