import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/home_tokens.dart';
import '../../core/text_utils.dart';
import '../../core/theme.dart';
import '../../data/quran_data.dart';
import '../../providers/quran_audio_provider.dart';
import '../../providers/quran_provider.dart';
import '../home/home_art.dart';

// ───────── أيقونات (viewBox 24) ─────────
const kIcBack = '<path d="M9 6l6 6-6 6"/>';
const kIcPrev = '<path d="M9 6l6 6-6 6"/>';
const kIcNext = '<path d="M15 6l-6 6 6 6"/>';
const kIcList = '<path d="M5 7h14M5 12h14M5 17h9"/>';
const kIcTune =
    '<path d="M4 7h10M18 7h2M4 17h2M10 17h10"/><circle cx="16" cy="7" r="2"/><circle cx="8" cy="17" r="2"/>';
const kIcCopy =
    '<rect x="8" y="8" width="12" height="12" rx="2"/><path d="M16 8V6a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h2"/>';
const kIcShare =
    '<circle cx="18" cy="5" r="2.5"/><circle cx="6" cy="12" r="2.5"/><circle cx="18" cy="19" r="2.5"/><path d="M8.2 10.8l7.6-4.6M8.2 13.2l7.6 4.6"/>';
const kIcMark = '<path d="M7 4h10v16l-5-4-5 4z"/>';
const kIcPin =
    '<path d="M12 21s-7-6-7-11a7 7 0 0 1 14 0c0 5-7 11-7 11z"/><circle cx="12" cy="10" r="2.5"/>';
const kIcCheck = '<path d="M5 12l4 4 10-10"/>';
const kIcClose = '<path d="M6 6l12 12M18 6L6 18"/>';
const kIcEdit = '<path d="M4 20h4l10-10-4-4L4 16zM13 7l4 4"/>';

/// ألوان العلامات (فهرس يُحفظ في QuranProvider).
const kMarkColors = <Color>[
  Color(0xFFD4AE5A), // ذهبي
  Color(0xFF6FAE5A), // أخضر
  Color(0xFF5B8DB8), // أزرق
  Color(0xFFC46A7A), // وردي
  Color(0xFF8E7BB5), // بنفسجي
];

// ───────── ثيم القارئ (نفس ألوان الرئيسية) ─────────
const _sepia = HomeTokens(
  bg: Color(0xFFF1E5C8),
  card: Color(0xFFF8EFD8),
  line: Color(0xFFDCCBA3),
  ink: Color(0xFF3B2F1E),
  muted: Color(0xFF8A7756),
  gold: Color(0xFF9A7424),
  mint: Color(0xFFE8DDB9),
  mintInk: Color(0xFF5C4A1E),
  leaf: Color(0xFF6FAE5A),
);

HomeTokens readerTokens(String name, Brightness app) {
  switch (name) {
    case 'light':
      return HomeTokens.light;
    case 'dark':
      return HomeTokens.dark;
    case 'sepia':
      return _sepia;
    default:
      return app == Brightness.dark ? HomeTokens.dark : HomeTokens.light;
  }
}

// ───────── نصوص مساعدة ─────────
String surahTitle(int n) => 'سورة ${QuranAudioProvider.surahName(n)}';

List<Ayah> sortedAyahs(Iterable<Ayah> l) {
  final out = l.toList()
    ..sort((a, b) => a.surah != b.surah ? a.surah.compareTo(b.surah) : a.number.compareTo(b.number));
  return out;
}

String refOf(List<Ayah> l) {
  final a = l.first, b = l.last;
  if (l.length == 1) return '${surahTitle(a.surah)} · الآية ${toArabicDigits(a.number)}';
  if (a.surah == b.surah) {
    return '${surahTitle(a.surah)} · الآيات ${toArabicDigits(a.number)}–${toArabicDigits(b.number)}';
  }
  return '${surahTitle(a.surah)} ${toArabicDigits(a.number)} ← ${surahTitle(b.surah)} ${toArabicDigits(b.number)}';
}

