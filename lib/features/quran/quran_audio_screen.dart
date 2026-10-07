import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/home_tokens.dart';
import '../../core/text_utils.dart';
import '../../data/quran_data.dart';
import '../../providers/quran_audio_provider.dart';
import '../../providers/quran_provider.dart';
import '../../widgets/home_style.dart';
import '../home/home_art.dart';
import 'audio_player_ui.dart';

/// القرآن صوتيًا — بنفس ألوان ونسب وكروت الشاشة الرئيسية.
class QuranAudioScreen extends StatefulWidget {
  const QuranAudioScreen({super.key});

  @override
  State<QuranAudioScreen> createState() => _QuranAudioScreenState();
}

class _QuranAudioScreenState extends State<QuranAudioScreen> {
  final _search = TextEditingController();
  String _query = '';
  bool _favoritesOnly = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<int> _visibleSurahs(QuranAudioProvider audio) {
    final q = normalizeArabic(_query);
    return [
      for (var n = 1; n <= QuranAudioProvider.surahCount; n++)
        if ((!_favoritesOnly || audio.isFavorite(n)) &&
            (q.isEmpty ||
                normalizeArabic(QuranAudioProvider.surahName(n)).contains(q) ||
                '$n' == q ||
                toArabicDigits(n) == q))
          n,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    final mq = MediaQuery.of(context);
    final audio = context.watch<QuranAudioProvider>();
    final surahs =
        context.select<QuranProvider, List<Surah>?>((q) => q.data?.surahs);
    final visible = _visibleSurahs(audio);

    return Scaffold(
      body: MediaQuery(
        data: mq.copyWith(textScaler: mq.textScaler.clamp(maxScaleFactor: 1.15)),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: [
                const PageHeader(title: 'القرآن صوتيًا'),
                Expanded(
                  child: CustomScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    slivers: [
                      const SliverToBoxAdapter(child: SizedBox(height: 6)),
                      SliverToBoxAdapter(
                          child: _ReciterPanel(tk: tk, audio: audio)),
                      if (QuranAudioProvider.backgroundInitError != null)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: _Notice(
                              tk: tk,
                              text:
                                  'إشعار التحكم في التلاوة غير مفعّل بسبب خطأ في خدمة الخلفية:\n${QuranAudioProvider.backgroundInitError}',
                              ltr: true,
                            ),
                          ),
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 10)),
                      SliverToBoxAdapter(
                        child: HomeSearchField(
                          tk: tk,
                          controller: _search,
                          hint: 'ابحث باسم السورة أو رقمها',
                          onChanged: (v) => setState(() => _query = v.trim()),
                          onClear: () => setState(() {
                            _search.clear();
                            _query = '';
                          }),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 10)),
                      SliverToBoxAdapter(
                        child: Row(
                          children: [
                            HomeChip(
                              tk: tk,
                              label: 'كل السور',
                              selected: !_favoritesOnly,
                              onTap: () =>
                                  setState(() => _favoritesOnly = false),
                            ),
                            const SizedBox(width: 8),
                            HomeChip(
                              tk: tk,
                              label: audio.favorites.isEmpty
                                  ? 'المفضلة'
                                  : 'المفضلة (${toArabicDigits(audio.favorites.length)})',
                              selected: _favoritesOnly,
                              onTap: () =>
                                  setState(() => _favoritesOnly = true),
                            ),
                          ],
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 10)),
                      if (visible.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: HomeEmpty(
                            tk: tk,
                            icon: _favoritesOnly && _query.isEmpty
                                ? HomeIcons.heart
                                : ZikrIcons.search,
                            title: _favoritesOnly && _query.isEmpty
                                ? 'لم تضف سورًا إلى المفضلة بعد'
                                : 'لا توجد سورة بهذا الاسم',
                            message: _favoritesOnly && _query.isEmpty
                                ? 'اضغط على القلب بجانب أي سورة'
                                : null,
                          ),
                        )
                      else
                        SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
  maxCrossAxisExtent: 240,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            mainAxisExtent: 112,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, i) {
                              final n = visible[i];
                              return _SurahTile(
                                tk: tk,
                                audio: audio,
                                surah: n,
                                info: surahs != null && n <= surahs.length
                                    ? surahs[n - 1]
                                    : null,
                              );
                            },
                            childCount: visible.length,
                          ),
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      // المشغل ثابت أسفل الشاشة ولا يتحرك مع القائمة.
      bottomNavigationBar: const AudioMiniPlayer(),
    );
  }
}

