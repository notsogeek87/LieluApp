import 'dart:async';

import 'package:flutter/services.dart';

/// Application déjà présente sur le téléphone.
final class InstalledInfo {
  final String packageName;
  final String versionName;
  final int versionCode;

  /// SHA-256 (hex minuscule) des certificats de signature actuels et passés.
  final Set<String> signers;
  const InstalledInfo({
    required this.packageName,
    required this.versionName,
    required this.versionCode,
    required this.signers,
  });
}

/// Ce que dit un fichier APK, lu par Android sans l'installer.
final class ApkInspection {
  final String packageName;
  final String versionName;
  final int versionCode;
  final int minSdk;

  /// Certificats de signature de l'APK, historique de rotation compris
  /// (SHA-256 hex minuscule).
  final Set<String> signers;

  /// Certificats *actuels* seulement : ce qu'on compare à une empreinte épinglée.
  final Set<String> currentSigners;

  /// ABI des bibliothèques natives embarquées (vide = aucun code natif).
  final Set<String> abis;
  const ApkInspection({
    required this.packageName,
    required this.versionName,
    required this.versionCode,
    required this.minSdk,
    required this.signers,
    required this.abis,
    Set<String>? currentSigners,
  }) : currentSigners = currentSigners ?? signers;
}

final class DeviceInfo {
  final int sdkInt;
  final List<String> abis;
  const DeviceInfo(this.sdkInt, this.abis);
}

final class InstallResult {
  final bool ok;

  /// `cancelled`, `incompatible`, `conflict`, `storage`, `invalid`, `blocked`, `failure`.
  final String? code;
  final String? message;
  const InstallResult.success()
      : ok = true,
        code = null,
        message = null;
  const InstallResult.failure(this.code, [this.message]) : ok = false;
}

/// Pont vers les API Android (PackageManager / PackageInstaller).
abstract interface class StorePlatform {
  Future<DeviceInfo> deviceInfo();
  Future<Map<String, InstalledInfo>> installed(List<String> packages);
  Future<bool> launch(String packageName);
  Future<ApkInspection> inspectApk(String path);
  Future<bool> canInstallPackages();
  Future<void> openInstallSettings();

  /// Installe via PackageInstaller ; Android affiche sa propre confirmation.
  Future<InstallResult> install(String path, String packageName);
}

final class MethodChannelStorePlatform implements StorePlatform {
  static const _channel = MethodChannel('eu.lielu.lieluapp/store');
  final Map<String, void Function(InstallResult)> _pending = {};

  MethodChannelStorePlatform() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'installResult') {
        final a = Map<String, dynamic>.from(call.arguments as Map);
        final cb = _pending.remove(a['package']);
        if (cb != null) {
          cb(a['ok'] == true
              ? const InstallResult.success()
              : InstallResult.failure(a['code'] as String? ?? 'failure',
                  a['message'] as String?));
        }
      }
    });
  }

  @override
  Future<DeviceInfo> deviceInfo() async {
    final m = Map<String, dynamic>.from(
        await _channel.invokeMethod<Map>('deviceInfo') ?? const {});
    return DeviceInfo(
        m['sdkInt'] as int? ?? 0, List<String>.from(m['abis'] as List? ?? const []));
  }

  @override
  Future<Map<String, InstalledInfo>> installed(List<String> packages) async {
    final raw = await _channel.invokeMethod<Map>('installed', {'packages': packages});
    final out = <String, InstalledInfo>{};
    for (final e in (raw ?? const {}).entries) {
      final m = Map<String, dynamic>.from(e.value as Map);
      out[e.key as String] = InstalledInfo(
        packageName: e.key as String,
        versionName: m['versionName'] as String? ?? '',
        versionCode: (m['versionCode'] as num?)?.toInt() ?? 0,
        signers: Set<String>.from(m['signers'] as List? ?? const []),
      );
    }
    return out;
  }

  @override
  Future<bool> launch(String packageName) async =>
      await _channel.invokeMethod<bool>('launch', {'package': packageName}) ?? false;

  @override
  Future<ApkInspection> inspectApk(String path) async {
    final m = Map<String, dynamic>.from(
        await _channel.invokeMethod<Map>('inspectApk', {'path': path}) ?? const {});
    return ApkInspection(
      packageName: m['packageName'] as String? ?? '',
      versionName: m['versionName'] as String? ?? '',
      versionCode: (m['versionCode'] as num?)?.toInt() ?? 0,
      minSdk: (m['minSdk'] as num?)?.toInt() ?? 1,
      signers: Set<String>.from(m['signers'] as List? ?? const []),
      currentSigners: Set<String>.from(m['currentSigners'] as List? ?? m['signers'] as List? ?? const []),
      abis: Set<String>.from(m['abis'] as List? ?? const []),
    );
  }

  @override
  Future<bool> canInstallPackages() async =>
      await _channel.invokeMethod<bool>('canInstall') ?? false;

  @override
  Future<void> openInstallSettings() => _channel.invokeMethod('openInstallSettings');

  @override
  Future<InstallResult> install(String path, String packageName) async {
    final done = Completer<InstallResult>();
    _pending[packageName] = (r) {
      if (!done.isCompleted) done.complete(r);
    };
    try {
      await _channel.invokeMethod('install', {'path': path, 'package': packageName});
    } on PlatformException catch (e) {
      _pending.remove(packageName);
      return InstallResult.failure('failure', e.message);
    }
    return done.future;
  }
}