String ayahsText(List<Ayah> l) =>
    l.map((a) => '${a.text} \uFD3F${toArabicDigits(a.number)}\uFD3E').join(' ');

String copyText(List<Ayah> l) => '${ayahsText(l)}\n[${refOf(l)}]';

// ───────── مكوّنات صغيرة ─────────
class QTile extends StatelessWidget {
  final HomeTokens tk;
  final String icon, label;
  final VoidCallback onTap;
  final Color? iconColor;
  const QTile(
      {super.key,
      required this.tk,
      required this.icon,
      required this.label,
      required this.onTap,
      this.iconColor});

  @override
  Widget build(BuildContext context) {
    return PressableCard(
      onTap: onTap,
      builder: (context, pressed) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 74,
        decoration: BoxDecoration(
          color: tk.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: pressed ? tk.gold : tk.line),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HomeIcon(icon, size: 22, color: iconColor ?? tk.gold),
            const SizedBox(height: 6),
            Text(label, style: cairoStyle(12, weight: 600, color: tk.ink)),
          ],
        ),
      ),
    );
  }
}

class QButton extends StatelessWidget {
  final HomeTokens tk;
  final String label;
  final bool primary;
  final String? icon;
  final VoidCallback? onTap;
  const QButton(
      {super.key,
      required this.tk,
      required this.label,
      required this.onTap,
      this.primary = true,
      this.icon});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? .45 : 1,
      child: PressableCard(
        onTap: onTap ?? () {},
        builder: (context, pressed) => Container(
          height: 48,
          decoration: BoxDecoration(
            color: primary ? tk.mintInk : tk.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: pressed ? tk.gold : (primary ? tk.mintInk : tk.line)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                HomeIcon(icon!, size: 18, color: primary ? tk.mint : tk.gold),
                const SizedBox(width: 8),
              ],
              Text(label,
                  style: cairoStyle(14, weight: 700, color: primary ? tk.mint : tk.ink)),
            ],
          ),
        ),
      ),
    );
  }
}

class QPill extends StatelessWidget {
  final HomeTokens tk;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const QPill(
      {super.key,
      required this.tk,
      required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 38,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? tk.mint : tk.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? tk.gold : tk.line),
        ),
        child: Text(label,
            style: cairoStyle(13, weight: 600, color: selected ? tk.mintInk : tk.ink)),
      ),
    );
  }
}

class QCircleBtn extends StatelessWidget {
  final HomeTokens tk;
  final String icon;
  final VoidCallback onTap;
  const QCircleBtn({super.key, required this.tk, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: tk.card,
          border: Border.all(color: tk.line),
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.center,
        child: HomeIcon(icon, size: 18, color: tk.ink),
      ),
    );
  }
}

Future<T?> qSheet<T>(BuildContext context, HomeTokens tk, WidgetBuilder builder) =>
    showModalBottomSheet<T>(
      context: context,
      backgroundColor: tk.bg,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: builder,
    );

