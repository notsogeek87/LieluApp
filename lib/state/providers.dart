import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lieluapp/catalog/catalog_models.dart';
import 'package:lieluapp/catalog/catalog_repository.dart';
import 'package:lieluapp/install/apk_downloader.dart';
import 'package:lieluapp/install/install_models.dart';
import 'package:lieluapp/install/install_service.dart';
import 'package:lieluapp/platform/store_platform.dart';
import 'package:lieluapp/releases/github_client.dart';
import 'package:lieluapp/releases/release_models.dart';
import 'package:lieluapp/releases/release_repository.dart';
import 'package:lieluapp/state/app_view.dart';
import 'package:lieluapp/state/settings.dart';
import 'package:path_provider/path_provider.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    headers: {'User-Agent': 'LieluStore'},
  ));
  ref.onDispose(dio.close);
  return dio;
});

final platformProvider =
    Provider<StorePlatform>((ref) => MethodChannelStorePlatform());

final deviceInfoProvider = FutureProvider<DeviceInfo>((ref) async {
  try {
    return await ref.watch(platformProvider).deviceInfo();
  } on Object {
    return const DeviceInfo(0, []);
  }
});

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) =>
    CatalogRepository(ref.watch(dioProvider), ref.watch(sharedPrefsProvider)));

final releaseRepositoryProvider = Provider<ReleaseRepository>((ref) =>
    ReleaseRepository(GithubReleaseClient(ref.watch(dioProvider)),
        ref.watch(sharedPrefsProvider)));

// ---------------------------------------------------------------- catalogue

final class CatalogState {
  final List<CatalogEntry> entries;
  final List<String> issues;
  final String? error;
  final bool refreshing;
  final DateTime? fetchedAt;
  const CatalogState(this.entries,
      {this.issues = const [], this.error, this.refreshing = false, this.fetchedAt});

  CatalogState copyWith({
    List<CatalogEntry>? entries,
    List<String>? issues,
    String? error,
    bool clearError = false,
    bool? refreshing,
    DateTime? fetchedAt,
  }) =>
      CatalogState(
        entries ?? this.entries,
        issues: issues ?? this.issues,
        error: clearError ? null : error ?? this.error,
        refreshing: refreshing ?? this.refreshing,
        fetchedAt: fetchedAt ?? this.fetchedAt,
      );
}

final class CatalogNotifier extends AsyncNotifier<CatalogState> {
  @override
  Future<CatalogState> build() async {
    final repo = ref.read(catalogRepositoryProvider);
    final local = await repo.loadLocal();
    final initial = CatalogState(local.entries,
        issues: local.issues, fetchedAt: repo.lastFetch);
    final interval = ref.read(settingsProvider).refreshInterval;
    final last = repo.lastFetch;
    final due = interval != null &&
        (last == null || DateTime.now().difference(last) >= interval);
    if (due) Future.microtask(refresh);
    return initial;
  }

  /// Relit le catalogue distant. Les entrées en cache restent affichées si l'échec.
  Future<void> refresh() async {
    final current = state.value;
    if (current == null || current.refreshing) return;
    state = AsyncData(current.copyWith(refreshing: true, clearError: true));
    final repo = ref.read(catalogRepositoryProvider);
    final fresh = await repo.refresh();
    final base = state.value ?? current;
    state = AsyncData(fresh == null
        ? base.copyWith(refreshing: false, error: repo.lastError)
        : CatalogState(fresh.entries,
            issues: fresh.issues, fetchedAt: repo.lastFetch));
  }
}

final catalogProvider =
    AsyncNotifierProvider<CatalogNotifier, CatalogState>(CatalogNotifier.new);

// ----------------------------------------------------------------- releases

final class ReleasesState {
  final Map<String, ReleaseResult> results;
  final bool refreshing;
  final DateTime? lastCheck;
  const ReleasesState(this.results, {this.refreshing = false, this.lastCheck});

  ReleasesState copyWith(
          {Map<String, ReleaseResult>? results, bool? refreshing, DateTime? lastCheck}) =>
      ReleasesState(results ?? this.results,
          refreshing: refreshing ?? this.refreshing,
          lastCheck: lastCheck ?? this.lastCheck);
}

final class ReleasesNotifier extends AsyncNotifier<ReleasesState> {
  static const _lastCheckKey = 'releases.lastCheck';

  @override
  Future<ReleasesState> build() async {
    final entries = ref.watch(catalogProvider.select((c) => c.value?.entries)) ?? const [];
    final abis = (await ref.watch(deviceInfoProvider.future)).abis;
    final repo = ref.read(releaseRepositoryProvider);
    final prefs = ref.read(sharedPrefsProvider);
    final last = DateTime.tryParse(prefs.getString(_lastCheckKey) ?? '');
    final results = <String, ReleaseResult>{
      for (final e in entries)
        if (repo.cached(e, deviceAbis: abis) case final r?) e.id: r,
    };
    final interval = ref.read(settingsProvider).refreshInterval;
    final missing = entries.any((e) => !results.containsKey(e.id));
    final due = interval != null &&
        (last == null || DateTime.now().difference(last) >= interval);
    if (entries.isNotEmpty && (due || missing)) Future.microtask(() => refresh());
    return ReleasesState(results, lastCheck: last);
  }

