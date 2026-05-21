import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class AppUpdateService {
  static const _repo = 'brinch-dev/risinge-jagt-app';
  static const _apiUrl = 'https://api.github.com/repos/$_repo/releases/latest';

  static Future<void> checkForUpdate(BuildContext context) async {
    if (kIsWeb) return;

    try {
      final response = await http.get(
        Uri.parse(_apiUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );
      if (response.statusCode != 200) return;

      final release = jsonDecode(response.body) as Map<String, dynamic>;
      final tagName = release['tag_name'] as String;
      final remoteVersion = tagName.replaceFirst('v', '');
      final releaseNotes = release['body'] as String? ?? '';

      final assets = release['assets'] as List;
      final apkAsset = assets.cast<Map<String, dynamic>>().firstWhere(
            (a) => (a['name'] as String).endsWith('.apk'),
            orElse: () => <String, dynamic>{},
          );
      if (apkAsset.isEmpty) return;

      final downloadUrl = apkAsset['browser_download_url'] as String;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      if (!_isNewer(remoteVersion, currentVersion)) return;

      if (!context.mounted) return;
      _showUpdateDialog(context, remoteVersion, releaseNotes, downloadUrl);
    } catch (_) {}
  }

  static bool _isNewer(String remote, String current) {
    final r = remote.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final c = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (var i = 0; i < 3; i++) {
      final rv = i < r.length ? r[i] : 0;
      final cv = i < c.length ? c[i] : 0;
      if (rv > cv) return true;
      if (rv < cv) return false;
    }
    return false;
  }

  static void _showUpdateDialog(
    BuildContext context,
    String version,
    String releaseNotes,
    String downloadUrl,
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
                releaseNotes.length > 200
                    ? '${releaseNotes.substring(0, 200)}...'
                    : releaseNotes,
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
              _downloadAndInstall(context, downloadUrl);
            },
            child: const Text('Opdater nu'),
          ),
        ],
      ),
    );
  }

  static Future<void> _downloadAndInstall(
    BuildContext context,
    String downloadUrl,
  ) async {
    final overlay = OverlayEntry(
      builder: (ctx) => const _DownloadOverlay(),
    );
    Overlay.of(context).insert(overlay);

    try {
      final response = await http.get(Uri.parse(downloadUrl));
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
