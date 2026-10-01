import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuranReciter {
  final String id;
  final String name;
  final String subtitle;
  final String packagePath;
  final String? downloadUrl;
  const QuranReciter(this.id, this.name, this.subtitle, this.packagePath, this.downloadUrl);
}

class QuranAudioProvider extends ChangeNotifier {
  static const int surahCount = 114;
  static const int maxDownloadBytes = 100 * 1024 * 1024;
  static const String _reciterKey = 'quran_audio_reciter';
  static const String _downloadedKey = 'quran_audio_downloaded';
  static const List<String> surahNames = [
    'الفاتحة', 'البقرة', 'آل عمران', 'النساء', 'المائدة', 'الأنعام', 'الأعراف', 'الأنفال', 'التوبة', 'يونس',
    'هود', 'يوسف', 'الرعد', 'إبراهيم', 'الحجر', 'النحل', 'الإسراء', 'الكهف', 'مريم', 'طه',
    'الأنبياء', 'الحج', 'المؤمنون', 'النور', 'الفرقان', 'الشعراء', 'النمل', 'القصص', 'العنكبوت', 'الروم',
    'لقمان', 'السجدة', 'الأحزاب', 'سبأ', 'فاطر', 'يس', 'الصافات', 'ص', 'الزمر', 'غافر',
    'فصلت', 'الشورى', 'الزخرف', 'الدخان', 'الجاثية', 'الأحقاف', 'محمد', 'الفتح', 'الحجرات', 'ق',
    'الذاريات', 'الطور', 'النجم', 'القمر', 'الرحمن', 'الواقعة', 'الحديد', 'المجادلة', 'الحشر', 'الممتحنة',
    'الصف', 'الجمعة', 'المنافقون', 'التغابن', 'الطلاق', 'التحريم', 'الملك', 'القلم', 'الحاقة', 'المعارج',
    'نوح', 'الجن', 'المزمل', 'المدثر', 'القيامة', 'الإنسان', 'المرسلات', 'النبأ', 'النازعات', 'عبس',
    'التكوير', 'الانفطار', 'المطففين', 'الانشقاق', 'البروج', 'الطارق', 'الأعلى', 'الغاشية', 'الفجر', 'البلد',
    'الشمس', 'الليل', 'الضحى', 'الشرح', 'التين', 'العلق', 'القدر', 'البينة', 'الزلزلة', 'العاديات',
    'القارعة', 'التكاثر', 'العصر', 'الهمزة', 'الفيل', 'قريش', 'الماعون', 'الكوثر', 'الكافرون', 'النصر',
    'المسد', 'الإخلاص', 'الفلق', 'الناس',
  ];

  static const reciters = <QuranReciter>[
    QuranReciter('mishary', 'مشاري راشد العفاسي', 'نسخة مضغوطة · تنزيل عام', 'mishary', 'https://raw.githubusercontent.com/dev-mohamed-abdalnabi/devx-audio-packages/main/mishary/quran.zip'),
    QuranReciter('husary', 'محمود خليل الحصري', 'أضف ZIP ثم رابطًا عامًا', 'husary', null),
    QuranReciter('minshawi', 'محمد صديق المنشاوي', 'أضف ZIP ثم رابطًا عامًا', 'minshawi', null),
    QuranReciter('sudais', 'عبدالرحمن السديس', 'أضف ZIP ثم رابطًا عامًا', 'sudais', null),
  ];

  final AudioPlayer player = AudioPlayer();
  SharedPreferences? _prefs;
  StreamSubscription<PlayerState>? _stateSub;
  String selectedReciterId = reciters.first.id;
  Set<int> downloadedSurahs = <int>{};
  bool downloading = false;
  int downloadedBytes = 0;
  int totalBytes = 0;
  Object? error;

  QuranAudioProvider() {
    _stateSub = player.playerStateStream.listen((_) => notifyListeners());
  }

