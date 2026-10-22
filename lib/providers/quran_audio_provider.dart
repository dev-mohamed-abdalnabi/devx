import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:audio_service/audio_service.dart' show MediaItem;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/battery_prompt.dart';
import '../services/quran_audio_handler.dart';
import 'notification_service.dart';

class QuranReciter {
  final String id;
  final String name;
  final String? downloadUrl;
  final String? streamEdition;
  const QuranReciter(this.id, this.name, this.downloadUrl,
      {this.streamEdition});

  bool get available => downloadUrl != null || streamEdition != null;
  bool get downloadable => downloadUrl != null;
  bool get streamOnly => downloadUrl == null && streamEdition != null;

  String? streamUrl(int surah) => streamEdition == null
      ? null
      : 'https://cdn.islamic.network/quran/audio-surah/128/'
          '$streamEdition/$surah.mp3';
}

enum AudioRepeat { off, all, one }

/// يحوّل مدة إلى نص مثل 3:07 أو 1:02:09.
String formatAudioTime(Duration d) {
  final total = d.isNegative ? 0 : d.inSeconds;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  final ss = s.toString().padLeft(2, '0');
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$ss';
  return '$m:$ss';
}

/// يفك ملف ZIP داخل isolate منفصل حتى لا يتجمد التطبيق. يرجع عدد السور المستخرجة.
int _extractSurahZip(List<String> args) {
  final zipPath = args[0];
  final outDir = Directory(args[1]);
  if (outDir.existsSync()) outDir.deleteSync(recursive: true);
  outDir.createSync(recursive: true);
  final archive = ZipDecoder().decodeBytes(File(zipPath).readAsBytesSync());
  final pattern = RegExp(r'^0*(\d{1,3})\.(mp3|m4a|ogg|opus)$', caseSensitive: false);
  var count = 0;
  for (final entry in archive) {
    if (!entry.isFile) continue;
    final name = entry.name.replaceAll('\\', '/').split('/').last;
    final match = pattern.firstMatch(name);
    if (match == null) continue;
    final n = int.parse(match.group(1)!);
    if (n < 1 || n > 114) continue;
    final content = entry.content;
    if (content is! List<int>) continue;
    final ext = name.split('.').last.toLowerCase();
    File('${outDir.path}/${n.toString().padLeft(3, '0')}.$ext')
        .writeAsBytesSync(content, flush: true);
    count++;
  }
  return count;
}

class QuranAudioProvider extends ChangeNotifier {
  /// سبب فشل تهيئة خدمة الميديا (إن حدث) ليظهر في شاشة الفحص بدل الفشل الصامت.
  static String? get backgroundInitError => QuranAudioService.initError;

  static const int surahCount = 114;
  static const int maxDownloadBytes = 300 * 1024 * 1024;
  static const List<double> speeds = [0.75, 1.0, 1.25, 1.5, 2.0];
  static const Duration seekStep = Duration(seconds: 10);

