class Zikr {
  final int id;
  final String text;
  final int count;
  final String source;
  final String categoryId;
  int remaining;

  Zikr({
    required this.id,
    required this.text,
    required this.count,
    required this.source,
    required this.categoryId,
  }) : remaining = count;

  String get uniqueKey => '$categoryId-$id';

  void reset() => remaining = count;
}

class AzkarCategory {
  final String id;
  final String title;
  final String icon;
  final List<Zikr> azkar;

  AzkarCategory({
    required this.id,
    required this.title,
    required this.icon,
    required this.azkar,
  });

  factory AzkarCategory.fromJson(Map<String, dynamic> json) {
    final catId = json['id'] as String;
    final list = (json['azkar'] as List)
        .map((z) => Zikr(
              id: z['id'],
              text: z['text'],
              count: z['count'],
              source: z['source'],
              categoryId: catId,
            ))
        .toList();
    return AzkarCategory(
      id: catId,
      title: json['title'],
      icon: json['icon'],
      azkar: list,
    );
  }
}
