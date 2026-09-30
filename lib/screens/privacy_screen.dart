import 'package:flutter/material.dart';
import '../widgets/app_ui.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: const [
        AppSectionHeader(title: 'الخصوصية', subtitle: 'بوضوح، بدون ادعاءات أكثر من تنفيذ التطبيق'),
        SizedBox(height: 20),
        _PrivacySection(title: 'ما الذي يُحفظ؟', body: 'يحفظ التطبيق محليًا على جهازك تفضيلات المظهر والخط، تقدم الأذكار والقرآن والتسبيح والتحديات، المفضلة والعلامات المرجعية، وإعدادات التذكيرات.'),
        _PrivacySection(title: 'الموقع', body: 'يُستخدم الموقع عند طلبك لحساب مواقيت الصلاة وتحديد اتجاه القبلة. يمكنك اختيار مدينة يدويًا بدلًا من السماح بالموقع.'),
        _PrivacySection(title: 'الإشعارات', body: 'تُستخدم لإرسال التذكيرات والأذان الذي تفعّله أنت. يمكنك تغييرها أو إيقافها من داخل التطبيق أو إعدادات Android.'),
        _PrivacySection(title: 'هل تُرسل بياناتك؟', body: 'لا يحتوي التطبيق على حسابات أو تسجيل دخول أو مزامنة سحابية. البيانات المحلية لا تُرسل إلى خادم بواسطة التطبيق. يعتمد البناء على مصادر بيانات عامة لجلب محتوى القرآن والأذكار أثناء إعداد نسخة التطبيق.'),
        _PrivacySection(title: 'حذف بياناتك المحلية', body: 'يمكن حذف بيانات التطبيق من إعدادات Android. سيؤدي ذلك إلى حذف التقدم والتفضيلات والتذكيرات المحفوظة على الجهاز.'),
      ],
    );
  }
}

class _PrivacySection extends StatelessWidget {
  final String title;
  final String body;
  const _PrivacySection({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(body, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.65)),
        ]),
      ),
    );
  }
}
