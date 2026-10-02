import 'package:flutter/material.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const _sections = [
    (Icons.storage_outlined, 'ما الذي يُحفظ؟', 'يحفظ التطبيق محليًا على جهازك تفضيلات المظهر والخط، تقدم الأذكار والقرآن والتسبيح والتحديات، المفضلة والعلامات المرجعية، وإعدادات التذكيرات.'),
    (Icons.location_on_outlined, 'الموقع', 'يُستخدم الموقع عند طلبك لحساب مواقيت الصلاة وتحديد اتجاه القبلة. يمكنك اختيار مدينة يدويًا بدلًا من السماح بالوصول إلى الموقع.'),
    (Icons.notifications_none_rounded, 'الإشعارات', 'تُستخدم لإرسال التذكيرات والأذان الذي تفعّله أنت. يمكنك تغييرها أو إيقافها من داخل التطبيق أو من إعدادات Android.'),
    (Icons.cloud_off_outlined, 'هل تُرسل بياناتك؟', 'لا يحتوي التطبيق على حسابات أو تسجيل دخول أو مزامنة سحابية. البيانات المحلية لا تُرسل إلى خادم بواسطة التطبيق.'),
    (Icons.delete_outline_rounded, 'حذف بياناتك المحلية', 'يمكن حذف بيانات التطبيق من إعدادات Android. سيؤدي ذلك إلى حذف التقدم والتفضيلات والتذكيرات المحفوظة على الجهاز.'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('الخصوصية')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
        children: [
          Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: scheme.primaryContainer.withValues(alpha: .55), borderRadius: BorderRadius.circular(24)), child: Row(children: [Icon(Icons.verified_user_outlined, color: scheme.primary, size: 30), const SizedBox(width: 14), Expanded(child: Text('خصوصيتك جزء من تصميم ذكر، لا إضافة جانبية.', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800, height: 1.45)))])),
          const SizedBox(height: 28),
          Text('بوضوح وبدون تعقيد', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('هذه هي طريقة تعامل التطبيق مع البيانات والصلاحيات.', style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          ...List.generate(_sections.length, (index) => _PolicySection(index: index + 1, icon: _sections[index].$1, title: _sections[index].$2, body: _sections[index].$3)),
          const SizedBox(height: 8),
          Text('آخر تحديث: الإصدار 1.2.0', textAlign: TextAlign.center, style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  final int index;
  final IconData icon;
  final String title;
  final String body;
  const _PolicySection({required this.index, required this.icon, required this.title, required this.body});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: scheme.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: scheme.outlineVariant.withValues(alpha: .4))), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 40, height: 40, alignment: Alignment.center, decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: scheme.primary, size: 21)), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Text('$index', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800)), const SizedBox(width: 8), Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)))]), const SizedBox(height: 8), Text(body, style: TextStyle(color: scheme.onSurfaceVariant, height: 1.65))]))])));
  }
}
