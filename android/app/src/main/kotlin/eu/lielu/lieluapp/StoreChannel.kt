package eu.lielu.lieluapp

import android.content.Context
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageInstaller
import android.content.pm.PackageManager
import android.content.pm.Signature
import android.app.PendingIntent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest
import java.util.zip.ZipFile

/**
 * Pont Flutter ↔ Android pour le store : applications installées, lecture d'un APK
 * sans l'installer, lancement d'une app et installation par PackageInstaller.
 *
 * Aucune installation silencieuse : Android demande toujours sa confirmation.
 */
object StoreChannel {
    private const val CHANNEL = "eu.lielu.lieluapp/store"
    private const val ACTION_RESULT = "eu.lielu.lieluapp.INSTALL_RESULT"
    const val EXTRA_PACKAGE = "eu.lielu.lieluapp.EXTRA_PACKAGE"

    private var channel: MethodChannel? = null
    private val main = Handler(Looper.getMainLooper())

    fun register(engine: FlutterEngine, context: Context) {
        val app = context.applicationContext
        val ch = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        channel = ch
        ch.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "deviceInfo" -> result.success(
                        mapOf(
                            "sdkInt" to Build.VERSION.SDK_INT,
                            "abis" to Build.SUPPORTED_ABIS.toList(),
                        )
                    )
                    "installed" -> {
                        val packages = call.argument<List<String>>("packages") ?: emptyList()
                        result.success(installed(app, packages))
                    }
                    "launch" -> {
                        val pkg = call.argument<String>("package")
                        val intent = pkg?.let { app.packageManager.getLaunchIntentForPackage(it) }
                        if (intent == null) {
                            result.success(false)
                        } else {
                            app.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                            result.success(true)
                        }
                    }
                    "inspectApk" -> {
                        val path = call.argument<String>("path")
                        val info = path?.let { inspectApk(app, it) }
                        if (info == null) result.error("INVALID_APK", "APK illisible", null)
                        else result.success(info)
                    }
                    "canInstall" -> result.success(
                        Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
                            app.packageManager.canRequestPackageInstalls()
                    )
                    "openInstallSettings" -> {
                        app.startActivity(
                            Intent(
                                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                Uri.parse("package:${app.packageName}")
                            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        )
                        result.success(null)
                    }
                    "install" -> {
                        val path = call.argument<String>("path")
                        val pkg = call.argument<String>("package")
                        if (path == null || pkg == null) {
                            result.error("ARG", "path/package manquant", null)
                        } else {
                            // La copie de l'APK dans la session peut être longue : hors thread UI.
                            Thread {
                                try {
                                    commit(app, File(path), pkg)
                                    main.post { result.success(null) }
                                } catch (e: Exception) {
                                    main.post { result.error("INSTALL", e.message, null) }
                                }
                            }.start()
                        }
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("STORE", e.message, null)
            }
        }
    }

    /** Renvoie à Dart le verdict d'une session d'installation. */
    fun emitInstallResult(pkg: String, ok: Boolean, code: String?, message: String?) {
        main.post {
            channel?.invokeMethod(
                "installResult",
                mapOf("package" to pkg, "ok" to ok, "code" to code, "message" to message)
            )
        }
    }

    // ------------------------------------------------------------ lecture

    private fun signingFlag(): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) PackageManager.GET_SIGNING_CERTIFICATES
        else @Suppress("DEPRECATION") PackageManager.GET_SIGNATURES

    private fun sha256(bytes: ByteArray): String =
        MessageDigest.getInstance("SHA-256").digest(bytes).joinToString("") { "%02x".format(it) }

    /** Certificats actuels du paquet (SHA-256 hex). */
    private fun currentSigners(info: PackageInfo): List<String> {
        val sigs: Array<Signature>? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.signingInfo?.apkContentsSigners
        } else {
            @Suppress("DEPRECATION") info.signatures
        }
        return sigs?.map { sha256(it.toByteArray()) } ?: emptyList()
    }

    /** Certificats actuels + anciens (rotation de clé) du paquet. */
    private fun allSigners(info: PackageInfo): List<String> {
        val current = currentSigners(info)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return current
        val si = info.signingInfo ?: return current
        val history =
            if (si.hasMultipleSigners()) emptyList()
            else si.signingCertificateHistory?.map { sha256(it.toByteArray()) } ?: emptyList()
        return (current + history).distinct()
    }

    private fun versionCode(info: PackageInfo): Long =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) info.longVersionCode
        else @Suppress("DEPRECATION") info.versionCode.toLong()

    private fun installed(context: Context, packages: List<String>): Map<String, Map<String, Any?>> {
        val pm = context.packageManager
        val out = HashMap<String, Map<String, Any?>>()
        for (pkg in packages) {
            try {
                val info = if (Build.VERSION.SDK_INT >= 33) {
                    pm.getPackageInfo(pkg, PackageManager.PackageInfoFlags.of(signingFlag().toLong()))
                } else {
                    @Suppress("DEPRECATION") pm.getPackageInfo(pkg, signingFlag())
                }
                out[pkg] = mapOf(
                    "versionName" to (info.versionName ?: ""),
                    "versionCode" to versionCode(info),
                    "signers" to allSigners(info),
                )
            } catch (_: PackageManager.NameNotFoundException) {
                // Non installée (ou invisible : voir <queries> dans le manifeste).
            }
        }
        return out
    }

    private fun inspectApk(context: Context, path: String): Map<String, Any?>? {
        val pm = context.packageManager
        val info = if (Build.VERSION.SDK_INT >= 33) {
            pm.getPackageArchiveInfo(path, PackageManager.PackageInfoFlags.of(signingFlag().toLong()))
        } else {
            @Suppress("DEPRECATION") pm.getPackageArchiveInfo(path, signingFlag())
        } ?: return null
        return mapOf(
            "packageName" to info.packageName,
            "versionName" to (info.versionName ?: ""),
            "versionCode" to versionCode(info),
            "minSdk" to (info.applicationInfo?.minSdkVersion ?: 1),
            "signers" to allSigners(info),
            "currentSigners" to currentSigners(info),
            "abis" to nativeAbis(path),
        )
    }

    /** ABI des bibliothèques natives embarquées (dossiers lib/<abi>/ de l'APK). */
    private fun nativeAbis(path: String): List<String> = try {
        ZipFile(path).use { zip ->
            zip.entries().asSequence()
                .map { it.name }
                .filter { it.startsWith("lib/") && it.count { c -> c == '/' } >= 2 }
                .map { it.split('/')[1] }
                .distinct()
                .toList()
        }
    } catch (_: Exception) {
        emptyList()
    }

    // --------------------------------------------------------- installation

    private fun commit(context: Context, apk: File, pkg: String) {
        val installer = context.packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
        params.setAppPackageName(pkg)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Pas de confirmation inutile pour une mise à jour quand Android l'autorise.
            params.setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_NOT_REQUIRED)
        }
        val id = installer.createSession(params)
        installer.openSession(id).use { session ->
            apk.inputStream().use { input ->
                session.openWrite("base.apk", 0, apk.length()).use { out ->
                    input.copyTo(out)
                    session.fsync(out)
                }
            }
            val intent = Intent(context, InstallResultReceiver::class.java)
                .setAction(ACTION_RESULT)
                .putExtra(EXTRA_PACKAGE, pkg)
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0)
            val pending = PendingIntent.getBroadcast(context, id, intent, flags)
            session.commit(pending.intentSender)
        }
    }
}