/// رسالة تنبيه/خطأ بشكل الكروت.
class _Notice extends StatelessWidget {
  final HomeTokens tk;
  final String text;
  final bool ltr;
  const _Notice({required this.tk, required this.text, this.ltr = false});

  @override
  Widget build(BuildContext context) {
    const err = Color(0xFFB3423A);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tk.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: err.withValues(alpha: .6)),
      ),
      child: Text(
        text,
        textDirection: ltr ? TextDirection.ltr : null,
        style: cairoStyle(12, weight: 600, color: err, height: 1.5),
      ),
    );
  }
}

class _ReciterPanel extends StatelessWidget {
  final HomeTokens tk;
  final QuranAudioProvider audio;
  const _ReciterPanel({required this.tk, required this.audio});

  @override
  Widget build(BuildContext context) {
    final reciter = audio.selectedReciter;
    final sub = tk.mintInk.withValues(alpha: .75);

    String status;
    if (audio.extracting) {
      status = 'جارٍ تجهيز السور…';
    } else if (audio.downloading) {
      status = 'جارٍ التنزيل';
    } else if (audio.isReady) {
      status = 'جاهزة · ${toArabicDigits(QuranAudioProvider.surahCount)} سورة';
    } else if (audio.hasAnyAudio) {
      status =
          '${toArabicDigits(audio.availableCount)} من ${toArabicDigits(QuranAudioProvider.surahCount)} سورة';
    } else if (!reciter.available) {
      status = 'سيتوفر قريبًا';
    } else {
      status = 'لم تُنزَّل بعد';
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        color: tk.mint,
        child: Stack(
          children: [
            const Positioned.fill(
              child: CustomPaint(painter: IslamicPatternPainter(opacity: .22)),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: tk.card,
                          shape: BoxShape.circle,
                          border: Border.all(color: tk.line),
                        ),
                        child: Center(
                            child: StyledIcon(ZikrIcons.mic,
                                size: 22, color: tk.gold)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(reciter.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: amiriStyle(22,
                                    bold: true,
                                    color: tk.mintInk,
                                    height: 1.2)),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                if (audio.isReady) ...[
                                  StyledIcon(ZikrIcons.check,
                                      size: 14, color: tk.leaf),
                                  const SizedBox(width: 4),
                                ],
                                Flexible(
                                  child: Text(status,
                                      style: cairoStyle(11.5, color: sub)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: audio.isBusy
                            ? null
                            : () => _showReciterSheet(context),
                        child: Opacity(
                          opacity: audio.isBusy ? .45 : 1,
                          child: Container(
                            height: 34,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: tk.card,
                              borderRadius: BorderRadius.circular(17),
                              border: Border.all(color: tk.line),
                            ),
                            child: Text('تغيير',
                                style: cairoStyle(13,
                                    weight: 600, color: tk.ink)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (audio.downloading) ...[
                    const SizedBox(height: 12),
                    HomeProgressBar(
                        value: audio.downloadProgress, tokens: tk),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            audio.totalBytes == 0
                                ? '${toArabicDigits((audio.downloadedBytes / 1048576).round())} ميجابايت'
                                : '${toArabicDigits((audio.downloadProgress * 100).round())}٪ · '
                                    '${toArabicDigits((audio.downloadedBytes / 1048576).round())} من '
                                    '${toArabicDigits((audio.totalBytes / 1048576).round())} ميجابايت',
                            style: cairoStyle(11.5, color: sub),
                          ),
                        ),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: audio.cancelDownload,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 4),
                            child: Text('إلغاء',
                                style: cairoStyle(13,
                                    weight: 700, color: tk.mintInk)),
                          ),
                        ),
                      ],
                    ),
                  ] else if (audio.extracting) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        minHeight: 6,
                        color: tk.leaf,
                        backgroundColor: tk.line,
                      ),
                    ),
                  ] else if (!audio.isReady && reciter.available) ...[
                    const SizedBox(height: 12),
                    HomeButton(
                      tk: tk,
                      label: audio.hasAnyAudio
                          ? 'إعادة تنزيل التلاوة'
                          : 'تنزيل التلاوة',
                      onTap: audio.downloadPackage,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'تُنزَّل مرة واحدة (حتى ١٠٠ ميجابايت) للاستماع إليها لاحقًا.',
                      style: cairoStyle(11.5, color: sub),
                    ),
                  ],
                  if (audio.error != null) ...[
                    const SizedBox(height: 10),
                    _Notice(tk: tk, text: audio.error!),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showReciterSheet(BuildContext context) {
  final audio = context.read<QuranAudioProvider>();
  final tk = HomeTokens.of(context);
  return showHomeSheet<void>(
    context,
    builder: (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('اختر القارئ', style: amiriStyle(24, bold: true, color: tk.ink)),
        const SizedBox(height: 8),
        for (final r in QuranAudioProvider.reciters)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () async {
              Navigator.of(sheetContext).pop();
              await audio.selectReciter(r.id);
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: r.id == audio.selectedReciterId ? tk.mint : tk.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: r.id == audio.selectedReciterId ? tk.gold : tk.line),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.name,
                            style: cairoStyle(15,
                                weight: 700,
                                color: r.id == audio.selectedReciterId
                                    ? tk.mintInk
                                    : tk.ink)),
                        Text(r.available ? 'متاح للتنزيل' : 'سيتوفر قريبًا',
                            style: cairoStyle(11.5, color: tk.muted)),
                      ],
                    ),
                  ),
                  if (r.id == audio.selectedReciterId)
                    StyledIcon(ZikrIcons.check, size: 20, color: tk.leaf),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

