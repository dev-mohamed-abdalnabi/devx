import 'package:flutter/material.dart';

/// أشكال شاشة الأذان الخمسة.
class AdhanStyleInfo {
  final String name;
  final String desc;
  final IconData icon;
  const AdhanStyleInfo(this.name, this.desc, this.icon);
}

const adhanStyles = <AdhanStyleInfo>[
  AdhanStyleInfo('الزمردي', 'تدرّج أخضر هادئ بنقش إسلامي', Icons.mosque_rounded),
  AdhanStyleInfo('ليل الفجر', 'سماء ليلية بنجوم وهلال', Icons.nightlight_round),
  AdhanStyleInfo('الذهبي', 'خلفية داكنة وإطار ذهبي فخم', Icons.auto_awesome),
  AdhanStyleInfo('غروب', 'ألوان الشفق الدافئة', Icons.wb_twilight_rounded),
  AdhanStyleInfo('بسيط', 'نظيف ومريح للعين', Icons.crop_square_rounded),
];

/// أنماط عرض شاشة الأذان.
/// 0 = فوق كل التطبيقات، 1 = على شاشة القفل فقط (إشعار عادي أثناء استخدام الجهاز).
const adhanDisplayOverApps = 0;
const adhanDisplayLockOnly = 1;
