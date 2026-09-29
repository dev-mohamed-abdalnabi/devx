import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/text_utils.dart';
import '../../data/cities.dart';
import '../../providers/prayer_provider.dart';

class CityPickerScreen extends StatefulWidget {
  const CityPickerScreen({super.key});

  @override
  State<CityPickerScreen> createState() => _CityPickerScreenState();
}

class _CityPickerScreenState extends State<CityPickerScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = normalizeArabic(_q);
    final list = q.isEmpty
        ? cities
        : cities
            .where((c) =>
                normalizeArabic(c.name).contains(q) || normalizeArabic(c.country).contains(q))
            .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('اختر مدينتك')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'ابحث عن مدينة أو دولة',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? const Center(child: Text('لا توجد نتائج'))
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final c = list[i];
                      return ListTile(
                        title: Text(c.name),
                        subtitle: Text(c.country),
                        onTap: () {
                          context.read<PrayerProvider>().selectCity(c);
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
