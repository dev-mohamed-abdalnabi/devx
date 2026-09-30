import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/text_utils.dart';
import '../../data/quran_data.dart';
import '../../providers/quran_provider.dart';
import '../../widgets/app_ui.dart';
import 'reader_screen.dart';

void openReader(BuildContext context, int page, {String? highlight}) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => ReaderScreen(page: page, highlight: highlight),
  ));
}

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

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _query = v.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = context.watch<QuranProvider>();
    if (q.loading) return const Center(child: CircularProgressIndicator());
    final data = q.data;
    if (data == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('تعذّر تحميل بيانات القرآن. أعد تشغيل التطبيق.',
              textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
        ),
      );
    }

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: AppSectionHeader(
              title: 'القرآن الكريم',
              subtitle: 'تابع وردك واقرأ براحة وطمأنينة',
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: CupertinoSearchTextField(
              controller: _controller,
              onChanged: _onChanged,
              placeholder: 'ابحث باسم السورة أو رقمها أو جزء من آية',
              prefixIcon: const Icon(CupertinoIcons.search),
              suffixIcon: const Icon(CupertinoIcons.xmark_circle_fill),
              suffixMode: OverlayVisibilityMode.editing,
              onSuffixTap: () {
                _controller.clear();
                setState(() => _query = '');
              },
            ),
          ),
          const SizedBox(height: 8),
          if (_query.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CupertinoSlidingSegmentedControl<bool>(
                groupValue: _byJuz,
                children: const {
                  false: Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('السور')),
                  true: Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('الأجزاء')),
                },
                onValueChanged: (value) {
                  if (value != null) setState(() => _byJuz = value);
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _byJuz ? _JuzList(data: data) : _SurahList(data: data, q: q)),
          ] else
            Expanded(child: _Results(data: data, query: _query)),
        ],
      ),
    );
  }
}

class _SurahList extends StatelessWidget {
  final QuranData data;
  final QuranProvider q;
  const _SurahList({required this.data, required this.q});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: data.surahs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final s = data.surahs[i];
        return AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          onTap: () => openReader(ctx, s.firstPage),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: scheme.primaryContainer,
                child: Text(toArabicDigits(s.number), style: TextStyle(color: scheme.primary, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displaySurahName(s.name), style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('${s.meccan ? 'مكية' : 'مدنية'} · ${toArabicDigits(s.ayahCount)} آية · صفحة ${toArabicDigits(s.firstPage)}'),
                ],
              )),
              const Icon(Icons.chevron_left_rounded),
            ],
          ),
        );
      },
    );
  }
}

class _JuzList extends StatelessWidget {
  final QuranData data;
  const _JuzList({required this.data});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: 30,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final page = data.juzStartPages[i];
        return AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          onTap: () => openReader(ctx, page),
          child: Row(
            children: [
              CircleAvatar(backgroundColor: scheme.primaryContainer, child: Text(toArabicDigits(i + 1), style: TextStyle(color: scheme.primary, fontWeight: FontWeight.bold))),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('الجزء ${toArabicDigits(i + 1)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('يبدأ من صفحة ${toArabicDigits(page)}'),
              ])),
              const Icon(Icons.chevron_left_rounded),
            ],
          ),
        );
      },
    );
  }
}

class _Results extends StatelessWidget {
  final QuranData data;
  final String query;
  const _Results({required this.data, required this.query});

  @override
  Widget build(BuildContext context) {
    final nq = normalizeArabic(query);
    final asNumber = int.tryParse(query);
    final surahHits = data.surahs.where((s) {
      if (asNumber != null) return s.number == asNumber;
      return normalizeArabic(s.name).contains(nq);
    }).toList();
    final ayahHits = asNumber == null ? data.searchAyahs(query) : const <Ayah>[];

    if (surahHits.isEmpty && ayahHits.isEmpty) {
      return const Center(child: Text('لا توجد نتائج مطابقة'));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        for (final s in surahHits)
          ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: Text(displaySurahName(s.name)),
            subtitle: Text('${toArabicDigits(s.ayahCount)} آية'),
            onTap: () => openReader(context, s.firstPage),
          ),
        if (ayahHits.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('آيات (${toArabicDigits(ayahHits.length)})',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        for (final a in ayahHits)
          ListTile(
            title: Text(a.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'AmiriQuran', fontSize: 19, height: 1.8)),
            subtitle: Text('${displaySurahName(data.surahOf(a.surah).name)} · آية ${toArabicDigits(a.number)}'),
            onTap: () => openReader(context, a.page, highlight: a.key),
          ),
      ],
    );
  }
}
