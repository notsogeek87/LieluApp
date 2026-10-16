enum InstallPhase {
  downloading,
  verifying,
  needsPermission,
  awaitingConfirmation,
  installed,
  failed,
  cancelled;

  bool get active =>
      this == downloading ||
      this == verifying ||
      this == needsPermission ||
      this == awaitingConfirmation;
}

/// État d'une installation/mise à jour en cours ou récemment terminée.
final class InstallState {
  final String appId;
  final String appName;
  final String versionLabel;
  final InstallPhase phase;
  final int received;
  final int total;
  final String? message;

  /// Ce qui a effectivement été vérifié (à afficher tel quel).
  final String? integrityNote;
  final String? signatureNote;
  final DateTime at;

  const InstallState({
    required this.appId,
    required this.appName,
    required this.versionLabel,
    required this.phase,
    required this.at,
    this.received = 0,
    this.total = -1,
    this.message,
    this.integrityNote,
    this.signatureNote,
  });

  double? get progress => total > 0 ? (received / total).clamp(0.0, 1.0) : null;

  InstallState copyWith({
    InstallPhase? phase,
    int? received,
    int? total,
    String? message,
    String? integrityNote,
    String? signatureNote,
  }) =>
      InstallState(
        appId: appId,
        appName: appName,
        versionLabel: versionLabel,
        phase: phase ?? this.phase,
        at: DateTime.now(),
        received: received ?? this.received,
        total: total ?? this.total,
        message: message ?? this.message,
        integrityNote: integrityNote ?? this.integrityNote,
        signatureNote: signatureNote ?? this.signatureNote,
      );
}
