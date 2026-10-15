import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/home_tokens.dart';
import '../../core/text_utils.dart';
import '../../providers/azkar_provider.dart';
import '../../widgets/home_style.dart';
import '../home/home_art.dart';

/// مكوّنات مشتركة لشاشات المكتبة والأحكام الفقهية، بنفس لغة الرئيسية
/// (بطاقة card، radius 18، إطار line، نص Amiri، مصدر ذهبي Cairo).

Future<void> copyToClipboard(BuildContext context, String text) async {
  final tk = HomeTokens.of(context);
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      backgroundColor: tk.card,
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      duration: const Duration(seconds: 1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: tk.line),
      ),
      content:
          Text('تم النسخ', style: cairoStyle(13, weight: 600, color: tk.ink)),
    ));
}

/// بطاقة نص (حديث أو فقرة فقهية): نص + سطر مصدر + نسخ ومشاركة.
class TextCard extends StatefulWidget {
  final String text;
  final String? source; // سطر ذهبي تحت النص
  final String shareFooter; // يُلحق بالنسخ والمشاركة (نسبة النص لمصدره)
  final double baseSize;
  final bool actions; // false: بلا شريط نسخ/مشاركة (القراءة الطويلة)، يبقى الضغط المطوّل
  const TextCard({
    super.key,
    required this.text,
    this.source,
    this.shareFooter = '',
    this.baseSize = 21,
    this.actions = true,
  });

  @override
  State<TextCard> createState() => _TextCardState();
}

class _TextCardState extends State<TextCard> {
  bool _down = false;

  String get _full => widget.shareFooter.isEmpty
      ? cleanImportedText(widget.text)
      : '${cleanImportedText(widget.text)}\n\n${cleanImportedText(widget.shareFooter)}';

