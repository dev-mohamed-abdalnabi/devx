import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class DuaItem {
  final String id;
  final String category;
  final String title;
  final String text;
  final String source;
  final String reference;
  final String speaker;
  final String occasion;
  final int? surah;
  final int? ayah;

  const DuaItem({
    required this.id,
    required this.category,
    required this.title,
    required this.text,
    required this.source,
    required this.reference,
    required this.speaker,
    required this.occasion,
    this.surah,
    this.ayah,
  });

  factory DuaItem.fromJson(Map<String, dynamic> j) => DuaItem(
        id: j['id'] as String,
        category: j['category'] as String,
        title: j['title'] as String,
        text: j['text'] as String,
        source: j['source'] as String,
        reference: j['reference'] as String,
        speaker: j['speaker'] as String? ?? 'من القرآن والسنة الصحيحة',
        occasion: j['occasion'] as String? ?? 'دعاء جامع يُستحب تذكّره والعمل بمعناه',
        surah: (j['surah'] as num?)?.toInt(),
        ayah: (j['ayah'] as num?)?.toInt(),
      );
}

class DuasRepo {
  DuasRepo._();
  static Future<List<DuaItem>> load() async {
    final raw = await rootBundle.loadString('assets/data/duas.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return [
      for (final x in (json['items'] as List))
        DuaItem.fromJson(x as Map<String, dynamic>),
    ];
  }
}
