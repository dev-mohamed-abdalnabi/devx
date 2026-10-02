import 'dart:convert';

const categoryNames = <String, String>{
  'worship': 'عبادة',
  'quran': 'قرآن',
  'dhikr': 'ذكر',
  'prayer': 'صلاة',
  'good': 'أعمال خير',
  'manners': 'أخلاق',
  'habits': 'عادات يومية',
  'self': 'تطوير النفس',
};

class Challenge {
  final String id;
  final String cat;
  final String period; // day | week | month
  final String title;
  final String? auto; // pages | tasbeeh:<id|all> | azkar:<morning|evening|sleep>
  final int? target;
  const Challenge(this.id, this.cat, this.period, this.title, this.auto, this.target);

  String get catName => categoryNames[cat] ?? cat;
  int get goal => target ?? 1;
}

List<Challenge> parseChallenges(String raw) {
  final j = json.decode(raw) as Map<String, dynamic>;
  return (j['challenges'] as List).map((e) {
    final m = e as Map<String, dynamic>;
    return Challenge(m['id'] as String, m['cat'] as String, m['period'] as String,
        m['title'] as String, m['auto'] as String?, m['target'] as int?);
  }).toList();
}
