/// أيام الأسبوع بترقيم Dart: الاثنين = 1 … الأحد = 7.
const allWeekdays = <int>{1, 2, 3, 4, 5, 6, 7};

/// ترتيب العرض: من السبت.
const weekdayDisplayOrder = <int>[6, 7, 1, 2, 3, 4, 5];

const weekdayNames = <int, String>{
  6: 'السبت',
  7: 'الأحد',
  1: 'الاثنين',
  2: 'الثلاثاء',
  3: 'الأربعاء',
  4: 'الخميس',
  5: 'الجمعة',
};

class Reminder {
  final int id;
  final String kind; // morning | evening | sleep | quran | challenges | custom
  String title;
  String body;
  int hour;
  int minute;
  Set<int> days;
  bool enabled;

  Reminder({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.hour,
    required this.minute,
    Set<int>? days,
    this.enabled = false,
  }) : days = days ?? {...allWeekdays};

  bool get isCustom => kind == 'custom';

  String get daysLabel {
    if (days.length == 7) return 'كل يوم';
    return weekdayDisplayOrder
        .where(days.contains)
        .map((d) => weekdayNames[d]!)
        .join('، ');
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'title': title,
        'body': body,
        'h': hour,
        'm': minute,
        'days': (days.toList()..sort()),
        'on': enabled,
      };

  static Reminder fromJson(Map<String, dynamic> j) => Reminder(
        id: j['id'] as int,
        kind: j['kind'] as String,
        title: j['title'] as String,
        body: (j['body'] as String?) ?? '',
        hour: j['h'] as int,
        minute: j['m'] as int,
        days:
            ((j['days'] as List?) ?? allWeekdays.toList()).cast<int>().toSet(),
        enabled: (j['on'] as bool?) ?? false,
      );
}

/// التذكيرات الافتراضية مفعّلة في أول تشغيل، ويمكن للمستخدم إيقاف أي منها.
List<Reminder> defaultReminders() => [
      Reminder(
          id: 1,
          kind: 'morning',
          title: 'أذكار الصباح',
          body: 'حان وقت أذكار الصباح',
          hour: 6,
          minute: 0,
          enabled: true),
      Reminder(
          id: 2,
          kind: 'evening',
          title: 'أذكار المساء',
          body: 'حان وقت أذكار المساء',
          hour: 17,
          minute: 0,
          enabled: true),
      Reminder(
          id: 3,
          kind: 'sleep',
          title: 'أذكار النوم',
          body: 'حان وقت أذكار النوم',
          hour: 22,
          minute: 30,
          enabled: true),
      Reminder(
          id: 4,
          kind: 'quran',
          title: 'ورد القرآن',
          body: 'موعد وردك من القرآن الكريم',
          hour: 21,
          minute: 0,
          enabled: true),
      Reminder(
          id: 5,
          kind: 'challenges',
          title: 'تحديات اليوم',
          body: 'راجع تحدياتك اليومية وأكمل ما بقي منها',
          hour: 20,
          minute: 0,
          enabled: true),
    ];
