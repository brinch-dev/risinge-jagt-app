import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppUpdateService {
  static const _bucket = 'app-releases';
  static const _versionFile = 'version.json';

  static Future<void> checkForUpdate(BuildContext context) async {
    if (kIsWeb) return;

    try {
      final client = Supabase.instance.client;
      final url = client.storage.from(_bucket).getPublicUrl(_versionFile);
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return;

      final remote = jsonDecode(response.body) as Map<String, dynamic>;
      final remoteBuild = remote['build'] as int;
      final remoteVersion = remote['version'] as String;
      final apkFileName = remote['apk_file'] as String;
      final releaseNotes = remote['release_notes'] as String? ?? '';

      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;

      if (remoteBuild <= currentBuild) return;

      if (!context.mounted) return;
      _showUpdateDialog(context, remoteVersion, releaseNotes, apkFileName);
    } catch (_) {}
  }

  static void _showUpdateDialog(
    BuildContext context,
    String version,
    String releaseNotes,
    String apkFileName,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Ny version tilgaengelig'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version $version er klar til installation.'),
            if (releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                releaseNotes,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Senere'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _downloadAndInstall(context, apkFileName);
            },
            child: const Text('Opdater nu'),
          ),
        ],
      ),
    );
  }

  static Future<void> _downloadAndInstall(
    BuildContext context,
    String apkFileName,
  ) async {
    final overlay = OverlayEntry(
      builder: (ctx) => const _DownloadOverlay(),
    );
    Overlay.of(context).insert(overlay);

    try {
      final client = Supabase.instance.client;
      final url = client.storage.from(_bucket).getPublicUrl(apkFileName);
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) throw Exception('Download fejlede');

      final dir = await getExternalCacheDirectories();
      final filePath = '${dir!.first.path}/jagt-app-update.apk';
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      overlay.remove();
      await OpenFilex.open(filePath, type: 'application/vnd.android.package-archive');
    } catch (e) {
      overlay.remove();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Opdatering fejlede: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class _DownloadOverlay extends StatelessWidget {
  const _DownloadOverlay();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Henter opdatering...', style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}
