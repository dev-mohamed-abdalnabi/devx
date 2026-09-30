import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/text_utils.dart';
import '../../core/theme.dart';
import '../../data/quran_data.dart';
import '../../providers/activity_provider.dart';
import '../../providers/quran_provider.dart';

class ReaderScreen extends StatefulWidget {
  final int page;
  final String? highlight;
  const ReaderScreen({super.key, required this.page, this.highlight});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late final PageController _controller;
  late int _page;
  String? _selected;
  Timer? _readTimer;

  @override
  void initState() {
    super.initState();
    _page = widget.page;
    _selected = widget.highlight;
    _controller = PageController(initialPage: _page - 1);
    _onPage(_page);
  }

  @override
  void dispose() {
    _readTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onPage(int page) {
    _readTimer?.cancel();
    final q = context.read<QuranProvider>();
    final act = context.read<ActivityProvider>();
    q.setLastPage(page);
    // تُحتسب الصفحة مقروءة بعد بقائها 6 ثوانٍ لتفادي احتساب التصفح السريع.
    _readTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) {
        q.markRead(page);
        act.addPage(page);
      }
    });
  }

  void _showAyahSheet(Ayah a) {
    setState(() => _selected = a.key);
    final q = context.read<QuranProvider>();
    final data = q.data!;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Consumer<QuranProvider>(
        builder: (ctx, q, _) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${displaySurahName(data.surahOf(a.surah).name)} · الآية ${toArabicDigits(a.number)}',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.copy_rounded),
                  title: const Text('نسخ الآية'),
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(
                        text: '${a.text} ﴿${toArabicDigits(a.number)}﴾ [${data.surahOf(a.surah).name}]'));
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text('تم نسخ الآية')));
                    }
                  },
                ),
                ListTile(
                  leading: Icon(q.isBookmarked(a.key) ? Icons.bookmark_rounded : Icons.bookmark_border_rounded),
                  title: Text(q.isBookmarked(a.key) ? 'إزالة العلامة' : 'حفظ علامة'),
                  onTap: () {
                    q.toggleBookmark(a.key);
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.push_pin_rounded),
                  title: const Text('اجعلها آخر موضع قراءة'),
                  onTap: () {
                    q.setLastPage(a.page, ayahKey: a.key);
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Consumer<QuranProvider>(
        builder: (ctx, q, _) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('حجم الخط', style: TextStyle(fontWeight: FontWeight.bold)),
                Slider(
                  value: q.fontSize,
                  min: 20,
                  max: 44,
                  divisions: 12,
                  label: toArabicDigits(q.fontSize.round()),
                  onChanged: q.setFontSize,
                ),
                const SizedBox(height: 8),
                const Text('لون الصفحة', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final e in const {
                      'auto': 'تلقائي',
                      'light': 'فاتح',
                      'dark': 'داكن',
                      'sepia': 'ورقي',
                    }.entries)
                      ChoiceChip(
                        label: Text(e.value),
                        selected: q.readerTheme == e.key,
                        onSelected: (_) => q.setReaderTheme(e.key),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = context.watch<QuranProvider>();
    final data = q.data!;
    final palette = ReaderPalette.byName(q.readerTheme, Theme.of(context).brightness);
    final pageAyahs = data.byPage[_page] ?? const <Ayah>[];
    final first = pageAyahs.isNotEmpty ? pageAyahs.first : null;
    final surahName = first == null ? '' : data.surahOf(first.surah).name;
    final juz = first?.juz ?? 1;

    return Scaffold(
      backgroundColor: palette.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'رجوع',
                    icon: Icon(Icons.arrow_forward, color: palette.fg),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      '${displaySurahName(surahName)} · الجزء ${toArabicDigits(juz)}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: palette.muted, fontSize: 15),
                    ),
                  ),
                  IconButton(
                    tooltip: 'إعدادات القراءة',
                    icon: Icon(Icons.text_fields, color: palette.fg),
                    onPressed: _showSettings,
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: data.pageCount,
                onPageChanged: (i) {
                  setState(() => _page = i + 1);
                  _onPage(i + 1);
                },
                itemBuilder: (ctx, i) => _MushafPage(
                  data: data,
                  page: i + 1,
                  fontSize: q.fontSize,
                  palette: palette,
                  selectedKey: _selected,
                  bookmarks: q.bookmarks,
                  onAyahTap: _showAyahSheet,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 4),
              child: Text(toArabicDigits(_page),
                  style: TextStyle(color: palette.muted, fontSize: 16, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MushafPage extends StatefulWidget {
  final QuranData data;
  final int page;
  final double fontSize;
  final ReaderPalette palette;
  final String? selectedKey;
  final Set<String> bookmarks;
  final void Function(Ayah) onAyahTap;

  const _MushafPage({
    required this.data,
    required this.page,
    required this.fontSize,
    required this.palette,
    required this.selectedKey,
    required this.bookmarks,
    required this.onAyahTap,
  });

  @override
  State<_MushafPage> createState() => _MushafPageState();
}

class _MushafPageState extends State<_MushafPage> {
  final List<TapGestureRecognizer> _recognizers = [];

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final p = widget.palette;
    final ayahs = widget.data.byPage[widget.page] ?? const <Ayah>[];
    final quranStyle = TextStyle(
      fontFamily: AppTheme.quranFont,
      fontSize: widget.fontSize,
      height: 2.1,
      color: p.fg,
    );

    final children = <Widget>[];
    var spans = <InlineSpan>[];

    void flush() {
      if (spans.isEmpty) return;
      children.add(Text.rich(
        TextSpan(children: spans, style: quranStyle),
        textAlign: TextAlign.justify,
        textDirection: TextDirection.rtl,
      ));
      spans = <InlineSpan>[];
    }

    for (final a in ayahs) {
      if (a.number == 1) {
        flush();
        children.add(_SurahBanner(name: widget.data.surahOf(a.surah).name, palette: p));
        if (a.surah != 1 && a.surah != 9) {
          children.add(Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(widget.data.basmala,
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: quranStyle.copyWith(fontSize: widget.fontSize * 0.95)),
          ));
        }
      }
      final rec = TapGestureRecognizer()..onTap = () => widget.onAyahTap(a);
      _recognizers.add(rec);
      final selected = widget.selectedKey == a.key;
      final marked = widget.bookmarks.contains(a.key);
      spans.add(TextSpan(
        text: a.text,
        recognizer: rec,
        style: selected ? TextStyle(backgroundColor: p.highlight) : null,
      ));
      spans.add(TextSpan(
        text: ' \uFD3F${toArabicDigits(a.number)}\uFD3E${marked ? ' ◆' : ''} ',
        style: TextStyle(color: p.accent, fontSize: widget.fontSize * 0.8),
      ));
    }
    flush();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

class _SurahBanner extends StatelessWidget {
  final String name;
  final ReaderPalette palette;
  const _SurahBanner({required this.name, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: palette.accent.withValues(alpha: 0.7), width: 1.2),
        ),
      ),
      child: Text(
        displaySurahName(name),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppTheme.quranFont,
          fontSize: 24,
          color: palette.accent,
        ),
      ),
    );
  }
}
