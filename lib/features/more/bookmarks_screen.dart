import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/text_utils.dart';
import '../../data/quran_data.dart';
import '../../providers/quran_provider.dart';
import '../quran/quran_home_screen.dart';

class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final q = context.watch<QuranProvider>();
    final data = q.data;
    final List<Ayah> items = q.bookmarks
        .map((k) => data?.ayahByKey(k))
        .whereType<Ayah>()
        .toList()
      ..sort((a, b) {
        final c = a.surah.compareTo(b.surah);
        return c != 0 ? c : a.number.compareTo(b.number);
      });

    return Scaffold(
      appBar: AppBar(title: const Text('علامات القرآن')),
      body: items.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'لم تحفظ أي علامة بعد.\nاضغط على أي آية أثناء القراءة ثم اختر «حفظ علامة».',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (ctx, i) {
                final a = items[i];
                return ListTile(
                  title: Text(a.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'AmiriQuran', fontSize: 19, height: 1.8)),
                  subtitle: Text(
                      'سورة ${data!.surahOf(a.surah).name} · آية ${toArabicDigits(a.number)}'),
                  trailing: IconButton(
                    tooltip: 'إزالة العلامة',
                    icon: const Icon(Icons.bookmark_remove_outlined),
                    onPressed: () => q.toggleBookmark(a.key),
                  ),
                  onTap: () => openReader(ctx, a.page, highlight: a.key),
                );
              },
            ),
    );
  }
}