// ───────── قائمة الآية ─────────
Future<void> showAyahSheet(BuildContext context, HomeTokens tk, Ayah a,
    {required VoidCallback onMultiSelect}) {
  return qSheet<void>(
    context,
    tk,
    (ctx) => Consumer<QuranProvider>(builder: (ctx, q, _) {
      final mark = q.markOf(a.key);
      final hq = a.hizbQuarter;
      final hizb = hq >= 1 ? (hq - 1) ~/ 4 + 1 : 1;
      Widget row(String icon, String label, VoidCallback onTap) => GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(children: [
                HomeIcon(icon, size: 20, color: tk.gold),
                const SizedBox(width: 12),
                Text(label, style: cairoStyle(14, weight: 600, color: tk.ink)),
              ]),
            ),
          );
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${surahTitle(a.surah)} · ${toArabicDigits(a.number)}',
                  style: amiriStyle(24, bold: true, color: tk.ink)),
              Text(
                  'صفحة ${toArabicDigits(a.page)} · الجزء ${toArabicDigits(a.juz)} · الحزب ${toArabicDigits(hizb)}',
                  style: cairoStyle(12, color: tk.muted)),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  color: tk.mint,
                  child: Stack(children: [
                    const Positioned.fill(
                        child: CustomPaint(painter: IslamicPatternPainter(opacity: .22))),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: SizedBox(
                        width: double.infinity,
                        child: Text(a.text,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                                fontFamily: AppTheme.quranFont,
                                fontSize: 20,
                                height: 1.9,
                                color: tk.mintInk)),
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: QTile(
                        tk: tk,
                        icon: HomeIcons.quran,
                        label: 'تفسير',
                        onTap: () {
                          Navigator.pop(ctx);
                          showTafsirSheet(context, tk, a);
                        })),
                const SizedBox(width: 8),
                Expanded(
                    child: QTile(
                        tk: tk,
                        icon: kIcCopy,
                        label: 'نسخ',
                        onTap: () async {
                          Navigator.pop(ctx);
                          await Clipboard.setData(ClipboardData(text: copyText([a])));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(const SnackBar(content: Text('تم نسخ الآية')));
                          }
                        })),
                const SizedBox(width: 8),
                Expanded(
                    child: QTile(
                        tk: tk,
                        icon: kIcShare,
                        label: 'مشاركة',
                        onTap: () {
                          Navigator.pop(ctx);
                          showShareDialog(context, [a]);
                        })),
                const SizedBox(width: 8),
                Expanded(
                    child: QTile(
                        tk: tk,
                        icon: kIcMark,
                        label: mark == null ? 'علامة' : 'العلامة',
                        iconColor: mark == null
                            ? null
                            : kMarkColors[mark.color % kMarkColors.length],
                        onTap: () {
                          Navigator.pop(ctx);
                          showMarkEditor(context, tk, [a]);
                        })),
              ]),
              const SizedBox(height: 6),
              row(kIcPin, 'اجعلها آخر موضع قراءة', () {
                q.setLastPage(a.page, ayahKey: a.key);
                Navigator.pop(ctx);
              }),
              Divider(height: 1, color: tk.line),
              row(kIcCheck, 'تحديد عدة آيات', () {
                Navigator.pop(ctx);
                onMultiSelect();
              }),
            ],
          ),
        ),
      );
    }),
  );
}

// ───────── التفسير ─────────
Future<void> showTafsirSheet(BuildContext context, HomeTokens tk, Ayah a) {
  final q = context.read<QuranProvider>();
  return qSheet<void>(
    context,
    tk,
    (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .72,
      minChildSize: .4,
      maxChildSize: .95,
      builder: (ctx, sc) => _TafsirBody(tk: tk, start: q.ayahIndex(a), controller: sc),
    ),
  );
}

class _TafsirBody extends StatefulWidget {
  final HomeTokens tk;
  final int start;
  final ScrollController controller;
  const _TafsirBody({required this.tk, required this.start, required this.controller});

  @override
  State<_TafsirBody> createState() => _TafsirBodyState();
}

class _TafsirBodyState extends State<_TafsirBody> {
  late int _i = widget.start;
  late Future<String?> _f;

  Ayah get _ayah => context.read<QuranProvider>().data!.ayahs[_i];

  @override
  void initState() {
    super.initState();
    _f = context.read<QuranProvider>().tafsirOf(_ayah);
  }