  static const String _reciterKey = 'quran_audio_reciter';
  static const String _favoritesKey = 'quran_audio_favorites';
  static const String _speedKey = 'quran_audio_speed';
  static const String _repeatKey = 'quran_audio_repeat';
  static const String _shuffleKey = 'quran_audio_shuffle';
  static String _lastSurahKey(String id) => 'quran_audio_last_$id';
  static String _lastPositionKey(String id) => 'quran_audio_pos_$id';

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
    QuranReciter('mishary', 'مشاري راشد العفاسي',
        'https://raw.githubusercontent.com/dev-mohamed-abdalnabi/devx-audio-packages/main/mishary/quran.zip'),
    QuranReciter('basit_murattal', 'عبد الباسط عبد الصمد — المرتل', null,
        streamEdition: 'ar.abdulbasitmurattal'),
    QuranReciter('basit_mujawwad', 'عبد الباسط عبد الصمد — المجود', null,
        streamEdition: 'ar.abdulbasitmujawwad'),
    QuranReciter('hani', 'هاني الرفاعي',
        'https://raw.githubusercontent.com/dev-mohamed-abdalnabi/devx-audio-packages/main/hani/quran.zip',
        streamEdition: 'ar.haniarrifai'),
    QuranReciter('banna', 'محمود علي البنا',
        'https://raw.githubusercontent.com/dev-mohamed-abdalnabi/devx-audio-packages/main/albanna/quran.zip',
        streamEdition: 'ar.mahmoudalialbanna'),
    QuranReciter('mustafa_ismail', 'مصطفى إسماعيل', null,
        streamEdition: 'ar.mustafaismail'),
    QuranReciter('tablawi', 'محمد محمود الطبلاوي', null,
        streamEdition: 'ar.mohamedtablawi'),
    QuranReciter('fares_abbad', 'فارس عباد', null,
        streamEdition: 'ar.faresabbad'),
    QuranReciter('ahmed_ajmi', 'أحمد بن علي العجمي', null,
        streamEdition: 'ar.ahmedalajmi'),
    QuranReciter('yasser_dossari', 'ياسر الدوسري',
        'https://raw.githubusercontent.com/dev-mohamed-abdalnabi/devx-audio-packages/main/yasser/quran.zip',
        streamEdition: 'ar.yasseraldossari'),
  ];

  static String surahName(int surah) => surahNames[surah - 1];

  /// المشغل المشترك مع إشعار الميديا (نفس الكائن الذي يقرأ منه الإشعار الموضع والحالة).
  AudioPlayer get player => QuranAudioService.player;

  SharedPreferences? _prefs;
  final List<StreamSubscription<dynamic>> _subs = [];
  Timer? _saveTimer;
  Timer? _sleepTimer;
  Timer? _sleepTicker;
  QuranAudioHandler? _attached;

  String selectedReciterId = reciters.first.id;
  Map<int, File> _files = <int, File>{};
  List<int> _queue = <int>[];
  List<int> _shuffleOrder = <int>[];

  /// السورة المحمّلة فعليًا في المشغل الآن (null = لا شيء محمّل).
  int? _loadedSurah;
  int _loadToken = 0;
  bool _advancing = false;
  bool _disposed = false;
  bool _cancelRequested = false;

  Set<int> favorites = <int>{};
  int? currentSurah;
  int? lastSurah;
  Duration lastPosition = Duration.zero;
  double speed = 1.0;
  AudioRepeat repeat = AudioRepeat.off;
  bool shuffle = false;

  bool loading = false;
  bool downloading = false;
  bool extracting = false;
  int downloadedBytes = 0;
  int totalBytes = 0;
  String? error;

  DateTime? _sleepEndsAt;
  bool sleepAtSurahEnd = false;
  bool _sleepFiring = false;

  QuranAudioProvider() {
    _subs.add(player.playerStateStream.listen((state) {
      if (!state.playing) _savePosition();
      if (state.processingState == ProcessingState.completed) unawaited(_onCompleted());
      _notify();
    }));
    _subs.add(player.positionStream.listen(_onPosition));
    _subs.add(player.playbackEventStream.listen((_) {}, onError: (Object e, StackTrace _) {
      loading = false;
      error = 'تعذّر تشغيل هذا الملف. جرّب سورة أخرى أو أعد تنزيل التلاوة.';
      _notify();
    }));
  }

  // ───────── حالة للقراءة ─────────

  QuranReciter get selectedReciter => reciters.firstWhere((r) => r.id == selectedReciterId);
  int get availableCount => selectedReciter.streamOnly ? surahCount : _files.length;
  List<int> get availableSurahs => List<int>.unmodifiable(_queue);
  bool get isReady => selectedReciter.streamOnly || _files.length == surahCount;
  bool get hasAnyAudio => selectedReciter.streamOnly || _files.isNotEmpty;
  bool get isStreaming => selectedReciter.streamOnly;
  bool get hasDownloadedAudio => _files.isNotEmpty;
  bool get isPlaying => player.playing;
  bool get hasTrack => currentSurah != null || lastSurah != null;
  int? get displaySurah => currentSurah ?? lastSurah;
  bool get isBusy => downloading || extracting;
  double get downloadProgress => totalBytes == 0 ? 0 : (downloadedBytes / totalBytes).clamp(0.0, 1.0);
  bool hasSurah(int surah) => selectedReciter.streamOnly || _files.containsKey(surah);
  bool isFavorite(int surah) => favorites.contains(surah);

  bool get sleepActive => _sleepEndsAt != null || sleepAtSurahEnd;
  Duration? get sleepRemaining {
    final end = _sleepEndsAt;
    if (end == null) return null;
    final left = end.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  // ───────── التهيئة والإعدادات ─────────

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 5));
      final p = _prefs!;
      final savedReciter = p.getString(_reciterKey);
      if (savedReciter != null && reciters.any((r) => r.id == savedReciter)) {
        selectedReciterId = savedReciter;
      }
      favorites = (p.getStringList(_favoritesKey) ?? const <String>[])
          .map(int.tryParse)
          .whereType<int>()
          .where((n) => n >= 1 && n <= surahCount)
          .toSet();
      final savedSpeed = p.getDouble(_speedKey) ?? 1.0;
      speed = speeds.contains(savedSpeed) ? savedSpeed : 1.0;
      repeat = AudioRepeat.values[(p.getInt(_repeatKey) ?? 0)
          .clamp(0, AudioRepeat.values.length - 1)];
      shuffle = p.getBool(_shuffleKey) ?? false;
      await _migrateLegacyAudioDirectory();
      await _scanFiles();
      _loadLastPosition();
    } catch (_) {
      error = 'تعذر قراءة إعدادات التلاوة';
    } finally {
      _attachHandler();
      _notify();
    }
  }

  /// يربط أزرار الإشعار بالمزوّد. آمن للتكرار، ويلتقط الخدمة لو اكتملت تهيئتها متأخرة.
  void _attachHandler() {
    final h = QuranAudioService.handler;
    if (h == null || identical(h, _attached)) return;
    _attached = h;
    h.onPlay = _resumeFromSystem;
    h.onSkipNext = next;
    h.onSkipPrevious = previous;
    h.onBeforeStop = _beforeStop;
  }

  void _loadLastPosition() {
    final p = _prefs;
    if (p == null) return;
    final surah = p.getInt(_lastSurahKey(selectedReciterId));
    lastSurah = surah != null && hasSurah(surah) ? surah : null;
    lastPosition = lastSurah == null
        ? Duration.zero
        : Duration(milliseconds: p.getInt(_lastPositionKey(selectedReciterId)) ?? 0);
  }

  Future<void> selectReciter(String id) async {
    if (isBusy || !reciters.any((r) => r.id == id) || id == selectedReciterId) return;
    await stop();
    selectedReciterId = id;
    currentSurah = null;
    _queue = <int>[];
    error = null;
    await _prefs?.setString(_reciterKey, id);
    await _scanFiles();
    _loadLastPosition();
    _notify();
  }

  Future<void> toggleFavorite(int surah) async {
    if (!favorites.remove(surah)) favorites.add(surah);
    await _prefs?.setStringList(_favoritesKey, favorites.map((e) => '$e').toList());
    _notify();
  }

  Future<void> setSpeed(double value) async {
    if (!speeds.contains(value)) return;
    speed = value;
    await player.setSpeed(value);
    await _prefs?.setDouble(_speedKey, value);
    _notify();
  }

  Future<void> cycleRepeat() async {
    repeat = AudioRepeat.values[(repeat.index + 1) % AudioRepeat.values.length];
    await _applyLoopMode();
    await _prefs?.setInt(_repeatKey, repeat.index);
    _notify();
  }

  Future<void> toggleShuffle() async {
    shuffle = !shuffle;
    if (shuffle) _rebuildShuffle();
    await _prefs?.setBool(_shuffleKey, shuffle);
    _notify();
  }

  /// «تكرار سورة واحدة» يتولاه المشغل نفسه؛ بقية الأوضاع نتولاها نحن عند انتهاء السورة.
  Future<void> _applyLoopMode() =>
      player.setLoopMode(repeat == AudioRepeat.one ? LoopMode.one : LoopMode.off);

  // ───────── الملفات ─────────

  Future<Directory> _reciterDirectory() async {
    final root = await getApplicationSupportDirectory();
    return Directory('${root.path}/quran_audio/$selectedReciterId');
  }

  Future<void> _migrateLegacyAudioDirectory() async {
    try {
      final oldRoot = await getApplicationDocumentsDirectory();
      final newRoot = await getApplicationSupportDirectory();
      final oldDir = Directory('${oldRoot.path}/quran_audio/$selectedReciterId');
      final newDir = Directory('${newRoot.path}/quran_audio/$selectedReciterId');
      if (!await oldDir.exists() || await newDir.exists()) return;
      await newDir.parent.create(recursive: true);
      await oldDir.rename(newDir.path);
    } catch (_) {
      // الترحيل اختياري ولا يجب أن يمنع التشغيل.
    }
  }

  /// يمسح مجلد القارئ مرة واحدة ويبني خريطة رقم السورة ← الملف.
  Future<void> _scanFiles() async {
    final found = <int, File>{};
    final dir = await _reciterDirectory();
    if (await dir.exists()) {
      final pattern = RegExp(r'^0*(\d{1,3})\.(mp3|m4a|ogg|opus)$', caseSensitive: false);
      await for (final entity in dir.list(recursive: false)) {
        if (entity is! File) continue;
        final match = pattern.firstMatch(entity.uri.pathSegments.last);
        final n = match == null ? null : int.tryParse(match.group(1)!);
        if (n != null && n >= 1 && n <= surahCount && await entity.length() > 0) found[n] = entity;
      }
    }
    _files = found;
    _queue = selectedReciter.streamOnly
        ? [for (var n = 1; n <= surahCount; n++) n]
        : (found.keys.toList()..sort());
    _rebuildShuffle();
  }

  void _rebuildShuffle() {
    final order = List<int>.of(_queue)..shuffle(Random());
    final current = currentSurah ?? lastSurah;
    if (current != null && order.remove(current)) order.insert(0, current);
    _shuffleOrder = order;
  }

  // ───────── التنزيل ─────────

  Future<void> downloadPackage() async {
    if (isBusy || isReady) return;
    final url = selectedReciter.downloadUrl;
    downloading = true;
    extracting = false;
    error = null;
    downloadedBytes = 0;
    totalBytes = 0;
    _cancelRequested = false;
    _notify();
    final client = http.Client();
    File? zip;
    try {
      if (url == null) throw 'هذا القارئ غير متاح للتنزيل حاليًا';
      final response = await client.send(http.Request('GET', Uri.parse(url)));
      if (response.statusCode >= 400) throw 'تعذّر الوصول إلى ملف التلاوة (${response.statusCode})';
      totalBytes = response.contentLength ?? 0;
      if (totalBytes > maxDownloadBytes) throw 'حجم الملف أكبر من ٣٠٠ ميجابايت';

      final root = await getApplicationSupportDirectory();
      final base = Directory('${root.path}/quran_audio');
      await base.create(recursive: true);
      zip = File('${base.path}/$selectedReciterId.zip');
      final sink = zip.openWrite();
      try {
        var lastNotify = DateTime.fromMillisecondsSinceEpoch(0);
        await for (final chunk in response.stream) {
          if (_cancelRequested) throw 'cancelled';
          downloadedBytes += chunk.length;
          if (downloadedBytes > maxDownloadBytes) throw 'تم إيقاف التنزيل لتجاوز ٣٠٠ ميجابايت';
          sink.add(chunk);
          final now = DateTime.now();
          if (now.difference(lastNotify).inMilliseconds > 150) {
            lastNotify = now;
            _notify();
          }
        }
      } finally {
        await sink.close();
      }

      downloading = false;
      extracting = true;
      _notify();
      final target = '${base.path}/$selectedReciterId';
      final tmp = '${base.path}/$selectedReciterId.tmp';
      final count = await compute(_extractSurahZip, [zip.path, tmp]);
      if (count == 0) {
        await Directory(tmp).delete(recursive: true);
        throw 'الملف لا يحتوي على ملفات سور صالحة';
      }
      final old = Directory(target);
      if (await old.exists()) await old.delete(recursive: true);
      await Directory(tmp).rename(target);
      await _scanFiles();
      if (!isReady) error = 'تم تنزيل $count سورة فقط من ١١٤. أعد التنزيل لاحقًا.';
    } catch (e) {
      if (_cancelRequested || e == 'cancelled') {
        error = null;
      } else if (e is SocketException || e is http.ClientException) {
        error = 'تعذّر الاتصال بالإنترنت. تأكد من الشبكة وحاول مرة أخرى.';
      } else {
        error = e is String ? e : 'حدث خطأ أثناء التنزيل. حاول مرة أخرى.';
      }
    } finally {
      client.close();
      try {
        if (zip != null && await zip.exists()) await zip.delete();
      } catch (_) {}
      downloading = false;
      extracting = false;
      _notify();
    }
  }

  void cancelDownload() {
    if (!downloading) return;
    _cancelRequested = true;
  }

  /// يحذف التلاوة المحلية فقط بعد أن يطلب المستخدم ذلك من نافذة تغيير القارئ.
  Future<void> deleteDownloadedRecitation() async {
    if (isBusy || !selectedReciter.downloadable) return;
    await stop();
    final root = await getApplicationSupportDirectory();
    final base = Directory('${root.path}/quran_audio');
    final dir = Directory('${base.path}/$selectedReciterId');
    final zip = File('${base.path}/$selectedReciterId.zip');
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
      if (await zip.exists()) await zip.delete();
    } finally {
      _files = <int, File>{};
      _queue = <int>[];
      lastSurah = null;
      lastPosition = Duration.zero;
      await _prefs?.remove(_lastSurahKey(selectedReciterId));
      await _prefs?.remove(_lastPositionKey(selectedReciterId));
      _notify();
    }
  }

  // ───────── التشغيل ─────────

  MediaItem _mediaItem(int surah) => MediaItem(
        id: '$selectedReciterId-$surah',
        title: 'سورة ${surahName(surah)}',
        artist: selectedReciter.name,
        album: 'القرآن الكريم',
        extras: {'surah': surah},
      );

  /// يحمّل سورة واحدة في المشغل ويشغّلها. عند انتهائها ننتقل للتالية (انظر [_onCompleted]).
  Future<void> playSurah(int surah, {Duration? startAt, bool autoplay = true}) async {
    final token = ++_loadToken;
    try {
      error = null;
      // أندرويد 13+ لا يعرض إشعار التحكم دون إذن الإشعارات.
      unawaited(NotificationService.requestPermission());
      final file = _files[surah];
      final streamUrl = selectedReciter.streamUrl(surah);
      if (file == null && streamUrl == null) {
        throw 'نزّل التلاوة أولًا للاستماع إلى سورة ${surahName(surah)}';
      }
      _attachHandler();
      currentSurah = surah;
      loading = true;
      _notify();

      // بيانات الإشعار تُضبط قبل التحميل والتشغيل، فيظهر الإشعار باسم السورة من أول لحظة.
      final item = _mediaItem(surah);
      QuranAudioService.handler?.mediaItem.add(item);

      final duration = file != null
          ? await player.setFilePath(file.path, initialPosition: startAt)
          : await player.setUrl(streamUrl!, initialPosition: startAt);
      if (token != _loadToken || _disposed) return;
      _loadedSurah = surah;
      if (duration != null) {
        QuranAudioService.handler?.mediaItem.add(item.copyWith(duration: duration));
      }
      await player.setSpeed(speed);
      await _applyLoopMode();
      if (token != _loadToken || _disposed) return;
      _rememberSurah(surah, position: startAt ?? Duration.zero);
      loading = false;
      _notify();
      if (autoplay) _startPlayback();
    } catch (e) {
      if (token == _loadToken) {
        loading = false;
        _loadedSurah = null;
        error = e is String ? e : 'تعذّر تشغيل السورة. حاول مرة أخرى.';
      }
      _notify();
    }
  }

  /// play() لا يكتمل إلا بانتهاء التشغيل؛ لذلك لا ننتظره، ونلتقط أخطاءه.
  void _startPlayback() {
    unawaited(BatteryPrompt.maybeAsk());
    unawaited(player.play().catchError((Object e, StackTrace s) {
      error = 'تعذّر تشغيل هذا الملف. جرّب سورة أخرى أو أعد تنزيل التلاوة.';
      _notify();
    }));
  }

  /// زر التشغيل/الإيقاف: يستأنف من آخر موضع إن لم يكن هناك شيء محمّل.
  Future<void> togglePlay() async {
    if (player.playing) {
      await player.pause();
      return;
    }
    if (_loadedSurah != null && player.processingState != ProcessingState.idle) {
      if (player.processingState == ProcessingState.completed) await player.seek(Duration.zero);
      _startPlayback();
      return;
    }
    final surah = lastSurah ?? (_queue.isEmpty ? null : _queue.first);
    if (surah != null) {
      await playSurah(surah, startAt: surah == lastSurah ? lastPosition : Duration.zero);
    }
  }

  /// زر التشغيل في الإشعار: يشغّل فقط (لا يوقف).
  Future<void> _resumeFromSystem() async {
    if (!player.playing) await togglePlay();
  }

  Future<void> pause() => player.pause();

  Future<void> stop() async {
    _loadToken++; // يلغي أي تحميل جارٍ
    _attachHandler();
    final h = QuranAudioService.handler;
    if (h != null) {
      await h.stop(); // يستدعي _beforeStop ثم يوقف المشغل ويزيل الإشعار
    } else {
      await _beforeStop();
      await player.stop();
    }
  }

  Future<void> _beforeStop() async {
    await _savePosition();
    _loadedSurah = null;
    loading = false;
    _notify();
  }

  /// السورة المجاورة حسب الترتيب الحالي (عادي أو عشوائي). null = لا توجد.
  int? _neighbor(int delta, {required bool wrap}) {
    final order = shuffle ? _shuffleOrder : _queue;
    if (order.isEmpty) return null;
    final current = currentSurah ?? lastSurah;
    final index = current == null ? -1 : order.indexOf(current);
    if (index < 0) return delta > 0 ? order.first : order.last;
    var target = index + delta;
    if (target < 0 || target >= order.length) {
      if (!wrap) return null;
      target = (target % order.length + order.length) % order.length;
    }
    return order[target];
  }

  Future<void> next() async {
    final target = _neighbor(1, wrap: repeat == AudioRepeat.all);
    if (target == null) return;
    await playSurah(target, autoplay: player.playing || _loadedSurah == null);
  }

  Future<void> previous() async {
    if (_loadedSurah == null) return;
    if (player.position > const Duration(seconds: 3)) {
      await player.seek(Duration.zero);
      return;
    }
    final target = _neighbor(-1, wrap: repeat == AudioRepeat.all);
    if (target == null) {
      await player.seek(Duration.zero);
    } else {
      await playSurah(target, autoplay: player.playing);
    }
  }

  /// تقديم أو تأخير بمقدار [delta] (±10 ثوانٍ افتراضيًا من الواجهة).
  Future<void> seekBy(Duration delta) async {
    if (_loadedSurah == null) return;
    final duration = player.duration;
    var target = player.position + delta;
    if (target.isNegative) target = Duration.zero;
    if (duration != null && target >= duration) {
      await next();
      return;
    }
    await player.seek(target);
  }

  Future<void> seekTo(Duration position) async {
    if (_loadedSurah == null) return;
    await player.seek(position);
  }

  // ───────── مؤقت النوم ─────────

  void setSleepTimer(Duration duration) {
    clearSleepTimer(notify: false);
    _sleepEndsAt = DateTime.now().add(duration);
    _sleepTimer = Timer(duration, () {
      player.pause();
      clearSleepTimer();
    });
    _sleepTicker = Timer.periodic(const Duration(seconds: 1), (_) => _notify());
    _notify();
  }

  void setSleepAtSurahEnd() {
    clearSleepTimer(notify: false);
    sleepAtSurahEnd = true;
    _notify();
  }

  void clearSleepTimer({bool notify = true}) {
    _sleepTimer?.cancel();
    _sleepTicker?.cancel();
    _sleepTimer = null;
    _sleepTicker = null;
    _sleepEndsAt = null;
    sleepAtSurahEnd = false;
    _sleepFiring = false;
    if (notify) _notify();
  }

  // ───────── مراقبة المشغل ─────────

  /// انتهت السورة الحالية: ننتقل للتالية حسب وضع التكرار/العشوائي.
  Future<void> _onCompleted() async {
    if (_advancing || _sleepFiring || _loadedSurah == null) return;
    _advancing = true;
    try {
      if (sleepAtSurahEnd) {
        _sleepFiring = true;
        await _finishSleepAtSurahEnd();
        return;
      }
      final target = _neighbor(1, wrap: repeat == AudioRepeat.all);
      if (target == null) {
        // آخر سورة بلا تكرار: نقف على بدايتها جاهزة للتشغيل.
        await player.pause();
        await player.seek(Duration.zero);
        await _savePosition();
        return;
      }
      await playSurah(target);
    } catch (_) {
      // لا نترك علمًا عالقًا إن فشل الانتقال.
    } finally {
      _advancing = false;
    }
  }

  void _onPosition(Duration position) {
    if (_saveTimer == null && player.playing) {
      _saveTimer = Timer(const Duration(seconds: 5), () {
        _saveTimer = null;
        _savePosition();
      });
    }
    if (sleepAtSurahEnd && !_sleepFiring && _loadedSurah != null) {
      final duration = player.duration;
      if (duration != null && duration > Duration.zero && duration - position < const Duration(milliseconds: 500)) {
        _sleepFiring = true;
        unawaited(_finishSleepAtSurahEnd());
      }
    }
  }

  Future<void> _finishSleepAtSurahEnd() async {
    try {
      await player.pause();
      // نجهّز السورة التالية (دون تشغيل) بدل أن نبقى على آخر ثانية.
      final target = repeat == AudioRepeat.one ? null : _neighbor(1, wrap: repeat == AudioRepeat.all);
      if (target != null) {
        await playSurah(target, autoplay: false);
      } else {
        await player.seek(Duration.zero);
      }
    } finally {
      clearSleepTimer();
    }
  }

  void _rememberSurah(int surah, {Duration position = Duration.zero}) {
    lastSurah = surah;
    lastPosition = position;
    _prefs?.setInt(_lastSurahKey(selectedReciterId), surah);
    _prefs?.setInt(_lastPositionKey(selectedReciterId), position.inMilliseconds);
  }

  Future<void> _savePosition() async {
    final surah = currentSurah;
    if (surah == null || _loadedSurah == null) return;
    lastPosition = player.position;
    await _prefs?.setInt(_lastSurahKey(selectedReciterId), surah);
    await _prefs?.setInt(_lastPositionKey(selectedReciterId), player.position.inMilliseconds);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _saveTimer?.cancel();
    _sleepTimer?.cancel();
    _sleepTicker?.cancel();
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    // المشغل مشترك مع إشعار الميديا ويعيش مع التطبيق؛ لا نغلقه هنا.
    super.dispose();
  }
}