  void _menu() {
    HapticFeedback.selectionClick();
    final tk = HomeTokens.of(context);
    showHomeSheet<void>(
      context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HomeSheetRow(
            tk: tk,
            icon: ZikrIcons.copy,
            label: 'نسخ',
            onTap: () {
              Navigator.pop(ctx);
              copyToClipboard(context, _full);
            },
          ),
          HomeSheetRow(
            tk: tk,
            icon: ZikrIcons.share,
            label: 'مشاركة',
            onTap: () {
              Navigator.pop(ctx);
              Share.share(_full);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    final scale = context.select<AzkarProvider, double>((p) => p.fontScale);
    final displayText = cleanImportedText(widget.text);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onLongPress: _menu,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        decoration: BoxDecoration(
          color: tk.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _down ? tk.gold : tk.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              displayText,
              textAlign: TextAlign.right,
              style: amiriStyle(widget.baseSize * scale,
                  color: tk.ink, height: 1.95),
            ),
            if (widget.source != null && widget.source!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(widget.source!,
                    style: cairoStyle(11.5, weight: 600, color: tk.gold)),
              ),
            if (widget.actions) ...[
              const SizedBox(height: 8),
              Container(height: 1, color: tk.line),
              const SizedBox(height: 4),
              Row(
                children: [
                  _Act(
                      icon: ZikrIcons.copy,
                      label: 'نسخ',
                      onTap: () => copyToClipboard(context, _full)),
                  _Act(
                      icon: ZikrIcons.share,
                      label: 'مشاركة',
                      onTap: () => Share.share(_full)),
                ],
              ),
            ] else
              const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

class _Act extends StatelessWidget {
  final String icon, label;
  final VoidCallback onTap;
  const _Act({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    return Semantics(
      label: label,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: StyledIcon(icon, size: 19, color: tk.muted),
        ),
      ),
    );
  }
}

/// صف قائمة (فصل/باب/كتاب) بنفس شكل بلاطات الرئيسية.
class LibRow extends StatelessWidget {
  final HomeTokens tk;
  final String title;
  final String? subtitle;
  final String? leading; // رقم أو حرف داخل دائرة نعناعية
  final bool emphasized; // عنوان كتاب (نعناعي) مقابل باب
  final double indent;
  final int subtitleLines;
  final VoidCallback onTap;
  const LibRow({
    super.key,
    required this.tk,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.leading,
    this.emphasized = false,
    this.indent = 0,
    this.subtitleLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.only(start: indent),
      child: PressableCard(
        onTap: onTap,
        builder: (context, pressed) => AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: emphasized ? tk.mint : tk.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: pressed
                    ? tk.gold
                    : (emphasized ? Colors.transparent : tk.line)),
          ),
          child: Row(
            children: [
              if (leading != null) ...[
                Container(
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: emphasized ? tk.card : tk.mint,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(leading!,
                      style: cairoStyle(12.5, weight: 700, color: tk.mintInk)),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: cairoStyle(14.5,
                            weight: 700,
                            color: emphasized ? tk.mintInk : tk.ink,
                            height: 1.5)),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(subtitle!,
                            maxLines: subtitleLines,
                            overflow: TextOverflow.ellipsis,
                            style: cairoStyle(11.5,
                                color: emphasized
                                    ? tk.mintInk.withValues(alpha: .75)
                                    : tk.muted,
                                height: 1.5)),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_left_rounded, color: tk.gold, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// هيكل صفحة داخلية: نفس مقاسات وهيدر صفحة الأذكار.
class LibPage extends StatelessWidget {
  final String title;
  final List<Widget> actions;
  final Widget body;
  const LibPage(
      {super.key, required this.title, required this.body, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Scaffold(
      body: MediaQuery(
        data:
            mq.copyWith(textScaler: mq.textScaler.clamp(maxScaleFactor: 1.15)),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: [
                PageHeader(title: title, actions: actions),
                Expanded(child: body),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// يعرض نتيجة Future (تحميل/خطأ/محتوى) بنفس حالات باقي الشاشات.
class LibFuture<T> extends StatelessWidget {
  final Future<T> future;
  final String errorTitle;
  final Widget Function(BuildContext context, T data) builder;
  const LibFuture(
      {super.key,
      required this.future,
      required this.builder,
      this.errorTitle = 'تعذّر تحميل المحتوى'});

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    return FutureBuilder<T>(
      future: future,
      builder: (context, snap) {
        if (snap.hasError) {
          return HomeEmpty(
            tk: tk,
            icon: HomeIcons.quran,
            title: errorTitle,
            message: 'أعد تثبيت التطبيق أو حدّثه ثم حاول مرة أخرى',
          );
        }
        if (!snap.hasData) {
          return Center(child: CircularProgressIndicator(color: tk.leaf));
        }
        return builder(context, snap.data as T);
      },
    );
  }
}

String countLabel(int n, String one, String two, String few, String many) {
  if (n == 1) return one;
  if (n == 2) return two;
  if (n <= 10) return '${toArabicDigits(n)} $few';
  return '${toArabicDigits(n)} $many';
}

/// مقتطف من [text] حول أول كلمة من الاستعلام. الفهرس تقريبي لأن مفتاح البحث
/// يحذف التشكيل والألفات، فنقيسه نسبةً إلى طول المفتاح.
String snippetFor(String text, String key, String query, {int span = 200}) {
  final w = searchKey(query).split(' ').firstWhere((x) => x.isNotEmpty,
      orElse: () => '');
  final idx = w.isEmpty || key.isEmpty ? 0 : key.indexOf(w);
  final at = idx <= 0 ? 0 : (idx / key.length * text.length).round();
  final start = (at - 40).clamp(0, text.length);
  final end = (start + span).clamp(0, text.length);
  var s = text.substring(start, end).trim();
  if (start > 0) s = '… $s';
  if (end < text.length) s = '$s …';
  return s;
}

/// قارئ كتاب بسيط: كل فقرة صفحة مستقلة مع تقليب أفقي مثل المصحف.
class BookPageReader extends StatefulWidget {
  final String title;
  final String? author;
  final List<String> pages;
  final List<String>? pageFooters;
  const BookPageReader({
    super.key,
    required this.title,
    required this.pages,
    this.author,
    this.pageFooters,
  });

  @override
  State<BookPageReader> createState() => _BookPageReaderState();
}

class _BookPageReaderState extends State<BookPageReader> {
  late final PageController _controller;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    if (widget.pages.isEmpty) {
      return Center(child: Text('لا يوجد نص للعرض', style: cairoStyle(13, color: tk.muted)));
    }
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.pages.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) {
              final footer = widget.pageFooters != null &&
                      i < widget.pageFooters!.length
                  ? widget.pageFooters![i]
                  : widget.author;
              return Padding(
                padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  decoration: BoxDecoration(
                    color: tk.card,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: tk.line),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .12),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: cairoStyle(12, weight: 700, color: tk.gold)),
                      const SizedBox(height: 14),
                      Expanded(
                        child: SingleChildScrollView(
                          child: SelectableText(
                            widget.pages[i],
                            textAlign: TextAlign.justify,
                            style: amiriStyle(20, color: tk.ink, height: 2.0),
                          ),
                        ),
                      ),
                      if (footer != null && footer.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(footer,
                            textAlign: TextAlign.center,
                            style: cairoStyle(11, color: tk.muted, height: 1.6)),
                      ],
                      const SizedBox(height: 8),
                      Text('${toArabicDigits(i + 1)} من ${toArabicDigits(widget.pages.length)}',
                          style: cairoStyle(11, color: tk.gold)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HomeChip(
                tk: tk,
                label: 'الصفحة السابقة',
                selected: false,
                onTap: _page == 0
                    ? () {}
                    : () => _controller.previousPage(
                        duration: const Duration(milliseconds: 220), curve: Curves.easeOut),
              ),
              const SizedBox(width: 10),
              HomeChip(
                tk: tk,
                label: 'الصفحة التالية',
                selected: _page < widget.pages.length - 1,
                onTap: _page >= widget.pages.length - 1
                    ? () {}
                    : () => _controller.nextPage(
                        duration: const Duration(milliseconds: 220), curve: Curves.easeOut),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