  void _go(int d) {
    final q = context.read<QuranProvider>();
    final n = (_i + d).clamp(0, q.data!.ayahs.length - 1);
    if (n == _i) return;
    setState(() {
      _i = n;
      _f = q.tafsirOf(_ayah);
    });
    if (widget.controller.hasClients) widget.controller.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final tk = widget.tk;
    final a = _ayah;
    return SafeArea(
      top: false,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              controller: widget.controller,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              children: [
                Text('${surahTitle(a.surah)} · ${toArabicDigits(a.number)}',
                    style: amiriStyle(24, bold: true, color: tk.ink)),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    color: tk.mint,
                    child: Stack(children: [
                      const Positioned.fill(
                          child: CustomPaint(painter: IslamicPatternPainter(opacity: .22))),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: double.infinity,
                          child: Text(a.text,
                              textAlign: TextAlign.center,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                  fontFamily: AppTheme.quranFont,
                                  fontSize: 22,
                                  height: 1.95,
                                  color: tk.mintInk)),
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),
                Text('التفسير الميسّر', style: cairoStyle(12.5, weight: 700, color: tk.gold)),
                const SizedBox(height: 6),
                FutureBuilder<String?>(
                  future: _f,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      );
                    }
                    final t = snap.data;
                    if (t == null) {
                      return Text('التفسير غير متوفر حاليًا في هذا الإصدار.',
                          style: cairoStyle(13.5, color: tk.muted, height: 1.8));
                    }
                    return Text(t, style: cairoStyle(15.5, color: tk.ink, height: 2));
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(children: [
              Expanded(
                  child: QButton(
                      tk: tk,
                      primary: false,
                      icon: kIcPrev,
                      label: 'الآية السابقة',
                      onTap: _i > 0 ? () => _go(-1) : null)),
              const SizedBox(width: 10),
              Expanded(
                  child: QButton(
                      tk: tk,
                      primary: false,
                      icon: kIcNext,
                      label: 'الآية التالية',
                      onTap: () => _go(1))),
            ]),
          ),
        ],
      ),
    );
  }
}

// ───────── محرر العلامة ─────────
Future<void> showMarkEditor(BuildContext context, HomeTokens tk, List<Ayah> ayahs) {
  return qSheet<void>(
    context,
    tk,
    (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: _MarkBody(tk: tk, ayahs: ayahs),
    ),
  );
}

class _MarkBody extends StatefulWidget {
  final HomeTokens tk;
  final List<Ayah> ayahs;
  const _MarkBody({required this.tk, required this.ayahs});

  @override
  State<_MarkBody> createState() => _MarkBodyState();
}

class _MarkBodyState extends State<_MarkBody> {
  late int _color;
  late final TextEditingController _note;
  late final bool _anyExisting;

  bool get _single => widget.ayahs.length == 1;

  @override
  void initState() {
    super.initState();
    final q = context.read<QuranProvider>();
    final first = q.markOf(widget.ayahs.first.key);
    _color = first?.color ?? 0;
    _note = TextEditingController(text: _single ? (first?.note ?? '') : '');
    _anyExisting = widget.ayahs.any((a) => q.isBookmarked(a.key));
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final q = context.read<QuranProvider>();
    if (_single) {
      await q.saveMark(widget.ayahs.first.key, color: _color, note: _note.text);
    } else {
      await q.saveMarksColor(widget.ayahs.map((a) => a.key), _color);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _remove() async {
    await context.read<QuranProvider>().removeMarks(widget.ayahs.map((a) => a.key));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final tk = widget.tk;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_single ? 'علامة على الآية' : 'علامة على ${toArabicDigits(widget.ayahs.length)} آيات',
                style: amiriStyle(24, bold: true, color: tk.ink)),
            const SizedBox(height: 2),
            Text(refOf(sortedAyahs(widget.ayahs)), style: cairoStyle(12, color: tk.muted)),
            const SizedBox(height: 14),
            Row(
              children: [
                for (var i = 0; i < kMarkColors.length; i++) ...[
                  GestureDetector(
                    onTap: () => setState(() => _color = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: kMarkColors[i],
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: _color == i ? tk.ink : Colors.transparent, width: 2.5),
                      ),
                      child: _color == i
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                          : null,
                    ),
                  ),
                  if (i < kMarkColors.length - 1) const SizedBox(width: 12),
                ],
              ],
            ),
            if (_single) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _note,
                maxLines: 3,
                minLines: 2,
                style: cairoStyle(14, color: tk.ink),
                decoration: InputDecoration(
                  hintText: 'ملاحظة (اختياري)',
                  hintStyle: cairoStyle(14, color: tk.muted),
                  filled: true,
                  fillColor: tk.card,
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: tk.line)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: tk.line)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: tk.gold)),
                ),
              ),
            ],
            const SizedBox(height: 16),
            QButton(tk: tk, label: 'حفظ العلامة', onTap: _save),
            if (_anyExisting) ...[
              const SizedBox(height: 8),
              QButton(tk: tk, primary: false, label: 'إزالة العلامة', onTap: _remove),
            ],
          ],
        ),
      ),
    );
  }
}

