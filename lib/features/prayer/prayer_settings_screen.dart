import 'dart:io' show Platform;
import 'package:azkari_native/azkari_native.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import '../../core/home_tokens.dart';
import '../../core/prayer_times.dart';
import '../../core/text_utils.dart';
import '../../providers/prayer_provider.dart';
import '../../services/adhan_sounds.dart';
import '../../widgets/page_kit.dart';
import 'adhan_screen.dart';
import 'adhan_styles.dart';

/// إعدادات الصلاة: صفحة كاملة بنفس أسلوب باقي التطبيق (هيرو + أقسام + كروت).
class PrayerSettingsScreen extends StatefulWidget {
  const PrayerSettingsScreen({super.key});

  @override
  State<PrayerSettingsScreen> createState() => _PrayerSettingsScreenState();
}

class _PrayerSettingsScreenState extends State<PrayerSettingsScreen> {
  AudioPlayer? _player;
  String? _playing;

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _togglePreview(String id) async {
    if (_playing == id) {
      await _player?.stop();
      setState(() => _playing = null);
      return;
    }
    final path = await AdhanSounds.localPath(id);
    if (path == null) return;
    try {
      _player ??= AudioPlayer();
      await _player!.setFilePath(path);
      setState(() => _playing = id);
      await _player!.play();
      if (mounted && _playing == id) setState(() => _playing = null);
    } catch (_) {
      if (mounted) setState(() => _playing = null);
      _toast('تعذّر تشغيل الصوت.');
    }
  }

  Future<void> _testAdhan(PrayerProvider p) async {
    if (!Platform.isAndroid) {
      _toast('تجربة الأذان متاحة على أندرويد فقط.');
      return;
    }
    if (!await AzkariNative.canUseFullScreenIntent()) {
      _toast('فعّل «عرض الإشعارات بملء الشاشة» لتظهر شاشة الأذان والهاتف مقفل.');
      await AzkariNative.requestFullScreenIntent();
    }
    final name = p.nextPrayer(DateTime.now())?.name ?? 'الظهر';
    if (p.adhanDisplay == adhanDisplayOverApps &&
        !await AzkariNative.canDrawOverlays()) {
      _toast('فعّل «العرض فوق التطبيقات» ليظهر الأذان فوق أي تطبيق مفتوح.');
      await AzkariNative.requestOverlay();
      return;
    }
    if (!await AzkariNative.testAdhan(name,
        style: p.adhanStyle,
        display: p.adhanDisplay,
        soundPath: p.adhanSoundPath)) {
      _toast('تعذّر تشغيل الأذان التجريبي.');
    }
  }

