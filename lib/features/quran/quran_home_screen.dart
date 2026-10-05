import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/home_tokens.dart';
import '../../core/text_utils.dart';
import '../../data/quran_data.dart';
import '../../providers/quran_provider.dart';
import '../../providers/quran_audio_provider.dart';
import '../../widgets/home_style.dart';
import '../home/home_art.dart';
import '../more/bookmarks_screen.dart';
import 'audio_player_ui.dart' show StarBadge;
import 'reader_screen.dart';

void openReader(BuildContext context, int page, {String? highlight}) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => ReaderScreen(page: page, highlight: highlight),
  ));
}

/// صفحة القرآن الكريم — بنفس ألوان ونسب وكروت الشاشة الرئيسية.
class QuranHomeScreen extends StatefulWidget {
  const QuranHomeScreen({super.key});

  @override
  State<QuranHomeScreen> createState() => _QuranHomeScreenState();
}

class _QuranHomeScreenState extends State<QuranHomeScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  bool _byJuz = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // يحفظ حالة/تركيز حقل البحث عند التبديل بين الشبكة ونتائج البحث (لتبقى لوحة المفاتيح مفتوحة).
  final GlobalKey _searchKey = GlobalKey();

  void _onChanged(String v) {
    setState(() {}); // لإظهار/إخفاء زر المسح فورًا
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _query = v.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    final mq = MediaQuery.of(context);
    final q = context.watch<QuranProvider>();
    final data = q.data;

    // الهيدر + البحث + الفلاتر جزء من المحتوى: يطلعوا مع التمرير.
    Widget content;
    if (q.loading) {
      content = Column(children: [
        const PageHeader(title: 'القرآن الكريم'),
        Expanded(
            child: Center(child: CircularProgressIndicator(color: tk.leaf))),
      ]);
    } else if (data == null) {
      content = Column(children: [
        const PageHeader(title: 'القرآن الكريم'),
        Expanded(
          child: HomeEmpty(
            tk: tk,
            icon: HomeIcons.quran,
            title: 'تعذّر تحميل بيانات القرآن',
            message: 'أعد تشغيل التطبيق',
          ),
        ),
      ]);
    } else {
      final top = <Widget>[
        PageHeader(
          title: 'القرآن الكريم',
          actions: [
            HeaderButton(
              icon: '<path d="M6 4h12v17l-6-4-6 4z"/>',
              label: 'علامات القرآن',
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BookmarksScreen())),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (_query.isEmpty &&
            (q.readPages.isNotEmpty ||
                q.lastAyahKey != null ||
                q.lastPage > 1)) ...[
          _ContinueCard(tk: tk, data: data, q: q),
          const SizedBox(height: 12),
        ],
        HomeSearchField(
          key: _searchKey,
          tk: tk,
          controller: _controller,
          hint: 'ابحث باسم السورة أو رقمها أو جزء من آية',
          onChanged: _onChanged,
          onClear: () {
            _controller.clear();
            setState(() => _query = '');
          },
        ),
        const SizedBox(height: 10),
        if (_query.isEmpty) ...[
          Row(
            children: [
              HomeChip(
                  tk: tk,
                  label: 'السور',
                  selected: !_byJuz,
                  onTap: () => setState(() => _byJuz = false)),
              const SizedBox(width: 8),
              HomeChip(
                  tk: tk,
                  label: 'الأجزاء',
                  selected: _byJuz,
                  onTap: () => setState(() => _byJuz = true)),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ];
      if (_query.isNotEmpty) {
        content = _Results(tk: tk, data: data, query: _query, top: top);
      } else {
        content = _byJuz
            ? _JuzGrid(tk: tk, data: data, top: top)
            : _SurahGrid(tk: tk, data: data, top: top);
      }
    }

    return MediaQuery(
      data: mq.copyWith(textScaler: mq.textScaler.clamp(maxScaleFactor: 1.15)),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: content,
        ),
      ),
    );
  }
}

const _grid = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 2,
  mainAxisSpacing: 10,
  crossAxisSpacing: 10,
  mainAxisExtent: 112,
);

