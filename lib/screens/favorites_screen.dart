import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/home_tokens.dart';
import '../features/home/home_art.dart';
import '../providers/azkar_provider.dart';
import '../widgets/home_style.dart';
import '../widgets/zikr_card.dart';

/// المفضّلة — نفس هيدر وكروت الرئيسية.
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    final mq = MediaQuery.of(context);
    final favs = context.watch<AzkarProvider>().favoriteAzkar;

    return Scaffold(
      body: MediaQuery(
        data: mq.copyWith(textScaler: mq.textScaler.clamp(maxScaleFactor: 1.3)),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: [
                const PageHeader(title: 'المفضّلة'),
                Expanded(
                  child: favs.isEmpty
                      ? HomeEmpty(
                          tk: tk,
                          icon: HomeIcons.heart,
                          title: 'لا يوجد أذكار مفضلة بعد',
                          message: 'اضغط على القلب في أي ذكر لإضافته هنا',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.only(top: 6, bottom: 24),
                          itemCount: favs.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, i) =>
                              ZikrCard(zikr: favs[i]),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
