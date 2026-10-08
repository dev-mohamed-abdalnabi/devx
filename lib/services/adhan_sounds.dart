import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// صوت أذان. الصوت الأساسي مدمج داخل التطبيق (res/raw/adhan)،
/// أما الباقي فيحمّله المستخدم عند الحاجة ولا يزيد حجم التطبيق.
class AdhanSound {
  final String id;
  final String name;
  final String desc;
  final String? file; // null = الصوت المدمج
  const AdhanSound(this.id, this.name, this.desc, [this.file]);
  bool get bundled => file == null;
}

class AdhanSounds {
  /// الملفات مستضافة في مستودع GitHub (فولدر «اذان»). لتغيير الاستضافة
  /// غيّر هذا الرابط وأسماء الملفات في القائمة أدناه.
  static const baseUrl =
      'https://raw.githubusercontent.com/dev-mohamed-abdalnabi/devx-audio-packages/main/%D8%A7%D8%B0%D8%A7%D9%86';

  static const defaultId = 'default';

  static const all = <AdhanSound>[
    AdhanSound(defaultId, 'الأذان الأساسي', 'مدمج في التطبيق، لا يحتاج تحميل'),
    AdhanSound('makkah', 'أذان الحرم المكي', 'مكة المكرمة', 'Adzan_Makkah.mp3'),
    AdhanSound('makkah2', 'أذان مكة (٢)', 'مكة المكرمة · نسخة قصيرة',
        'Adzan_Makkah_2.mp3'),
    AdhanSound('madinah', 'أذان المسجد النبوي', 'المدينة المنورة',
        'Adzan_Madinah.mp3'),
    AdhanSound('madinah_fajr', 'أذان فجر المدينة', 'المدينة المنورة · الفجر',
        'Adzan_Madinah_Subuh.mp3'),
    AdhanSound('aqsa', 'أذان المسجد الأقصى', 'القدس الشريف', 'Adzan_Aqsa.mp3'),
    AdhanSound('egypt', 'الأذان المصري', 'مصر', 'Adzan_Mesir.mp3'),
    AdhanSound('kuwait', 'الأذان الكويتي', 'الكويت', 'Adzan_Kuwait_2.mp3'),
    AdhanSound('syria', 'الأذان السوري', 'سوريا', 'Adzan_Suriah.mp3'),
  ];

  static AdhanSound byId(String id) =>
      all.firstWhere((s) => s.id == id, orElse: () => all.first);

  static Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/adhan_sounds');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  /// مسار الملف المحمَّل، أو null لو الصوت مدمج/غير محمَّل.
  static Future<String?> localPath(String id) async {
    final s = byId(id);
    if (s.bundled) return null;
    final f = File('${(await _dir()).path}/${s.id}.mp3');
    return await f.exists() && await f.length() > 20 * 1024 ? f.path : null;
  }

  static Future<bool> isAvailable(String id) async =>
      byId(id).bundled || await localPath(id) != null;

  /// يحمّل الصوت مع نسبة التقدم (0..1). يرمي Exception برسالة عربية عند الفشل.
  static Future<void> download(String id,
      {void Function(double)? onProgress}) async {
    final s = byId(id);
    if (s.bundled) return;
    final dir = await _dir();
    final tmp = File('${dir.path}/${s.id}.mp3.part');
    final client = http.Client();
    try {
      final res = await client
          .send(http.Request('GET', Uri.parse('$baseUrl/${s.file}')))
          .timeout(const Duration(seconds: 25));
      if (res.statusCode != 200) {
        throw Exception('تعذّر التحميل (${res.statusCode}). حاول لاحقًا.');
      }
      final total = res.contentLength ?? 0;
      var got = 0;
      final sink = tmp.openWrite();
      try {
        await for (final chunk in res.stream) {
          sink.add(chunk);
          got += chunk.length;
          if (total > 0) onProgress?.call(got / total);
        }
      } finally {
        await sink.close();
      }
      if (got < 20 * 1024) {
        throw Exception('الملف غير صالح. حاول لاحقًا.');
      }
      await tmp.rename('${dir.path}/${s.id}.mp3');
      onProgress?.call(1);
    } on SocketException {
      throw Exception('لا يوجد اتصال بالإنترنت.');
    } finally {
      client.close();
      if (await tmp.exists()) {
        try {
          await tmp.delete();
        } catch (_) {}
      }
    }
  }

  static Future<void> delete(String id) async {
    final p = await localPath(id);
    if (p != null) {
      try {
        await File(p).delete();
      } catch (_) {}
    }
  }
}