class _SurahTile extends StatelessWidget {
  final HomeTokens tk;
  final QuranAudioProvider audio;
  final int surah;
  final Surah? info;

  const _SurahTile(
      {required this.tk, required this.audio, required this.surah, this.info});

  @override
  Widget build(BuildContext context) {
    final available = audio.hasSurah(surah);
    final current = audio.currentSurah == surah;
    final playing = current && audio.isPlaying;
    final favorite = audio.isFavorite(surah);

    String? meta;
    if (info != null) {
      meta =
          '${info!.meccan ? 'مكية' : 'مدنية'} · ${toArabicDigits(info!.ayahCount)} آية';
    }

    return Opacity(
      opacity: available || !audio.hasAnyAudio ? 1.0 : 0.45,
      child: NumberCard(
        tk: tk,
        number: surah,
        title: QuranAudioProvider.surahName(surah),
        subtitle: meta,
        selected: current,
        onTap: () => _onTap(context, available, current),
        onLongPress: () => audio.toggleFavorite(surah),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (current)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: EqualizerBars(animate: playing, color: tk.leaf),
              ),
            Semantics(
              label: favorite ? 'إزالة من المفضلة' : 'إضافة إلى المفضلة',
              button: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => audio.toggleFavorite(surah),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 4, 0, 6),
                  child: StyledIcon(
                    HomeIcons.heart,
                    size: 22,
                    color: tk.gold,
                    fill: favorite ? tk.gold : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onTap(BuildContext context, bool available, bool current) {
    if (audio.extracting) return;
    if (!available) {
      final reciter = audio.selectedReciter;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          backgroundColor: tk.card,
          behavior: SnackBarBehavior.floating,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: tk.line),
          ),
          content: Text(
              reciter.available
                  ? 'نزّل التلاوة أولًا للاستماع إلى هذه السورة'
                  : 'تلاوة ${reciter.name} ستتوفر قريبًا',
              style: cairoStyle(13, weight: 600, color: tk.ink)),
        ));
      return;
    }
    if (current) {
      audio.togglePlay();
    } else {
      audio.playSurah(surah);
    }
  }
}
