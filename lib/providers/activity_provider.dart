import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/dates.dart';
import '../data/challenges.dart';

class TasbeehPreset {
  final String id;
  final String text;
  final bool custom;
  const TasbeehPreset(this.id, this.text, {this.custom = false});
}

const builtinPresets = <TasbeehPreset>[
  TasbeehPreset('subhan', 'سبحان الله'),
  TasbeehPreset('hamd', 'الحمد لله'),
  TasbeehPreset('akbar', 'الله أكبر'),
  TasbeehPreset('tahlil', 'لا إله إلا الله'),
  TasbeehPreset('istighfar', 'أستغفر الله'),
  TasbeehPreset('salawat', 'اللهم صل وسلم على نبينا محمد'),
];

/// سجل نشاط يوم واحد.
class DayLog {
  int zikr = 0;
  final Set<int> pages = <int>{};
  final Map<String, int> tasbeeh = <String, int>{};
  final Set<String> azkarDone = <String>{};

  int get tasbeehTotal => tasbeeh.values.fold(0, (a, b) => a + b);
  bool get hasActivity =>
      zikr > 0 || pages.isNotEmpty || tasbeehTotal > 0 || azkarDone.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'z': zikr,
        'p': pages.toList(),
        't': tasbeeh,
        'a': azkarDone.toList(),
      };

  static DayLog fromJson(Map<String, dynamic> j) {
    final d = DayLog();
    d.zikr = (j['z'] as num?)?.toInt() ?? 0;
    d.pages.addAll(((j['p'] as List?) ?? const []).whereType<num>().map((v) => v.toInt()));
    ((j['t'] as Map?) ?? const {}).forEach((k, v) {
      if (k is String && v is num) d.tasbeeh[k] = v.toInt();
    });
    d.azkarDone.addAll(((j['a'] as List?) ?? const []).whereType<String>());
    return d;
  }
}

class Achievement {
  final String title;
  final String desc;
  final int current;
  final int target;
  const Achievement(this.title, this.desc, this.current, this.target);
  bool get earned => current >= target;
}

class ActivityProvider extends ChangeNotifier with WidgetsBindingObserver {
  List<Challenge> all = const [];
  final Map<String, DayLog> days = <String, DayLog>{};
  final Set<String> done = <String>{};
  final List<TasbeehPreset> custom = <TasbeehPreset>[];
  final Map<String, int> goals = <String, int>{};
  bool vibrate = true;
  bool sound = false;
  bool loading = true;

  SharedPreferences? _prefs;
  Timer? _saveTimer;
  static const _key = 'activity_v1';

  static const xpPerLevel = 150;

