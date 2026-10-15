import 'package:flutter/material.dart';
import '../../core/home_tokens.dart';
import '../../core/text_utils.dart';
import '../../data/library_data.dart';
import '../../widgets/home_style.dart';
import '../home/home_art.dart';
import '../home/home_screen.dart' show HomeTile;
import 'hadith_screens.dart';
import 'library_widgets.dart';

String hadithCountLabel(int n) =>
    countLabel(n, 'حديث واحد', 'حديثان', 'أحاديث', 'حديثًا');

/// المكتبة: فهرس كتب مرتب، ثم يفتح كل كتاب على أبوابه وصفحاته.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    return LibPage(
      title: 'المكتبة',
      body: LibFuture<List<LibBook>>(
        future: LibraryRepo.libIndex(),
        errorTitle: 'تعذّر تحميل المكتبة',
        builder: (context, books) {
          final total = books.fold<int>(0, (a, b) => a + b.count);
          return CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 6)),
              SliverToBoxAdapter(
                child: HomeHeroCard(
                  tk: tk,
                  icon: HomeIcons.books,
                  eyebrow: 'من كتب السنة النبوية',
                  title: 'مكتبة الحديث',
                  caption:
                      '${toArabicDigits(books.length)} كتب · ${toArabicDigits(total)} حديثًا',
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 10)),
              SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 240,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  mainAxisExtent: 126,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final b = books[i];
                    return HomeTile(
                      tk: tk,
                      compact: false,
                      icon: HomeIcons.books,
                      title: b.title,
                      subtitle:
                          '${hadithCountLabel(b.count)} · ${toArabicDigits(b.chapters)} بابًا',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => HadithBookScreen(book: b)),
                      ),
                    );
                  },
                  childCount: books.length,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 16, 4, 24),
                  child: Text(
                    'نصوص الأحاديث منقولة كما هي من مصادرها الأصلية دون أي تعديل، '
                    'مع اسم الكتاب ورقم الحديث. التفاصيل في «المصادر والتراخيص».',
                    style: cairoStyle(11.5, color: tk.muted, height: 1.7),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