const _surahGrid = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 2,
  mainAxisSpacing: 10,
  crossAxisSpacing: 10,
  mainAxisExtent: 84,
);

/// السورة التي تقع فيها الصفحة [page].
Surah _surahAtPage(QuranData data, int page) {
  var cur = data.surahs.first;
  for (final s in data.surahs) {
    if (s.firstPage <= page) {
      cur = s;
    } else {
      break;
    }
  }
  return cur;
}

class _SurahGrid extends StatelessWidget {
  final HomeTokens tk;
  final QuranData data;
  final List<Widget> top;
  const _SurahGrid({required this.tk, required this.data, required this.top});

  @override
  Widget build(BuildContext context) {
    final lastPage = context.select<QuranProvider, int>((q) => q.lastPage);
    final hasProgress = context.select<QuranProvider, bool>((q) =>
        q.readPages.isNotEmpty || q.lastAyahKey != null || q.lastPage > 1);
    final currentSurah = hasProgress ? _surahAtPage(data, lastPage).number : -1;
    return CustomScrollView(
      slivers: [
        SliverList(delegate: SliverChildListDelegate(top)),
        SliverPadding(
          padding: const EdgeInsets.only(bottom: 16),
          sliver: SliverGrid(
            gridDelegate: _surahGrid,
            delegate: SliverChildBuilderDelegate(
              childCount: data.surahs.length,
              (ctx, i) {
                final s = data.surahs[i];
                return _SurahCard(
                  tk: tk,
                  surah: s,
                  current: s.number == currentSurah,
                  onTap: () => openReader(ctx, s.firstPage),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _JuzGrid extends StatelessWidget {
  final HomeTokens tk;
  final QuranData data;
  final List<Widget> top;
  const _JuzGrid({required this.tk, required this.data, required this.top});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverList(delegate: SliverChildListDelegate(top)),
        SliverPadding(
          padding: const EdgeInsets.only(bottom: 16),
          sliver: SliverGrid(
            gridDelegate: _grid,
            delegate: SliverChildBuilderDelegate(
              childCount: 30,
              (ctx, i) {
                final page = data.juzStartPages[i];
                return NumberCard(
                  tk: tk,
                  number: i + 1,
                  title: 'الجزء ${toArabicDigits(i + 1)}',
                  subtitle: 'صفحة ${toArabicDigits(page)}',
                  onTap: () => openReader(ctx, page),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _Results extends StatelessWidget {
  final HomeTokens tk;
  final QuranData data;
  final String query;
  final List<Widget> top;
  const _Results(
      {required this.tk,
      required this.data,
      required this.query,
      required this.top});

  @override
  Widget build(BuildContext context) {
    final nq = normalizeArabic(query);
    final asNumber = int.tryParse(query);
    final surahHits = data.surahs.where((s) {
      if (asNumber != null) return s.number == asNumber;
      return normalizeArabic(s.name).contains(nq);
    }).toList();
    final ayahHits =
        asNumber == null ? data.searchAyahs(query) : const <Ayah>[];

    if (surahHits.isEmpty && ayahHits.isEmpty) {
      return Column(children: [
        ...top,
        Expanded(
          child: HomeEmpty(
              tk: tk, icon: ZikrIcons.search, title: 'لا توجد نتائج مطابقة'),
        ),
      ]);
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        ...top,
        for (final s in surahHits)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ResultRow(
              tk: tk,
              icon: HomeIcons.quran,
              title: QuranAudioProvider.surahName(s.number),
              subtitle: '${toArabicDigits(s.ayahCount)} آية',
              onTap: () => openReader(context, s.firstPage),
            ),
          ),
        if (ayahHits.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 2, 2, 8),
            child: Text('آيات (${toArabicDigits(ayahHits.length)})',
                style: cairoStyle(12.5, weight: 700, color: tk.gold)),
          ),
        for (final a in ayahHits)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ResultRow(
              tk: tk,
              title: a.text,
              quranTitle: true,
              subtitle:
                  '${QuranAudioProvider.surahName(a.surah)} · آية ${toArabicDigits(a.number)}',
              onTap: () => openReader(context, a.page, highlight: a.key),
            ),
          ),
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  final HomeTokens tk;
  final String? icon;
  final String title;
  final String subtitle;
  final bool quranTitle;
  final VoidCallback onTap;
  const _ResultRow({
    required this.tk,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.icon,
    this.quranTitle = false,
  });

  @override
  Widget build(BuildContext context) {
    return PressableCard(
      onTap: onTap,
      builder: (context, pressed) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: tk.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: pressed ? tk.gold : tk.line),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              HomeIcon(icon!, size: 24, color: tk.gold),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: quranTitle
                        ? const TextStyle(
                                fontFamily: 'AmiriQuran',
                                fontSize: 19,
                                height: 1.8)
                            .copyWith(color: tk.ink)
                        : cairoStyle(16, weight: 700, color: tk.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: cairoStyle(11.5, weight: 600, color: tk.gold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// كارت سورة مضغوط: نجمة الرقم + الاسم + النوع وعدد الآيات + رقم الصفحة.
class _SurahCard extends StatelessWidget {
  final HomeTokens tk;
  final Surah surah;
  final bool current;
  final VoidCallback onTap;
  const _SurahCard({
    required this.tk,
    required this.surah,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableCard(
      onTap: onTap,
      builder: (context, pressed) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: current ? tk.mint : tk.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: (pressed || current) ? tk.gold : tk.line),
        ),
        child: Row(
          children: [
            StarBadge(
              number: surah.number,
              size: 44,
              fill: current ? tk.card : tk.mint,
              textColor: tk.mintInk,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    QuranAudioProvider.surahName(surah.number),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: cairoStyle(16,
                        weight: 700, color: tk.ink, height: 1.25),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${surah.meccan ? 'مكية' : 'مدنية'} · ${toArabicDigits(surah.ayahCount)} آية',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: cairoStyle(11.5, color: tk.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            if (current)
              Icon(Icons.bookmark_rounded, size: 20, color: tk.gold)
            else
              Text('ص ${toArabicDigits(surah.firstPage)}',
                  style: cairoStyle(11, weight: 600, color: tk.gold)),
          ],
        ),
      ),
    );
  }
}

/// «أكمل القراءة»: آخر موضع + نسبة الختمة.
class _ContinueCard extends StatelessWidget {
  final HomeTokens tk;
  final QuranData data;
  final QuranProvider q;
  const _ContinueCard({required this.tk, required this.data, required this.q});

  @override
  Widget build(BuildContext context) {
    final page = q.lastPage;
    final surah = _surahAtPage(data, page);
    final progress = q.khatmaProgress.clamp(0.0, 1.0);
    final pct = (progress * 100).round();
    return PressableCard(
      onTap: () => openReader(context, page, highlight: q.lastAyahKey),
      builder: (context, pressed) => Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: tk.mint,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: tk.gold.withValues(alpha: pressed ? 1 : .55)),
        ),
        child: Row(
          children: [
            StarBadge(
              number: surah.number,
              size: 50,
              fill: tk.card,
              textColor: tk.mintInk,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('أكمل القراءة',
                      style: cairoStyle(11.5, weight: 700, color: tk.gold)),
                  Text('سورة ${QuranAudioProvider.surahName(surah.number)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: cairoStyle(17,
                          weight: 700, color: tk.mintInk, height: 1.3)),
                  Text(
                      'صفحة ${toArabicDigits(page)} من ${toArabicDigits(data.pageCount)}',
                      style: cairoStyle(12,
                          color: tk.mintInk.withValues(alpha: .75))),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 50,
              height: 50,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 50,
                    height: 50,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 4,
                      backgroundColor: tk.card,
                      color: tk.gold,
                    ),
                  ),
                  Text('${toArabicDigits(pct)}٪',
                      style: cairoStyle(11.5, weight: 700, color: tk.mintInk)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