// ───────── المشاركة كصورة ─────────
Future<void> showShareDialog(BuildContext context, List<Ayah> ayahs) {
  final list = sortedAyahs(ayahs);
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => _ShareDialog(ayahs: list),
  );
}

class _ShareDialog extends StatefulWidget {
  final List<Ayah> ayahs;
  const _ShareDialog({required this.ayahs});

  @override
  State<_ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<_ShareDialog> {
  final GlobalKey _key = GlobalKey();
  bool _busy = false;

  String get _text => ayahsText(widget.ayahs);
  String get _ref => refOf(widget.ayahs);
  bool get _tooLong => _text.length > 900;

  Future<void> _shareImage() async {
    setState(() => _busy = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final b = _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 3);
      final bd = await img.toByteData(format: ui.ImageByteFormat.png);
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/zikr_ayah_${DateTime.now().millisecondsSinceEpoch}.png');
      await f.writeAsBytes(bd!.buffer.asUint8List());
      await Share.shareXFiles([XFile(f.path)], text: _ref);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تعذّرت مشاركة الصورة')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RepaintBoundary(
              key: _key,
              child: ShareCard(text: _text, refText: _ref),
            ),
            const SizedBox(height: 14),
            if (_tooLong)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text('النص طويل للصورة، شاركه كنص.',
                    textAlign: TextAlign.center,
                    style: cairoStyle(12.5, color: Colors.white)),
              ),
            Row(children: [
              Expanded(
                child: QButton(
                  tk: tk,
                  icon: kIcShare,
                  label: _busy ? 'جارٍ التجهيز…' : 'مشاركة كصورة',
                  onTap: (_busy || _tooLong) ? null : _shareImage,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: QButton(
                  tk: tk,
                  primary: false,
                  icon: kIcCopy,
                  label: 'كنص',
                  onTap: () {
                    Share.share('$_text\n\n[$_ref]');
                  },
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

/// بطاقة الآية (دائمًا بألوان الفاتح لتبدو موحّدة عند المشاركة).
class ShareCard extends StatelessWidget {
  final String text, refText;
  const ShareCard({super.key, required this.text, required this.refText});

  @override
  Widget build(BuildContext context) {
    const tk = HomeTokens.light;
    final len = text.length;
    final fs = len < 80 ? 28.0 : (len < 180 ? 23.0 : (len < 350 ? 19.0 : 16.0));
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: 340,
        color: tk.bg,
        child: Stack(
          children: [
            const Positioned.fill(
                child: CustomPaint(painter: IslamicPatternPainter(opacity: .12))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('ذِكر', style: amiriStyle(24, bold: true, color: tk.gold)),
                  const SizedBox(height: 12),
                  CustomPaint(
                    foregroundPainter: DashedBorderPainter(color: tk.gold, radius: 18),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
                      child: Text('\uFD3F $text \uFD3E',
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                              fontFamily: AppTheme.quranFont,
                              fontSize: fs,
                              height: 2,
                              color: tk.ink,
                              decoration: TextDecoration.none)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(refText,
                      textAlign: TextAlign.center,
                      style: cairoStyle(13, weight: 600, color: tk.gold)
                          .copyWith(decoration: TextDecoration.none)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
