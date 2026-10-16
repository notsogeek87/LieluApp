import 'package:lieluapp/catalog/catalog_models.dart';
import 'package:lieluapp/platform/store_platform.dart';

/// Verdict de la vérification d'un APK téléchargé, avant toute installation.
final class VerifyResult {
  final String? error;

  /// Ce qui a *réellement* été comparé, pour l'afficher sans exagérer.
  final String signatureNote;
  const VerifyResult.ok(this.signatureNote) : error = null;
  const VerifyResult.rejected(this.error) : signatureNote = '';
  bool get ok => error == null;
}

/// Contrôles locaux de l'APK (lu par Android, pas par nous) :
/// bon paquet, compatible avec l'appareil, pas de rétrogradation, signature
/// cohérente avec l'app déjà installée.
VerifyResult verifyApk({
  required CatalogEntry entry,
  required ApkInspection apk,
  required DeviceInfo device,
  InstalledInfo? installed,
}) {
  if (apk.packageName != entry.packageName) {
    return VerifyResult.rejected(
        'Cet APK est celui de « ${apk.packageName} », pas de ${entry.name} '
        '(${entry.packageName}). Installation refusée.');
  }
  if (device.sdkInt > 0 && apk.minSdk > device.sdkInt) {
    return VerifyResult.rejected(
        '${entry.name} demande Android ${_androidName(apk.minSdk)} ou plus récent '
        '(ce téléphone : API ${device.sdkInt}).');
  }
  if (apk.abis.isNotEmpty &&
      device.abis.isNotEmpty &&
      !apk.abis.any(device.abis.contains)) {
    return VerifyResult.rejected(
        'Cet APK ne contient du code natif que pour ${apk.abis.join(', ')} ; '
        'ce téléphone utilise ${device.abis.join(', ')}.');
  }
  if (installed != null && apk.versionCode <= installed.versionCode) {
    return VerifyResult.rejected(
        'Cet APK (code ${apk.versionCode}) n\'est pas plus récent que la version '
        'installée (code ${installed.versionCode}). Android refuse les rétrogradations.');
  }

  final pinned = entry.signingCertSha256;
  if (pinned != null && !apk.currentSigners.contains(pinned)) {
    return const VerifyResult.rejected(
        'La signature de cet APK ne correspond pas à l\'empreinte attendue par le catalogue. '
        'Installation refusée.');
  }
  if (installed != null) {
    if (apk.signers.isEmpty || !apk.signers.any(installed.signers.contains)) {
      return VerifyResult.rejected(
          'Cet APK est signé avec une autre clé que ${entry.name} déjà installée : '
          'Android refuserait la mise à jour et vos données seraient perdues en cas de '
          'désinstallation. Rien n\'a été modifié.');
    }
    return const VerifyResult.ok('Signature identique à l\'application installée (vérifiée).');
  }
  if (pinned != null) {
    return const VerifyResult.ok('Signature conforme à l\'empreinte du catalogue (vérifiée).');
  }
  return const VerifyResult.ok(
      'Première installation : la signature n\'a pas pu être comparée à une version existante.');
}

String _androidName(int sdk) => switch (sdk) {
      24 => '7.0',
      25 => '7.1',
      26 => '8.0',
      27 => '8.1',
      28 => '9',
      29 => '10',
      30 => '11',
      31 => '12',
      32 => '12L',
      33 => '13',
      34 => '14',
      35 => '15',
      36 => '16',
      _ => '(API $sdk)',
    };
