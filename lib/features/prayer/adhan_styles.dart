import 'package:flutter/material.dart';

/// أشكال شاشة الأذان الخمسة.
class AdhanStyleInfo {
  final String name;
  final String desc;
  final IconData icon;
  const AdhanStyleInfo(this.name, this.desc, this.icon);
}

const adhanStyles = <AdhanStyleInfo>[
  AdhanStyleInfo('الزمردي', 'تدرّج أخضر هادئ بنقش إسلامي وموجات حول الشعار', Icons.mosque_rounded),
  AdhanStyleInfo('ليل الفجر', 'سماء ليلية بنجوم وهلال والشعار يطفو', Icons.nightlight_round),
  AdhanStyleInfo('الذهبي', 'خلفية داكنة وإطار ذهبي ولمعة تعبر الشعار', Icons.auto_awesome),
  AdhanStyleInfo('غروب', 'ألوان الشفق وأشعة شمس تدور خلف الشعار', Icons.wb_twilight_rounded),
  AdhanStyleInfo('بسيط', 'نظيف ومريح للعين بشعار أخضر', Icons.crop_square_rounded),
];

/// أنماط عرض شاشة الأذان.
/// 0 = فوق كل التطبيقات، 1 = على شاشة القفل فقط (إشعار عادي أثناء استخدام الجهاز).
const adhanDisplayOverApps = 0;
const adhanDisplayLockOnly = 1;

/// عبارات الأذان بالترتيب (نفس ترتيب AdhanLyrics.java في الجزء الأصلي).
const adhanLines = <String>[
  'اللهُ أكبرُ، اللهُ أكبرُ',
  'اللهُ أكبرُ، اللهُ أكبرُ',
  'أشهدُ أن لا إلهَ إلا اللهُ',
  'أشهدُ أن لا إلهَ إلا اللهُ',
  'أشهدُ أنَّ محمدًا رسولُ اللهِ',
  'أشهدُ أنَّ محمدًا رسولُ اللهِ',
  'حيَّ على الصلاةِ',
  'حيَّ على الصلاةِ',
  'حيَّ على الفلاحِ',
  'حيَّ على الفلاحِ',
  'اللهُ أكبرُ، اللهُ أكبرُ',
  'لا إلهَ إلا اللهُ',
];

/// الدعاء المأثور بعد الأذان (رواه البخاري).
const adhanAfterDua =
    'اللهمَّ ربَّ هذه الدعوةِ التامَّةِ، والصلاةِ القائمةِ، آتِ محمدًا الوسيلةَ والفضيلةَ، وابعثهُ مقامًا محمودًا الذي وعدتَه';
