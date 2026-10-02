import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/text_utils.dart';
import '../../data/quran_data.dart';
import '../../providers/quran_audio_provider.dart';
import '../../providers/quran_provider.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/support_app_button.dart';
import 'audio_player_ui.dart';

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
    final audio = context.watch<QuranAudioProvider>();
    final surahs =
        context.select<QuranProvider, List<Surah>?>((q) => q.data?.surahs);
    final visible = _visibleSurahs(audio);

    return Scaffold(
      appBar: AppBar(title: const Text('القرآن صوتيًا')),
      body: PatternBackground(
        opacity: 0.045,
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              sliver: SliverToBoxAdapter(child: _ReciterPanel(audio: audio)),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: SupportAppButton(compact: true),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    TextField(
                      controller: _search,
                      onChanged: (v) => setState(() => _query = v.trim()),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'ابحث باسم السورة أو رقمها',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'مسح',
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () => setState(() {
                                  _search.clear();
                                  _query = '';
                                }),
                              ),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text('كل السور'),
                          selected: !_favoritesOnly,
                          onSelected: (_) =>
                              setState(() => _favoritesOnly = false),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          avatar: const Icon(Icons.favorite_rounded, size: 16),
                          label: Text(audio.favorites.isEmpty
                              ? 'المفضلة'
                              : 'المفضلة (${toArabicDigits(audio.favorites.length)})'),
                          selected: _favoritesOnly,
                          onSelected: (_) =>
                              setState(() => _favoritesOnly = true),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (visible.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      _favoritesOnly && _query.isEmpty
                          ? 'لم تضف سورًا إلى المفضلة بعد. اضغط على القلب بجانب أي سورة.'
                          : 'لا توجد سورة بهذا الاسم.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    mainAxisExtent: 88,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final n = visible[i];
                      return _SurahTile(
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
              ),
          ],
        ),
      ),
      // المشغل ثابت أسفل الشاشة ولا يتحرك مع القائمة.
      bottomNavigationBar: const AudioMiniPlayer(),
    );
  }
}

class _ReciterPanel extends StatelessWidget {
  final QuranAudioProvider audio;
  const _ReciterPanel({required this.audio});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final reciter = audio.selectedReciter;

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

    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: scheme.surface,
                  child: Icon(Icons.mic_rounded, color: scheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(reciter.name,
                          style: text.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (audio.isReady) ...[
                            Icon(Icons.check_circle_rounded,
                                size: 15, color: scheme.primary),
                            const SizedBox(width: 4),
                          ],
                          Flexible(
                            child: Text(status,
                                style: text.bodySmall
                                    ?.copyWith(color: scheme.onSurfaceVariant)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed:
                      audio.isBusy ? null : () => _showReciterSheet(context),
                  child: const Text('تغيير'),
                ),
              ],
            ),
            if (audio.downloading) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  minHeight: 7,
                  value: audio.downloadProgress == 0
                      ? null
                      : audio.downloadProgress,
                  backgroundColor: scheme.surface,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      audio.totalBytes == 0
                          ? '${toArabicDigits((audio.downloadedBytes / 1048576).round())} ميجابايت'
                          : '${toArabicDigits((audio.downloadProgress * 100).round())}٪ · '
                              '${toArabicDigits((audio.downloadedBytes / 1048576).round())} من '
                              '${toArabicDigits((audio.totalBytes / 1048576).round())} ميجابايت',
                      style: text.bodySmall,
                    ),
                  ),
                  TextButton(
                      onPressed: audio.cancelDownload,
                      child: const Text('إلغاء')),
                ],
              ),
            ] else if (audio.extracting) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                    minHeight: 7, backgroundColor: scheme.surface),
              ),
            ] else if (!audio.isReady && reciter.available) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: audio.downloadPackage,
                  icon: const Icon(Icons.download_rounded),
                  label: Text(audio.hasAnyAudio
                      ? 'إعادة تنزيل التلاوة'
                      : 'تنزيل التلاوة'),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'تُنزَّل مرة واحدة (حتى ١٠٠ ميجابايت) وتعمل بعدها بدون إنترنت.',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
            if (audio.error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded,
                        color: scheme.onErrorContainer),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(audio.error!,
                          style: TextStyle(color: scheme.onErrorContainer)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<void> _showReciterSheet(BuildContext context) {
  final audio = context.read<QuranAudioProvider>();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text('اختر القارئ',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            ),
          ),
          for (final r in QuranAudioProvider.reciters)
            ListTile(
              leading: Icon(
                r.id == audio.selectedReciterId
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: r.id == audio.selectedReciterId
                    ? Theme.of(sheetContext).colorScheme.primary
                    : null,
              ),
              title: Text(r.name),
              subtitle: Text(r.available ? 'متاح للتنزيل' : 'سيتوفر قريبًا'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                await audio.selectReciter(r.id);
              },
            ),
        ],
      ),
    ),
  );
}

class _SurahTile extends StatelessWidget {
  final QuranAudioProvider audio;
  final int surah;
  final Surah? info;

  const _SurahTile({required this.audio, required this.surah, this.info});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final available = audio.hasSurah(surah);
    final current = audio.currentSurah == surah;
    final playing = current && audio.isPlaying;
    final favorite = audio.isFavorite(surah);

    final fill = current ? scheme.primaryContainer : scheme.surface;
    final border = current ? scheme.primary : scheme.outlineVariant;

    String? meta;
    if (info != null) {
      meta =
          '${info!.meccan ? 'مكية' : 'مدنية'} · ${toArabicDigits(info!.ayahCount)} آية';
    }

    return Opacity(
      opacity: available || !audio.hasAnyAudio ? 1.0 : 0.45,
      child: Material(
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: border, width: current ? 1.5 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _onTap(context, available, current),
          onLongPress: () => audio.toggleFavorite(surah),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(10, 8, 2, 8),
            child: Row(
              children: [
                StarBadge(
                  number: surah,
                  size: 40,
                  fill: current ? scheme.primary : scheme.primaryContainer,
                  textColor: current ? scheme.onPrimary : scheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        QuranAudioProvider.surahName(surah),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      if (meta != null)
                        Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
                if (current)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child:
                        EqualizerBars(animate: playing, color: scheme.primary),
                  ),
                SizedBox(
                  width: 34,
                  height: 34,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 20,
                    tooltip:
                        favorite ? 'إزالة من المفضلة' : 'إضافة إلى المفضلة',
                    onPressed: () => audio.toggleFavorite(surah),
                    icon: Icon(
                      favorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color:
                          favorite ? scheme.primary : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
          content: Text(reciter.available
              ? 'نزّل التلاوة أولًا للاستماع إلى هذه السورة'
              : 'تلاوة ${reciter.name} ستتوفر قريبًا'),
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
