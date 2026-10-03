import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

import '../config.dart';

class AppVersionInfo {
  final int versionCode;
  final String versionName;
  final String apkUrl;
  final String? changelog;
  final bool forceUpdate;

  AppVersionInfo({
    required this.versionCode,
    required this.versionName,
    required this.apkUrl,
    this.changelog,
    required this.forceUpdate,
  });

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    return AppVersionInfo(
      versionCode: json["version_code"] as int,
      versionName: json["version_name"] as String,
      apkUrl: json["apk_url"] as String,
      changelog: json["changelog"] as String?,
      forceUpdate: json["force_update"] as bool? ?? false,
    );
  }
}

class UpdateService {
  // Nombre de esta app tal como esta registrado en el backend.
  static const String _appName = "pasajero";

  // Consulta el backend y devuelve la info de la ultima version SOLO si
  // es mas nueva que la instalada. Si ya esta actualizada o hay un error
  // de red, devuelve null -- nunca interrumpe el uso normal de la app por
  // un problema al chequear actualizaciones.
  Future<AppVersionInfo?> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersionCode = int.tryParse(packageInfo.buildNumber) ?? 0;

      final res = await http
          .get(Uri.parse("${AppConfig.apiBaseUrl}/app-version/$_appName"))
          .timeout(const Duration(seconds: 8));

      if (res.statusCode != 200) return null;

      final info = AppVersionInfo.fromJson(jsonDecode(res.body));
      if (info.versionCode > currentVersionCode) return info;
      return null;
    } catch (e) {
      return null;
    }
  }

  // Descarga el APK a almacenamiento temporal reportando progreso
  // (0.0 a 1.0) y luego abre el instalador nativo de Android.
  Future<void> downloadAndInstall(
    AppVersionInfo info, {
    void Function(double progress)? onProgress,
  }) async {
    final request = http.Request("GET", Uri.parse(info.apkUrl));
    final response = await http.Client().send(request);

    final total = response.contentLength ?? 0;
    var received = 0;

    final dir = await getTemporaryDirectory();
    final filePath = "${dir.path}/update_${info.versionCode}.apk";
    final file = File(filePath);
    final sink = file.openWrite();

    await for (final chunk in response.stream) {
      sink.add(chunk);
      received += chunk.length;
      if (total > 0 && onProgress != null) {
        onProgress(received / total);
      }
    }
    await sink.close();

    await OpenFilex.open(filePath);
  }
}