  Future<void> init() async {
    try {
      all = parseChallenges(await rootBundle.loadString('assets/data/challenges.json'));
    } catch (_) {
      all = const [];
    }
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_key);
    if (raw != null) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        (j['days'] as Map<String, dynamic>? ?? {}).forEach((k, v) {
          days[k] = DayLog.fromJson(v as Map<String, dynamic>);
        });
        done.addAll(((j['done'] as List?) ?? const []).cast<String>());
        for (final c in (j['custom'] as List?) ?? const []) {
          custom.add(TasbeehPreset(c['id'] as String, c['text'] as String, custom: true));
        }
        ((j['goals'] as Map?) ?? const {}).forEach((k, v) => goals[k as String] = v as int);
        vibrate = (j['vibrate'] as bool?) ?? true;
        sound = (j['sound'] as bool?) ?? false;
      } catch (_) {
        // لا نمسح بيانات المستخدم: نحتفظ بنسخة من النص التالف.
        await _prefs!.setString('${_key}_corrupt', raw);
      }
    }
    WidgetsBinding.instance.addObserver(this);
    loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _flush();
  }

  // ---------- حفظ ----------
  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), _flush);
  }

  void _flush() {
    _saveTimer?.cancel();
    final data = {
      'days': days.map((k, v) => MapEntry(k, v.toJson())),
      'done': done.toList(),
      'custom': custom.map((c) => {'id': c.id, 'text': c.text}).toList(),
      'goals': goals,
      'vibrate': vibrate,
      'sound': sound,
    };
    _prefs?.setString(_key, jsonEncode(data));
  }

  void _changed() {
    _autoSync();
    _scheduleSave();
    notifyListeners();
  }

  DayLog _log(DateTime d) => days.putIfAbsent(dayKey(d), DayLog.new);
  DayLog get today => days[dayKey(DateTime.now())] ?? DayLog();

  // ---------- التسبيح ----------
  List<TasbeehPreset> get presets => [...builtinPresets, ...custom];
  int goalOf(String id) => goals[id] ?? 100;
  int tasbeehCount(String id) => today.tasbeeh[id] ?? 0;

  void tapTasbeeh(String id) {
    final log = _log(DateTime.now());
    log.tasbeeh[id] = (log.tasbeeh[id] ?? 0) + 1;
    _changed();
  }

  void resetTasbeeh(String id) {
    _log(DateTime.now()).tasbeeh.remove(id);
    _changed();
  }

  void setGoal(String id, int goal) {
    goals[id] = goal.clamp(1, 100000);
    _scheduleSave();
    notifyListeners();
  }

  String addCustom(String text, int goal) {
    final id = 'c${DateTime.now().millisecondsSinceEpoch}';
    custom.add(TasbeehPreset(id, text.trim(), custom: true));
    goals[id] = goal.clamp(1, 100000);
    _scheduleSave();
    notifyListeners();
    return id;
  }

  void removeCustom(String id) {
    custom.removeWhere((c) => c.id == id);
    goals.remove(id);
    _scheduleSave();
    notifyListeners();
  }

  void setVibrate(bool v) {
    vibrate = v;
    _scheduleSave();
    notifyListeners();
  }

  void setSound(bool v) {
    sound = v;
    _scheduleSave();
    notifyListeners();
  }

  // ---------- تسجيل النشاط من بقية الأقسام ----------
  void addPage(int page) {
    if (_log(DateTime.now()).pages.add(page)) _changed();
  }

  void addZikr({required String categoryId, required bool categoryDone}) {
    final log = _log(DateTime.now());
    log.zikr++;
    if (categoryDone) log.azkarDone.add(categoryId);
    _changed();
  }

  // ---------- التحديات ----------
  Iterable<Challenge> _byPeriod(String p) => all.where((c) => c.period == p);

  List<Challenge> _pick(List<Challenge> pool, int seed, int n) {
    final list = [...pool]..sort((a, b) => a.id.compareTo(b.id));
    list.shuffle(Random(seed));
    return list.take(n).toList();
  }

  List<Challenge> dailyFor(DateTime d) {
    final rng = Random(d.year * 10000 + d.month * 100 + d.day);
    final byCat = <String, List<Challenge>>{};
    for (final c in _byPeriod('day')) {
      byCat.putIfAbsent(c.cat, () => <Challenge>[]).add(c);
    }
    final cats = byCat.keys.toList()..sort();
    cats.shuffle(rng);
    return cats.take(5).map((k) {
      final l = [...byCat[k]!]..sort((a, b) => a.id.compareTo(b.id));
      return l[rng.nextInt(l.length)];
    }).toList();
  }

  List<Challenge> weeklyFor(DateTime d) {
    final s = weekStart(d);
    return _pick(_byPeriod('week').toList(), s.year * 10000 + s.month * 100 + s.day, 2);
  }

  List<Challenge> monthlyFor(DateTime d) =>
      _pick(_byPeriod('month').toList(), d.year * 100 + d.month, 1);

  String periodKey(Challenge c, DateTime d) {
    switch (c.period) {
      case 'week':
        return 'w:${dayKey(weekStart(d))}';
      case 'month':
        return 'm:${monthKey(d)}';
      default:
        return 'd:${dayKey(d)}';
    }
  }

  String doneId(Challenge c, DateTime d) => '${periodKey(c, d)}:${c.id}';
  bool isDone(Challenge c, DateTime d) => done.contains(doneId(c, d));

  void toggleManual(Challenge c, DateTime d) {
    final id = doneId(c, d);
    if (!done.remove(id)) done.add(id);
    _scheduleSave();
    notifyListeners();
  }

  List<DateTime> _range(String period, DateTime d) {
    switch (period) {
      case 'week':
        final s = weekStart(d);
        return List.generate(7, (i) => addDays(s, i));
      case 'month':
        final n = DateTime(d.year, d.month + 1, 0).day;
        return List.generate(n, (i) => DateTime(d.year, d.month, i + 1));
      default:
        return [DateTime(d.year, d.month, d.day)];
    }
  }

  int progressOf(Challenge c, DateTime d) {
    final a = c.auto;
    if (a == null) return 0;
    var sum = 0;
    for (final day in _range(c.period, d)) {
      final log = days[dayKey(day)];
      if (log == null) continue;
      if (a == 'pages') {
        sum += log.pages.length;
      } else if (a.startsWith('tasbeeh:')) {
        final id = a.substring(8);
        sum += id == 'all' ? log.tasbeehTotal : (log.tasbeeh[id] ?? 0);
      } else if (a.startsWith('azkar:')) {
        if (log.azkarDone.contains(a.substring(6))) sum += 1;
      }
    }
    return sum;
  }

  void _autoSync() {
    final now = DateTime.now();
    for (final c in [...dailyFor(now), ...weeklyFor(now), ...monthlyFor(now)]) {
      if (c.auto != null && !isDone(c, now) && progressOf(c, now) >= c.goal) {
        done.add(doneId(c, now));
      }
    }
  }

  int dailyDone(DateTime d) => dailyFor(d).where((c) => isDone(c, d)).length;

  int _doneOnDay(DateTime d) {
    final prefix = 'd:${dayKey(d)}:';
    return done.where((e) => e.startsWith(prefix)).length;
  }

  // ---------- الإحصائيات ----------
  int sumOver(Iterable<DateTime> range, int Function(DayLog) f) {
    var s = 0;
    for (final d in range) {
      final log = days[dayKey(d)];
      if (log != null) s += f(log);
    }
    return s;
  }

  int tasbeehOn(DateTime d) => sumOver([d], (l) => l.tasbeehTotal);
  int pagesOn(DateTime d) => sumOver([d], (l) => l.pages.length);
  int challengesOn(DateTime d) => _doneOnDay(d);

  List<DateTime> lastDays(int n) {
    final t = DateTime.now();
    return List.generate(n, (i) => DateTime(t.year, t.month, t.day - (n - 1 - i)));
  }

  List<DateTime> monthDays() => _range('month', DateTime.now());

  int challengesInMonth() {
    final p = 'd:${monthKey(DateTime.now())}';
    return done.where((e) => e.startsWith(p)).length;
  }

  Set<String> get activeDates {
    final s = <String>{};
    days.forEach((k, v) {
      if (v.hasActivity) s.add(k);
    });
    for (final id in done) {
      if (id.startsWith('d:')) s.add(id.substring(2, 12));
    }
    return s;
  }

  int get streak => currentStreak(activeDates, DateTime.now());
  int get bestStreak => longestStreak(activeDates);

  int get xp {
    var x = 0;
    for (final id in done) {
      switch (id[0]) {
        case 'w':
          x += 25;
          break;
        case 'm':
          x += 60;
          break;
        default:
          x += 10;
      }
    }
    return x;
  }

  int get level => xp ~/ xpPerLevel + 1;
  int get xpInLevel => xp % xpPerLevel;

  int get totalTasbeeh => days.values.fold(0, (a, l) => a + l.tasbeehTotal);
  int get totalPages => days.values.fold(0, (a, l) => a + l.pages.length);
  int get totalChallenges => done.length;

  List<Achievement> get badges => [
        Achievement('ثلاثة أيام متواصلة', 'نشاط ٣ أيام متتالية', bestStreak, 3),
        Achievement('أسبوع متواصل', 'نشاط ٧ أيام متتالية', bestStreak, 7),
        Achievement('ثلاثون يومًا', 'نشاط ٣٠ يومًا متتالية', bestStreak, 30),
        Achievement('البداية', 'إنجاز ١٠ تحديات', totalChallenges, 10),
        Achievement('المثابر', 'إنجاز ٥٠ تحديًا', totalChallenges, 50),
        Achievement('الصامد', 'إنجاز ١٠٠ تحدٍّ', totalChallenges, 100),
        Achievement('ذاكر', '١٬٠٠٠ تسبيحة', totalTasbeeh, 1000),
        Achievement('كثير الذكر', '١٠٬٠٠٠ تسبيحة', totalTasbeeh, 10000),
        Achievement('قارئ', 'قراءة ١٠ صفحات', totalPages, 10),
        Achievement('وِرد ثابت', 'قراءة ١٠٠ صفحة', totalPages, 100),
        Achievement('ختمة', 'قراءة ٦٠٤ صفحات', totalPages, 604),
      ];
}