  /// Interroge GitHub pour toutes les applications (4 requêtes en parallèle).
  Future<void> refresh() async {
    final current = state.value;
    if (current == null || current.refreshing) return;
    final entries = ref.read(catalogProvider).value?.entries ?? const <CatalogEntry>[];
    final abis = (await ref.read(deviceInfoProvider.future)).abis;
    final repo = ref.read(releaseRepositoryProvider);
    state = AsyncData(current.copyWith(refreshing: true));

    final results = Map<String, ReleaseResult>.of(current.results);
    final queue = List.of(entries);
    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final e = queue.removeLast();
        results[e.id] = await repo.refresh(e, deviceAbis: abis);
        state = AsyncData(
            (state.value ?? current).copyWith(results: Map.of(results), refreshing: true));
      }
    }

    await Future.wait(List.generate(4, (_) => worker()));
    final now = DateTime.now();
    await ref.read(sharedPrefsProvider).setString(_lastCheckKey, now.toUtc().toIso8601String());
    state = AsyncData(
        (state.value ?? current).copyWith(results: results, refreshing: false, lastCheck: now));
  }
}

final releasesProvider =
    AsyncNotifierProvider<ReleasesNotifier, ReleasesState>(ReleasesNotifier.new);

// ---------------------------------------------------- applications installées

final class InstalledNotifier extends AsyncNotifier<Map<String, InstalledInfo>> {
  @override
  Future<Map<String, InstalledInfo>> build() async {
    final entries = ref.watch(catalogProvider.select((c) => c.value?.entries)) ?? const [];
    return _read(entries);
  }

  Future<Map<String, InstalledInfo>> _read(List<CatalogEntry> entries) async {
    try {
      return await ref
          .read(platformProvider)
          .installed([for (final e in entries) e.packageName]);
    } on Object {
      return const {};
    }
  }

  Future<void> refresh() async {
    final entries = ref.read(catalogProvider).value?.entries ?? const <CatalogEntry>[];
    state = AsyncData(await _read(entries));
  }
}

final installedProvider =
    AsyncNotifierProvider<InstalledNotifier, Map<String, InstalledInfo>>(
        InstalledNotifier.new);

/// Dernier tag installé par le store, par packageName.
final class InstalledTagsNotifier extends Notifier<Map<String, String>> {
  static const _prefix = 'tag.';

  @override
  Map<String, String> build() {
    final p = ref.read(sharedPrefsProvider);
    return {
      for (final k in p.getKeys())
        if (k.startsWith(_prefix) && p.getString(k) != null)
          k.substring(_prefix.length): p.getString(k)!,
    };
  }

  Future<void> record(String packageName, String tag) async {
    state = {...state, packageName: tag};
    await ref.read(sharedPrefsProvider).setString('$_prefix$packageName', tag);
  }
}

final installedTagsProvider =
    NotifierProvider<InstalledTagsNotifier, Map<String, String>>(InstalledTagsNotifier.new);

// -------------------------------------------------------------- vue agrégée

final appViewsProvider = Provider<List<AppView>>((ref) {
  final entries = ref.watch(catalogProvider).value?.entries ?? const <CatalogEntry>[];
  final installed = ref.watch(installedProvider).value ?? const {};
  final releases = ref.watch(releasesProvider).value?.results ?? const {};
  final tags = ref.watch(installedTagsProvider);
  return [
    for (final e in entries)
      AppView(e,
          installed: installed[e.packageName],
          result: releases[e.id],
          trackedTag: tags[e.packageName]),
  ];
});

final updatesProvider = Provider<List<AppView>>(
    (ref) => ref.watch(appViewsProvider).where((a) => a.hasUpdate).toList());

// ------------------------------------------------------------ installations

final installServiceProvider = Provider<InstallService>((ref) {
  final downloader = ApkDownloader(ref.watch(dioProvider));
  return InstallService(
    platform: ref.watch(platformProvider),
    download: downloader.download,
    fetchText: downloader.fetchSmallText,
    workDir: () async {
      final base = await getTemporaryDirectory();
      return Directory('${base.path}/store_apks').create(recursive: true);
    },
    onInstalled: (entry, release) =>
        ref.read(installedTagsProvider.notifier).record(entry.packageName, release.tag),
  );
});

final class InstallController extends Notifier<Map<String, InstallState>> {
  final _tokens = <String, CancelToken>{};
  final _waitingForPermission = <String, (CatalogEntry, ReleaseInfo)>{};

  @override
  Map<String, InstallState> build() => {};

  bool isBusy(String id) {
    final p = state[id]?.phase;
    return p != null && p.active && p != InstallPhase.needsPermission;
  }

  Future<void> start(CatalogEntry entry, ReleaseInfo release) async {
    if (isBusy(entry.id)) return;
    final token = CancelToken();
    _tokens[entry.id] = token;
    _waitingForPermission.remove(entry.id);
    await ref.read(installServiceProvider).run(entry, release, token, (s) {
      state = {...state, entry.id: s};
      if (s.phase == InstallPhase.needsPermission) {
        _waitingForPermission[entry.id] = (entry, release);
      }
    });
    _tokens.remove(entry.id);
    await ref.read(installedProvider.notifier).refresh();
  }

  void cancel(String id) {
    _tokens[id]?.cancel();
    if (state[id]?.phase == InstallPhase.needsPermission) {
      _waitingForPermission.remove(id);
      state = {...state}..remove(id);
    }
  }

  void dismiss(String id) {
    if (isBusy(id)) return;
    state = {...state}..remove(id);
  }

  /// Au retour dans l'app : relit les apps installées et relance les
  /// installations qui attendaient l'autorisation système.
  Future<void> onResumed() async {
    await ref.read(installedProvider.notifier).refresh();
    if (_waitingForPermission.isEmpty) return;
    if (!await ref.read(platformProvider).canInstallPackages()) return;
    for (final (entry, release) in List.of(_waitingForPermission.values)) {
      unawaited(start(entry, release));
    }
  }
}

final installControllerProvider =
    NotifierProvider<InstallController, Map<String, InstallState>>(InstallController.new);
