package eu.lielu.lieluapp

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.os.Build

/** Reçoit le verdict de PackageInstaller et le transmet à l'interface Flutter. */
class InstallResultReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val pkg = intent.getStringExtra(StoreChannel.EXTRA_PACKAGE) ?: return
        val message = intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE)
        when (intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)) {
            PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                // Android demande sa confirmation : on affiche sa fenêtre, rien de plus.
                val confirm = if (Build.VERSION.SDK_INT >= 33) {
                    intent.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)
                } else {
                    @Suppress("DEPRECATION") intent.getParcelableExtra(Intent.EXTRA_INTENT)
                }
                if (confirm != null) {
                    confirm.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(confirm)
                } else {
                    StoreChannel.emitInstallResult(pkg, false, "failure", message)
                }
            }
            PackageInstaller.STATUS_SUCCESS -> StoreChannel.emitInstallResult(pkg, true, null, null)
            PackageInstaller.STATUS_FAILURE_ABORTED ->
                StoreChannel.emitInstallResult(pkg, false, "cancelled", message)
            PackageInstaller.STATUS_FAILURE_INCOMPATIBLE ->
                StoreChannel.emitInstallResult(pkg, false, "incompatible", message)
            PackageInstaller.STATUS_FAILURE_CONFLICT ->
                StoreChannel.emitInstallResult(pkg, false, "conflict", message)
            PackageInstaller.STATUS_FAILURE_STORAGE ->
                StoreChannel.emitInstallResult(pkg, false, "storage", message)
            PackageInstaller.STATUS_FAILURE_INVALID ->
                StoreChannel.emitInstallResult(pkg, false, "invalid", message)
            PackageInstaller.STATUS_FAILURE_BLOCKED ->
                StoreChannel.emitInstallResult(pkg, false, "blocked", message)
            else -> StoreChannel.emitInstallResult(pkg, false, "failure", message)
        }
    }
}
