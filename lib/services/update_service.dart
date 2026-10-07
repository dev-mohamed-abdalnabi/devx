import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/supabase_config.dart';

class AppRelease {
  final String versionName;
  final int versionCode;
  final String downloadPageUrl;
  final String apkUrl;
  final String notes;
  final bool required;

  const AppRelease({
    required this.versionName,
    required this.versionCode,
    required this.downloadPageUrl,
    required this.apkUrl,
    required this.notes,
    required this.required,
  });

  factory AppRelease.fromMap(Map<String, dynamic> map) => AppRelease(
        versionName: map['version_name'].toString(),
        versionCode: (map['version_code'] as num).toInt(),
        downloadPageUrl: map['download_page_url'].toString(),
        apkUrl: map['apk_url'].toString(),
        notes: (map['release_notes'] ?? '').toString(),
        required: map['is_required'] == true,
      );
}

class UpdateService {
  static const _lastPromptKey = 'last_update_prompt_version';
  static bool _checking = false;

  static Future<AppRelease?> findAvailableRelease() async {
    final package = await PackageInfo.fromPlatform();
    final currentCode = int.tryParse(package.buildNumber) ?? 0;
    final row = await supabase
        .from('app_releases')
        .select(
            'version_name, version_code, download_page_url, apk_url, release_notes, is_required')
        .eq('is_active', true)
        .gt('version_code', currentCode)
        .order('version_code', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    return AppRelease.fromMap(Map<String, dynamic>.from(row));
  }

  static Future<void> checkAndShow(BuildContext context) async {
    if (_checking || !context.mounted) return;
    _checking = true;
    try {
      final release = await findAvailableRelease();
      if (release == null || !context.mounted) return;
      final prefs = await SharedPreferences.getInstance();
      final lastPrompt = prefs.getString(_lastPromptKey);
      final shouldShow = release.required || lastPrompt != release.versionName;
      if (!shouldShow || !context.mounted) return;
      await prefs.setString(_lastPromptKey, release.versionName);
      await showDialog<void>(
        context: context,
        barrierDismissible: !release.required,
        builder: (_) => _UpdateDialog(release: release),
      );
    } catch (_) {
      // فشل الإنترنت أو Supabase لا يمنع فتح التطبيق.
    } finally {
      _checking = false;
    }
  }
}

class _UpdateDialog extends StatelessWidget {
  final AppRelease release;
  const _UpdateDialog({required this.release});

  Future<void> _openDownload() async {
    final apkUri = Uri.tryParse(release.apkUrl);
    if (apkUri != null &&
        await launchUrl(apkUri, mode: LaunchMode.externalApplication)) {
      return;
    }
    final pageUri = Uri.tryParse(release.downloadPageUrl);
    if (pageUri != null) {
      await launchUrl(pageUri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Row(children: [
          Icon(Icons.system_update_rounded,
              color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          const Expanded(child: Text('تحديث جديد متاح')),
        ]),
        content: SingleChildScrollView(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('الإصدار ${release.versionName} أصبح جاهزًا للتنزيل.'),
            if (release.notes.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text('أهم التحديثات',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(release.notes),
            ],
            const SizedBox(height: 14),
            const Text(
                'سيتم فتح صفحة التحميل الرسمية. نزّل ملف APK وثبّته فوق النسخة الحالية.'),
          ]),
        ),
        actions: [
          if (!release.required)
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('لاحقًا')),
          FilledButton.icon(
            onPressed: () async {
              await _openDownload();
              if (context.mounted && !release.required) Navigator.pop(context);
            },
            icon: const Icon(Icons.download_rounded),
            label: const Text('تحميل التحديث'),
          ),
        ],
      );
}