  void _pickMethod(PrayerProvider p) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('طريقة الحساب',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            for (final m in calcMethods)
              ListTile(
                title: Text(m.name),
                subtitle: Text(m.summary),
                trailing: m.id == p.methodId ? const Icon(Icons.check) : null,
                onTap: () {
                  p.setMethod(m.id);
                  Navigator.of(ctx).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PrayerProvider>();
    final tk = HomeTokens.of(context);
    final mq = MediaQuery.of(context);
    final on = p.adhanEnabled;

    return MediaQuery(
      data: mq.copyWith(textScaler: mq.textScaler.clamp(maxScaleFactor: 1.15)),
      child: Scaffold(
        appBar: AppBar(title: const Text('إعدادات الصلاة')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 32),
          children: [
            _hero(p),
            const SizedBox(height: 22),
            Opacity(
              opacity: on ? 1 : .45,
              child: IgnorePointer(
                ignoring: !on,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const KitSectionTitle(
                        text: 'شكل شاشة الأذان',
                        caption: 'اختر التصميم الذي يظهر وقت الأذان'),
                    _stylePicker(p, tk),
                    const SizedBox(height: 22),
                    const KitSectionTitle(
                        text: 'صوت الأذان',
                        caption: 'الصوت الأساسي مدمج، والباقي تحمّله وقت ما تحب'),
                    _soundList(p, tk),
                    const SizedBox(height: 22),
                    const KitSectionTitle(
                        text: 'ظهور شاشة الأذان',
                        caption: 'الصوت يعمل في الحالتين'),
                    _displayPicker(p, tk),
                    const SizedBox(height: 22),
                    const KitSectionTitle(
                        text: 'التذكير قبل الصلاة',
                        caption: 'إشعار هادئ يسبق الأذان'),
                    _preReminder(p, tk),
                    const SizedBox(height: 22),
                    const KitSectionTitle(
                        text: 'تنبيه كل صلاة',
                        caption: 'أذان بصوت · إشعار بدون صوت · بدون تنبيه'),
                    _modes(p, tk),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            const KitSectionTitle(text: 'الحساب والتاريخ'),
            _calc(p, tk),
            const SizedBox(height: 14),
            Text(
              'تُحسب المواقيت فلكيًا على جهازك، وقد تختلف دقيقة أو دقيقتين '
              'عن التقويم الرسمي في بلدك. والتاريخ الهجري بالحساب الجدولي '
              'وقد يختلف يومًا عن الرؤية.',
              style: cairoStyle(12, color: tk.muted, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  // ───────── الهيرو: تفعيل الأذان + تجربة ─────────
  Widget _hero(PrayerProvider p) {
    return KitHero(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.mosque_rounded, color: kHeroGold, size: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Text('الأذان والتنبيهات',
                    style: cairoStyle(19, weight: 700, color: kHeroInk)),
              ),
              Switch(
                value: p.adhanEnabled,
                activeColor: kHeroGold,
                onChanged: (v) async {
                  final ok = await p.setAdhanEnabled(v);
                  if (!ok) _toast('اسمح بالإشعارات من إعدادات النظام أولًا.');
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            p.adhanEnabled
                ? 'الأذان مفعّل عند دخول كل صلاة'
                : 'الأذان متوقف، فعّله لتظهر باقي الخيارات',
            style: cairoStyle(13, color: kHeroSoft),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              KitHeroPill(
                  text: adhanStyles[p.adhanStyle].name,
                  icon: Icons.palette_outlined),
              KitHeroPill(
                  text: AdhanSounds.byId(p.adhanSoundId).name,
                  icon: Icons.music_note_rounded),
              if (p.preReminderMinutes > 0)
                KitHeroPill(
                    text: 'تذكير قبل ${_minLabel(p.preReminderMinutes)}',
                    icon: Icons.alarm_rounded),
            ],
          ),
          if (p.adhanEnabled) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => _testAdhan(p),
              style: OutlinedButton.styleFrom(
                foregroundColor: kHeroGold,
                side: const BorderSide(color: kHeroGold),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.play_circle_outline_rounded),
              label: Text('تجربة الأذان الآن',
                  style: cairoStyle(13.5, weight: 700, color: kHeroGold)),
            ),
          ],
        ],
      ),
    );
  }

  static String _minLabel(int m) =>
      m == 60 ? 'ساعة' : (m == 30 ? 'نصف ساعة' : '${toArabicDigits(m)} دقيقة');

  // ───────── أشكال شاشة الأذان ─────────
  Widget _stylePicker(PrayerProvider p, HomeTokens tk) {
    return SizedBox(
      height: 262,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: adhanStyles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final sel = p.adhanStyle == i;
          return GestureDetector(
            onTap: () => p.setAdhanStyle(i),
            child: SizedBox(
              width: 122,
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 210,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: sel ? tk.gold : tk.line, width: sel ? 2.5 : 1),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: 360,
                              height: 640,
                              child: MediaQuery(
                                data: MediaQuery.of(context).copyWith(
                                    padding: EdgeInsets.zero,
                                    textScaler: TextScaler.noScaling),
                                child: AdhanView(
                                    prayerName: 'الظهر',
                                    style: i,
                                    preview: true),
                              ),
                            ),
                          ),
                          if (sel)
                            Positioned(
                              top: 6,
                              right: 6,
                              child: CircleAvatar(
                                radius: 12,
                                backgroundColor: tk.gold,
                                child: const Icon(Icons.check,
                                    size: 16, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(adhanStyles[i].name,
                      style: cairoStyle(13, weight: sel ? 700 : 600, color: tk.ink)),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) =>
                            AdhanScreen(prayerName: 'الظهر', style: i))),
                    child: Text('معاينة كاملة',
                        style: cairoStyle(11.5, weight: 600, color: tk.gold)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ───────── أصوات الأذان ─────────
  Widget _soundList(PrayerProvider p, HomeTokens tk) {
    return KitCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < AdhanSounds.all.length; i++) ...[
            if (i > 0) const KitDivider(),
            _SoundRow(
              sound: AdhanSounds.all[i],
              p: p,
              playing: _playing == AdhanSounds.all[i].id,
              onPreview: () => _togglePreview(AdhanSounds.all[i].id),
              onToast: _toast,
            ),
          ],
        ],
      ),
    );
  }

  // ───────── وقت ظهور الشاشة ─────────
  Widget _displayPicker(PrayerProvider p, HomeTokens tk) {
    Widget opt(int v, IconData icon, String title, String sub, {bool rec = false}) {
      final sel = p.adhanDisplay == v;
      return KitCard(
        onTap: () async {
          if (v == adhanDisplayOverApps &&
              Platform.isAndroid &&
              !await AzkariNative.canDrawOverlays()) {
            _toast('فعّل «العرض فوق التطبيقات» لتطبيق ذكر ثم ارجع.');
            await AzkariNative.requestOverlay();
          }
          await p.setAdhanDisplay(v);
        },
        borderColor: sel ? tk.gold : null,
        color: sel ? tk.mint : null,
        child: Row(
          children: [
            KitIcon(
                icon: icon,
                size: 42,
                background: sel ? tk.gold : tk.mint,
                foreground: sel ? Colors.white : tk.mintInk),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(title,
                          style: cairoStyle(14.5, weight: 700, color: tk.ink)),
                    ),
                    if (rec) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 1),
                        decoration: BoxDecoration(
                          border: Border.all(color: tk.gold),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('موصى به',
                            style: cairoStyle(10.5, weight: 600, color: tk.gold)),
                      ),
                    ],
                  ]),
                  Text(sub,
                      style: cairoStyle(12.5, color: tk.muted, height: 1.5)),
                ],
              ),
            ),
            Icon(sel ? Icons.radio_button_checked : Icons.radio_button_off,
                color: sel ? tk.gold : tk.muted),
          ],
        ),
      );
    }

    return Column(children: [
      opt(adhanDisplayLockOnly, Icons.lock_outline_rounded, 'على شاشة القفل فقط',
          'ملء الشاشة والهاتف مقفل، وإشعار عادي لو تستخدم أي تطبيق فلا يقطع عليك',
          rec: true),
      const SizedBox(height: 10),
      opt(adhanDisplayOverApps, Icons.layers_outlined, 'فوق كل التطبيقات',
          'تظهر شاشة الأذان حتى لو كنت داخل تطبيق آخر'),
    ]);
  }

  // ───────── التذكير قبل الصلاة ─────────
  Widget _preReminder(PrayerProvider p, HomeTokens tk) {
    final on = p.preReminderMinutes > 0;
    return KitCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          KitTile(
            icon: Icons.alarm_rounded,
            title: 'ذكّرني قبل الصلاة',
            subtitle: on
                ? 'قبل كل صلاة بـ ${_minLabel(p.preReminderMinutes)}'
                : 'متوقف',
            trailing: Switch(
              value: on,
              onChanged: (v) => p.setPreReminder(v ? 60 : 0),
            ),
          ),
          if (on)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final m in const [15, 30, 60])
                    ChoiceChip(
                      label: Text(_minLabel(m)),
                      selected: p.preReminderMinutes == m,
                      onSelected: (_) => p.setPreReminder(m),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ───────── نمط تنبيه كل صلاة ─────────
  static const _prayers = [
    ('fajr', 'الفجر'),
    ('dhuhr', 'الظهر'),
    ('asr', 'العصر'),
    ('maghrib', 'المغرب'),
    ('isha', 'العشاء'),
  ];
  static const _gentle = {
    'fajr': 'الفجر نور يومك، لا تفوّت بركته',
    'dhuhr': 'استرح من شغلك بصلاة الظهر',
    'asr': 'حافظ على العصر فهي الصلاة الوسطى',
    'maghrib': 'عند الغروب لا تنسَ موعدك مع ربك',
    'isha': 'اختم يومك بالعشاء طمأنينةً لقلبك',
  };

  Widget _modes(PrayerProvider p, HomeTokens tk) {
    return KitCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        children: [
          for (final (id, name) in _prayers) ...[
            Row(
              children: [
                Expanded(
                  child: Text(name,
                      style: cairoStyle(14.5, weight: 700, color: tk.ink)),
                ),
                SegmentedButton<int>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                  segments: const [
                    ButtonSegment(
                        value: 0,
                        icon: Icon(Icons.volume_up_rounded, size: 18),
                        tooltip: 'أذان بصوت'),
                    ButtonSegment(
                        value: 1,
                        icon: Icon(Icons.notifications_none_rounded, size: 18),
                        tooltip: 'بدون صوت'),
                    ButtonSegment(
                        value: 2,
                        icon: Icon(Icons.notifications_off_outlined, size: 18),
                        tooltip: 'بدون تنبيه'),
                  ],
                  selected: {p.modeOf(id)},
                  onSelectionChanged: (s) => p.setPrayerMode(id, s.first),
                ),
              ],
            ),
            if (p.modeOf(id) == 2)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('لن يصلك تنبيه · ${_gentle[id]} 🤍',
                      style: cairoStyle(11.5, color: tk.gold)),
                ),
              ),
            if (id != 'isha') Divider(height: 14, color: tk.line),
          ],
        ],
      ),
    );
  }

  // ───────── الحساب والتاريخ ─────────
  Widget _calc(PrayerProvider p, HomeTokens tk) {
    return KitCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          KitTile(
            icon: Icons.calculate_outlined,
            title: 'طريقة الحساب',
            subtitle: p.method.name,
            onTap: () => _pickMethod(p),
          ),
          const KitDivider(),
          KitTile(
            icon: Icons.filter_2_outlined,
            title: 'العصر بالمذهب الحنفي',
            subtitle: 'ظل الشيء مثلاه بدل مثله',
            trailing: Switch(value: p.hanafi, onChanged: p.setHanafi),
          ),
          const KitDivider(),
          KitTile(
            icon: Icons.calendar_month_outlined,
            title: 'تصحيح التاريخ الهجري',
            subtitle: 'لموافقة الرؤية في بلدك',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                    onPressed: () => p.setHijriAdjust(p.hijriAdjust - 1),
                    icon: const Icon(Icons.remove_circle_outline)),
                Text(p.hijriAdjust == 0
                    ? '٠'
                    : (p.hijriAdjust > 0 ? '+' : '-') +
                        toArabicDigits(p.hijriAdjust.abs())),
                IconButton(
                    onPressed: () => p.setHijriAdjust(p.hijriAdjust + 1),
                    icon: const Icon(Icons.add_circle_outline)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// صف صوت: اختيار / تحميل (مع تقدّم) / استماع / حذف.
class _SoundRow extends StatefulWidget {
  final AdhanSound sound;
  final PrayerProvider p;
  final bool playing;
  final VoidCallback onPreview;
  final void Function(String) onToast;
  const _SoundRow(
      {required this.sound,
      required this.p,
      required this.playing,
      required this.onPreview,
      required this.onToast});

  @override
  State<_SoundRow> createState() => _SoundRowState();
}

class _SoundRowState extends State<_SoundRow> {
  late Future<bool> _ready = AdhanSounds.isAvailable(widget.sound.id);

  void _refresh() => setState(() => _ready = AdhanSounds.isAvailable(widget.sound.id));

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    final s = widget.sound;
    final p = widget.p;
    final selected = p.adhanSoundId == s.id;
    final progress = p.downloading[s.id];

    return FutureBuilder<bool>(
      future: _ready,
      builder: (context, snap) {
        final ready = snap.data ?? s.bundled;
        Widget action;
        if (progress != null) {
          action = SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(
                strokeWidth: 3, value: progress > 0 ? progress : null),
          );
        } else if (!ready) {
          action = OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: tk.gold,
                side: BorderSide(color: tk.gold)),
            onPressed: () async {
              final err = await p.downloadSound(s.id);
              _refresh();
              if (err != null) {
                widget.onToast(err);
              } else if (await p.selectSound(s.id)) {
                widget.onToast('تم التحميل واختيار «${s.name}»');
              }
            },
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('تحميل'),
          );
        } else {
          action = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!s.bundled)
                IconButton(
                  tooltip: widget.playing ? 'إيقاف' : 'استماع',
                  onPressed: widget.onPreview,
                  icon: Icon(
                      widget.playing
                          ? Icons.stop_circle_outlined
                          : Icons.play_circle_outline_rounded,
                      color: tk.gold),
                ),
              if (!s.bundled)
                IconButton(
                  tooltip: 'حذف من الجهاز',
                  onPressed: () async {
                    await p.deleteSound(s.id);
                    _refresh();
                  },
                  icon: Icon(Icons.delete_outline_rounded, color: tk.muted),
                ),
            ],
          );
        }
        return InkWell(
          onTap: ready && progress == null ? () => p.selectSound(s.id) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: selected ? tk.gold : tk.muted),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name,
                          style: cairoStyle(14, weight: 700, color: tk.ink)),
                      Text(s.desc,
                          style: cairoStyle(12, color: tk.muted)),
                    ],
                  ),
                ),
                action,
              ],
            ),
          ),
        );
      },
    );
  }
}
