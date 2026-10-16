import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:lieluapp/platform/store_platform.dart';

/// Dio sans réseau : [handler] fabrique la réponse pour chaque requête.
final class FakeAdapter implements HttpClientAdapter {
  final ResponseBody Function(RequestOptions) handler;
  final requests = <RequestOptions>[];
  FakeAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream,
      Future<void>? cancelFuture) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

Dio fakeDio(ResponseBody Function(RequestOptions) handler) =>
    Dio()..httpClientAdapter = FakeAdapter(handler);

ResponseBody text(String body, int status, {Map<String, List<String>>? headers}) =>
    ResponseBody.fromString(body, status,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
          ...?headers,
        });

ResponseBody bytes(List<int> data, int status, {Map<String, List<String>>? headers}) =>
    ResponseBody.fromBytes(data, status, headers: headers);

ResponseBody redirect(String location) =>
    ResponseBody.fromString('', 302, headers: {'location': [location]});

String releasesJson(List<Map<String, dynamic>> releases) => jsonEncode(releases);

/// Faux pont Android, entièrement configurable.
final class FakePlatform implements StorePlatform {
  DeviceInfo device = const DeviceInfo(34, ['arm64-v8a', 'armeabi-v7a']);
  Map<String, InstalledInfo> installedApps = {};
  bool canInstall = true;
  ApkInspection? inspection;
  Object? inspectError;
  InstallResult installResult = const InstallResult.success();
  final installCalls = <String>[];

  @override
  Future<DeviceInfo> deviceInfo() async => device;
  @override
  Future<Map<String, InstalledInfo>> installed(List<String> packages) async =>
      {for (final p in packages) if (installedApps[p] != null) p: installedApps[p]!};
  @override
  Future<bool> launch(String packageName) async => true;
  @override
  Future<ApkInspection> inspectApk(String path) async {
    if (inspectError != null) throw inspectError!;
    return inspection!;
  }

  @override
  Future<bool> canInstallPackages() async => canInstall;
  @override
  Future<void> openInstallSettings() async {}
  @override
  Future<InstallResult> install(String path, String packageName) async {
    installCalls.add(path);
    return installResult;
  }
}