  QuranReciter get selectedReciter => reciters.firstWhere((r) => r.id == selectedReciterId);
  bool get isReady => downloadedSurahs.length == surahCount;
  bool get isPlaying => player.playing;
  bool get hasAnyAudio => downloadedSurahs.isNotEmpty;
  double get downloadProgress => totalBytes == 0 ? 0 : downloadedBytes / totalBytes;
  String? get packageUrl => selectedReciter.downloadUrl;
  bool hasSurah(int surah) => downloadedSurahs.contains(surah);

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    selectedReciterId = _prefs?.getString(_reciterKey) ?? reciters.first.id;
    downloadedSurahs = (_prefs?.getStringList(_downloadedKey) ?? const [])
        .map(int.tryParse)
        .whereType<int>()
        .where((n) => n >= 1 && n <= surahCount)
        .toSet();
    await _migrateLegacyAudioDirectory();
    await _refreshDownloadedFiles();
    notifyListeners();
  }

  Future<void> selectReciter(String id) async {
    if (!reciters.any((r) => r.id == id) || id == selectedReciterId) return;
    await stop();
    selectedReciterId = id;
    downloadedSurahs = <int>{};
    await _prefs?.setString(_reciterKey, id);
    await _prefs?.remove(_downloadedKey);
    notifyListeners();
  }

  Future<Directory> _audioDirectory() async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory('${root.path}/quran_audio/$selectedReciterId');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _zipFile() async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory('${root.path}/quran_audio');
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}/$selectedReciterId.zip');
  }

  Future<void> _migrateLegacyAudioDirectory() async {
    final oldRoot = await getApplicationDocumentsDirectory();
    final newRoot = await getApplicationSupportDirectory();
    final oldDir = Directory('${oldRoot.path}/quran_audio/$selectedReciterId');
    final newDir = Directory('${newRoot.path}/quran_audio/$selectedReciterId');
    if (!await oldDir.exists() || await newDir.exists()) return;
    await newDir.parent.create(recursive: true);
    await oldDir.rename(newDir.path);
  }

  Future<File?> _fileFor(int surah) async {
    final dir = await _audioDirectory();
    await for (final entity in dir.list(recursive: false)) {
      if (entity is File && _surahNumber(entity.uri.pathSegments.last) == surah) return entity;
    }
    return null;
  }

  int? _surahNumber(String name) {
    final match = RegExp(r'^0*(\d{1,3})\.(mp3|m4a|ogg|opus)$', caseSensitive: false).firstMatch(name);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  Future<void> _refreshDownloadedFiles() async {
    final existing = <int>{};
    for (var surah = 1; surah <= surahCount; surah++) {
      if (await _fileFor(surah) != null) existing.add(surah);
    }
    downloadedSurahs = existing;
    await _prefs?.setStringList(_downloadedKey, existing.map((e) => e.toString()).toList());
  }

  Future<void> downloadPackage() async {
    if (downloading || isReady) return;
    downloading = true;
    error = null;
    downloadedBytes = 0;
    totalBytes = 0;
    notifyListeners();
    try {
      final url = packageUrl;
      if (url == null) throw Exception('هذا القارئ يحتاج رابط ZIP عام بعد رفع ملفه');
      final request = http.Request('GET', Uri.parse(url));
      final response = await http.Client().send(request);
      if (response.statusCode >= 400) throw Exception('لم يتم العثور على quran.zip لهذا القارئ');
      totalBytes = response.contentLength ?? 0;
      if (totalBytes > maxDownloadBytes) {
        throw Exception('حجم quran.zip أكبر من ١٠٠ ميجابايت');
      }
      final chunks = <int>[];
      await for (final chunk in response.stream) {
        chunks.addAll(chunk);
        downloadedBytes += chunk.length;
        if (downloadedBytes > maxDownloadBytes) throw Exception('تم إيقاف التنزيل لتجاوز ١٠٠ ميجابايت');
        notifyListeners();
      }
      final zip = await _zipFile();
      await zip.writeAsBytes(chunks, flush: true);
      await _extractPackage(Uint8List.fromList(chunks));
      await zip.delete();
      await _refreshDownloadedFiles();
      await _prefs?.setStringList(_downloadedKey, downloadedSurahs.map((e) => e.toString()).toList());
      if (!isReady) throw Exception('الملف لا يحتوي على السور الـ١١٤ كاملة');
    } catch (e) {
      error = e;
    } finally {
      downloading = false;
      notifyListeners();
    }
  }

  Future<void> _extractPackage(Uint8List bytes) async {
    final archive = ZipDecoder().decodeBytes(bytes);
    final dir = await _audioDirectory();
    await for (final entity in dir.list()) {
      if (entity is File) await entity.delete();
    }
    for (final entry in archive) {
      if (!entry.isFile) continue;
      final name = entry.name.replaceAll('\\', '/').split('/').last;
      if (!RegExp(r'^0*\d{1,3}\.(mp3|m4a|ogg|opus)$', caseSensitive: false).hasMatch(name)) continue;
      entry.decompress();
      final content = entry.content;
      if (content is List<int>) {
        await File('${dir.path}/$name').writeAsBytes(content, flush: true);
      }
    }
  }

  Future<void> playFrom(int surah) async {
    final sources = <AudioSource>[];
    for (var i = surah; i <= surahCount; i++) {
      final file = await _fileFor(i);
      if (file == null) continue;
      sources.add(AudioSource.file(file.path, tag: MediaItem(
        id: '$selectedReciterId-$i',
        title: 'سورة $i',
        album: 'القرآن الكريم',
        artist: selectedReciter.name,
      )));
    }
    if (sources.isEmpty) return;
    await player.setAudioSource(ConcatenatingAudioSource(children: sources));
    await player.play();
    notifyListeners();
  }

  Future<void> playSurah(int surah) async {
    try {
      final file = await _fileFor(surah);
      if (file == null) throw Exception('ملف السورة غير موجود داخل التطبيق');
      await player.setAudioSource(AudioSource.file(
        file.path,
        tag: MediaItem(
          id: '$selectedReciterId-$surah',
          title: 'سورة ${surahNames[surah - 1]}',
          album: 'القرآن الكريم',
          artist: selectedReciter.name,
        ),
      ));
      await player.play();
      error = null;
      notifyListeners();
    } catch (e) {
      error = e;
      notifyListeners();
    }
  }

  Future<void> pause() => player.pause();
  Future<void> resume() => player.play();
  Future<void> stop() => player.stop();

  @override
  void dispose() {
    unawaited(_stateSub?.cancel());
    unawaited(player.dispose());
    super.dispose();
  }
}
