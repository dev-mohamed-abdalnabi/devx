import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/home_tokens.dart';
import '../../core/star_shape.dart';
import '../../core/text_utils.dart';
import '../../services/ads_service.dart';
import '../../widgets/page_kit.dart';
import '../../widgets/home_style.dart';
import '../home/home_art.dart';
import '../../widgets/support_app_button.dart';

const _contactEmail = 'dev.mohamed.abdalnabi@gmail.com';
const _contactWhatsapp = '201102855563'; // 01102855563 بصيغة دولية (مصر)
const _shareText =
    'أنصحك بتطبيق «ذِكر»: أذكار الصباح والمساء، والقرآن الكريم مقروءًا ومسموعًا، ومواقيت الصلاة، مجاني وبلا إعلانات إجبارية. جزاك الله خيرًا ونفع بك 🤍';
const _duaText =
    'اللَّهُمَّ اجْعَلْ هَذَا العَمَلَ خَالِصًا لِوَجْهِكَ الكَرِيمِ، وَانْفَعْ بِهِ، وَاجْعَلْهُ صَدَقَةً جَارِيَةً لِكُلِّ مَنْ أَسْهَمَ فِيهِ.';

/// شاشة «ادعم التطبيق»: الإعلانات هنا اختيارية بالكامل ولا تظهر في أي مكان آخر.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  static const _countKey = 'support_ads_count';
  int _count = 0;
  bool _loading = false;
  bool _ready = false;
  bool _failed = false;
  bool _details = false;

  @override
  void initState() {
    super.initState();
    SupportBarVisibility.hide();
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => _count = p.getInt(_countKey) ?? 0);
    });
    _prepare();
  }

  @override
  void dispose() {
    SupportBarVisibility.show();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  /// يحمّل الإعلان مسبقًا بمجرد فتح الشاشة ليكون جاهزًا عند الضغط.
  Future<void> _prepare() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    final ok = AdsService.instance.rewardedReady ||
        await AdsService.instance.loadRewarded();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _ready = ok;
      _failed = !ok;
    });
  }

  Future<void> _watch() async {
    if (_loading) return;
    if (!_ready) {
      await _prepare();
      if (!_ready) {
        _snack('${AdsService.instance.friendlyError} شكرًا لنيتك الطيبة.');
        return;
      }
    }
    final watched = await AdsService.instance.showRewarded();
    if (!mounted) return;
    setState(() => _ready = false);
    if (watched) {
      final prefs = await SharedPreferences.getInstance();
      final next = (prefs.getInt(_countKey) ?? 0) + 1;
      await prefs.setInt(_countKey, next);
      if (mounted) setState(() => _count = next);
      _snack('جزاك الله خيرًا، شكرًا لدعمك التطبيق.');
    }
    // جهّز الإعلان التالي في الخلفية.
    if (mounted) _prepare();
  }

  Future<void> _open(Uri uri, {String? fallbackCopy}) async {
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok) {
      if (fallbackCopy != null) {
        await Clipboard.setData(ClipboardData(text: fallbackCopy));
        _snack('تعذّر فتح التطبيق، تم نسخ: $fallbackCopy');
      } else {
        _snack('تعذّر فتح الرابط');
      }
    }
  }

  void _whatsapp() => _open(
        Uri.parse(
            'https://wa.me/$_contactWhatsapp?text=${Uri.encodeComponent('السلام عليكم، بخصوص تطبيق ذِكر: ')}'),
        fallbackCopy: '+$_contactWhatsapp',
      );

  void _email() => _open(
        Uri.parse(
            'mailto:$_contactEmail?subject=${Uri.encodeComponent('بخصوص تطبيق ذِكر')}'),
        fallbackCopy: _contactEmail,
      );

  Future<void> _share() async {
    try {
      await Share.share(_shareText);
    } catch (_) {
      _snack('تعذّرت المشاركة');
    }
  }

  Future<void> _copyDua() async {
    await Clipboard.setData(const ClipboardData(text: _duaText));
    _snack('تم نسخ الدعاء');
  }

  @override
  Widget build(BuildContext context) {
    final tk = HomeTokens.of(context);
    final ads = AdsService.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('ادعم التطبيق')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            HomeHeroCard(
              tk: tk,
              icon: HomeIcons.heart,
              eyebrow: 'مجاني وبلا إعلانات إجبارية',
              title: 'ادعم ذِكر',
              caption: 'دعمك يبقيه نافعًا',
              height: 124,
            ),
            const SizedBox(height: 22),
            const KitSectionTitle(
              text: 'كيف تدعمنا؟',
              caption: 'كل الطرق اختيارية، وبعضها لا يكلّفك شيئًا',
            ),
            // ─ إعلان ─
            KitCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const KitIcon(
                          icon: Icons.play_circle_outline_rounded, size: 46),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('شاهد إعلانًا قصيرًا',
                                style: cairoStyle(15.5,
                                    weight: 700, color: tk.ink)),
                            const SizedBox(height: 2),
                            Text(
                                'دقيقة واحدة تساعدنا على الاستمرار، ولا شيء يتغيّر في التطبيق إن لم تفعل.',
                                style: cairoStyle(12.5,
                                    color: tk.muted, height: 1.6)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  KitPrimaryButton(
                    busy: _loading,
                    icon: _failed
                        ? Icons.refresh_rounded
                        : Icons.volunteer_activism_rounded,
                    label: _loading
                        ? 'جارٍ تحميل الإعلان…'
                        : _failed
                            ? 'إعادة المحاولة'
                            : 'شاهد الإعلان',
                    onPressed: _failed ? _prepare : _watch,
                  ),
                  if (_failed) ...[
                    const SizedBox(height: 12),
                    Text(ads.friendlyError,
                        style: cairoStyle(12.5, color: tk.muted, height: 1.6)),
                    InkWell(
                      onTap: () => setState(() => _details = !_details),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                            _details
                                ? 'إخفاء التفاصيل'
                                : 'عرض التفاصيل التقنية',
                            style: cairoStyle(12, weight: 600, color: tk.gold)),
                      ),
                    ),
                    if (_details)
                      SelectableText(ads.technicalError,
                          textDirection: TextDirection.ltr,
                          style: cairoStyle(11, color: tk.muted)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            // ─ مشاركة ─
            KitCard(
              padding: EdgeInsets.zero,
              child: KitTile(
                icon: Icons.ios_share_rounded,
                title: 'شارك التطبيق',
                subtitle: 'أرسله لمن تحب، فالدالّ على الخير كفاعله.',
                onTap: _share,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 10),
            // ─ دعاء ─
            _DuaCard(tk: tk, onCopy: _copyDua),
            const SizedBox(height: 24),
            const KitSectionTitle(
              text: 'تواصل معنا',
              caption: 'اقتراح أو بلاغ عن مشكلة؟ يسعدنا سماعك',
            ),
            KitCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  KitTile(
                    icon: Icons.chat_rounded,
                    title: 'واتساب',
                    subtitle: toArabicDigitsStr('01102855563'),
                    onTap: _whatsapp,
                  ),
                  const KitDivider(),
                  KitTile(
                    icon: Icons.mail_outline_rounded,
                    title: 'البريد الإلكتروني',
                    subtitle: _contactEmail,
                    ltrSubtitle: true,
                    onTap: _email,
                  ),
                ],
              ),
            ),
            if (_count > 0) ...[
              const SizedBox(height: 22),
              _Impact(tk: tk, count: _count),
            ] else ...[
              const SizedBox(height: 24),
              Center(
                child: Text('جزاك الله خيرًا على نيتك الطيبة',
                    style: cairoStyle(12.5, color: tk.muted)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DuaCard extends StatelessWidget {
  final HomeTokens tk;
  final VoidCallback onCopy;
  const _DuaCard({required this.tk, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return KitCard(
      color: tk.mint,
      borderColor: tk.gold.withValues(alpha: .5),
      padding: const EdgeInsets.fromLTRB(18, 16, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 18, color: tk.gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text('ادعُ لنا بظهر الغيب',
                    style: cairoStyle(14.5, weight: 700, color: tk.mintInk)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(_duaText,
              textAlign: TextAlign.center,
              style: amiriStyle(19, color: tk.mintInk, height: 2)),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: onCopy,
              icon: Icon(Icons.copy_rounded, size: 16, color: tk.gold),
              label: Text('نسخ الدعاء',
                  style: cairoStyle(13, weight: 700, color: tk.gold)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Impact extends StatelessWidget {
  final HomeTokens tk;
  final int count;
  const _Impact({required this.tk, required this.count});

  @override
  Widget build(BuildContext context) {
    return KitCard(
      color: tk.mint,
      borderColor: tk.gold.withValues(alpha: .5),
      child: Row(
        children: [
          IslamicStar(
            size: 54,
            color: tk.gold.withValues(alpha: .25),
            child: Text(toArabicDigits(count),
                style: cairoStyle(count > 99 ? 14 : 18,
                    weight: 700, color: tk.mintInk)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'دعمتَ التطبيق ${toArabicDigits(count)} ${count == 1 ? 'مرة' : 'مرات'}، جزاك الله خيرًا وبارك فيك.',
              style:
                  cairoStyle(13.5, weight: 600, color: tk.mintInk, height: 1.7),
            ),
          ),
        ],
      ),
    );
  }
}
