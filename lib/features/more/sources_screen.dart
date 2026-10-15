import 'package:flutter/material.dart';

import '../../core/home_tokens.dart';
import '../../widgets/page_kit.dart';

/// شاشة «المصادر والتراخيص»: تنسب كل محتوى في التطبيق لأصحابه.
/// ملاحظة للمطوّر: حدّث هذه القائمة كلما أضفت مصدرًا جديدًا (تلاوة، أذان، خط…).
class _Src {
  final IconData icon;
  final String title;
  final String by; // الجهة / المصدر
  final String note; // الترخيص أو ملاحظة
  const _Src(this.icon, this.title, this.by, this.note);
}

const _content = <_Src>[
  _Src(
    Icons.menu_book_rounded,
    'نص القرآن الكريم',
    'مشروع تنزيل (tanzil.net) عبر alquran.cloud',
    'النص العثماني. يُحفظ كما هو دون تعديل.',
  ),
  _Src(
    Icons.auto_stories_outlined,
    'التفسير الميسر',
    'مجمع الملك فهد لطباعة المصحف الشريف',
    'حقوقه محفوظة للمجمع، ويُعرض هنا للقراءة فقط.',
  ),
  _Src(
    Icons.view_agenda_outlined,
    'تخطيط مصحف المدينة وخطوط صفحاته',
    'Quran.com / Quran Foundation، وأصل الخطوط من مجمع الملك فهد',
    'تُستخدم دون تعديل وفق شروط أصحابها.',
  ),
  _Src(
    Icons.pan_tool_alt_outlined,
    'الأذكار',
    'حصن المسلم من أذكار الكتاب والسنة، للشيخ سعيد بن علي بن وهف القحطاني',
    'مصدر كل ذكر ورقمه يظهران داخل التطبيق.',
  ),
  _Src(
    Icons.local_library_outlined,
    'مكتبة الحديث (١٠ كتب)',
    'نصوص الأحاديث من موقع sunnah.com عبر مستودع AhmedBaset/hadith-json. '
        'صحيح البخاري، صحيح مسلم، الأربعون النووية، رياض الصالحين، الأربعون القدسية، '
        'بلوغ المرام، سنن أبي داود، جامع الترمذي، سنن النسائي، سنن ابن ماجه',
    'تُعرض كما هي دون تعديل، مع اسم الكتاب ورقم الحديث.',
  ),
  _Src(
    Icons.history_edu_outlined,
    'حكايات الوحي',
    'فهرس مراجع فقط (tool/build_stories.py): الآيات من نص القرآن أعلاه، والأحاديث من '
        'صحيح البخاري وصحيح مسلم في المكتبة أعلاه، بنصها وأرقامها',
    'لا نص مكتوب بالذكاء الاصطناعي. لا تُعرض روايات سيرة خارج الصحيحين لعدم توثيق سندها هنا.',
  ),
  _Src(
    Icons.menu_book_outlined,
    'كتب «حكايات الوحي» الأصلية',
    'قصص الأنبياء لابن كثير، والسيرة النبوية لابن هشام. النصوص من المكتبة الشاملة عبر '
        'مشروع OpenITI (الإصدار والمسار يظهران داخل كل كتاب)',
    'تُعرض كما وردت، وفيها روايات غير صحيحة وإسرائيليات؛ التنبيه ظاهر داخل الكتاب. '
        'تحقق من ترخيص OpenITI لكل كتاب قبل النشر.',
  ),
  _Src(
    Icons.gavel_outlined,
    'الأحكام الفقهية',
    'متون مختصرة: مختصر القدوري (حنفي)، الرسالة لابن أبي زيد القيرواني (مالكي)، '
        'الغاية والتقريب لأبي شجاع (شافعي)، عمدة الفقه لابن قدامة (حنبلي). '
        'النصوص من المكتبة الشاملة عبر مشروع OpenITI',
    'تُعرض كما وردت في الكتب؛ حذفنا فقط أرقام الصفحات وعلامات التنسيق.',
  ),
  _Src(
    Icons.headphones_outlined,
    'التلاوات الصوتية',
    'مشاري راشد العفاسي، محمود خليل الحصري، محمد صديق المنشاوي، عبدالرحمن السديس',
    'حقوق التسجيلات محفوظة لأصحابها.',
  ),
  _Src(
    Icons.volume_up_outlined,
    'الأذان',
    'تسجيل بصوت ناصر القطامي من Internet Archive',
    'Public Domain Mark 1.0. لا يعني ذلك تزكية من المؤذّن.',
  ),
];

const _tech = <_Src>[
  _Src(
    Icons.font_download_outlined,
    'الخطوط',
    'Tajawal، Cairo، Amiri، Amiri Quran (Google Fonts)',
    'رخصة SIL Open Font License 1.1.',
  ),
  _Src(
    Icons.graphic_eq_rounded,
    'تشغيل الصوت في الخلفية',
    'just_audio_background لـ Ryan Heise',
    'رخصة MIT.',
  ),
];

class SourcesScreen extends StatelessWidget {
  const SourcesScreen({super.key});

  static const _version = '1.4.0';

  Widget _group(List<_Src> list) {
    return KitCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < list.length; i++) ...[
            KitTile(
              icon: list[i].icon,
              title: list[i].title,
              subtitle: '${list[i].by}\n${list[i].note}',
            ),
            if (i < list.length - 1) const KitDivider(),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    final mq = MediaQuery.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('المصادر والتراخيص')),
      body: MediaQuery(
        data:
            mq.copyWith(textScaler: mq.textScaler.clamp(maxScaleFactor: 1.15)),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            KitCard(
              child: Text(
                'نشكر كل من أتاح هذا المحتوى. هنا مصدر كل جزء في ذِكر، '
                'وحقوقه محفوظة لأصحابه. إن وجدت محتوى يخصّك وترغب في '
                'تعديل نسبته أو إزالته، تواصل معنا من شاشة «عن ذِكر».',
                style: cairoStyle(13.5, color: tk.ink, height: 1.9),
              ),
            ),
            const SizedBox(height: 22),
            const KitSectionTitle(text: 'المحتوى'),
            _group(_content),
            const SizedBox(height: 22),
            const KitSectionTitle(text: 'الخطوط والمكتبات'),
            _group(_tech),
            const SizedBox(height: 10),
            KitCard(
              padding: EdgeInsets.zero,
              child: KitTile(
                icon: Icons.description_outlined,
                title: 'تراخيص المكتبات مفتوحة المصدر',
                subtitle: 'قائمة كاملة بكل المكتبات المستخدمة',
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'ذِكر',
                  applicationVersion: _version,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
