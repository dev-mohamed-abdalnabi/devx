import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/home_tokens.dart';
import '../../core/star_shape.dart';
import '../../core/text_utils.dart';
import '../../services/ads_service.dart';
import '../../widgets/support_app_button.dart';
import '../home/home_art.dart';

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
        _snack('${AdsService.instance.friendlyError} شكرًا لنيتك الطيبة 🤍');
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
      _snack('جزاك الله خيرًا، شكرًا لدعمك التطبيق 🤍');
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
    _snack('تم نسخ الدعاء 🤍');
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
            _Hero(tk: tk),
            const SizedBox(height: 18),
            _Heading(tk: tk, text: 'طرق الدعم'),
            // ─ إعلان ─
            _Panel(
              tk: tk,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RowHead(
                    tk: tk,
                    icon: Icons.play_circle_outline_rounded,
                    title: 'شاهد إعلانًا قصيرًا',
                    subtitle:
                        'بإرادتك فقط، ولا شيء يتغير في التطبيق إن لم تفعل.',
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed:
                          _loading ? null : (_failed ? _prepare : _watch),
                      style: FilledButton.styleFrom(
                        backgroundColor: tk.leaf,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Icon(
                              _failed
                                  ? Icons.refresh_rounded
                                  : Icons.favorite_rounded,
                              size: 20),
                      label: Text(
                        _loading
                            ? 'جارٍ تحميل الإعلان...'
                            : _failed
                                ? 'إعادة المحاولة'
                                : 'شاهد الإعلان',
                        style: cairoStyle(15, weight: 700, color: Colors.white),
                      ),
                    ),
                  ),
                  if (_failed) ...[
                    const SizedBox(height: 10),
                    Text(ads.friendlyError,
                        style: cairoStyle(12.5, color: tk.muted, height: 1.6)),
                    const SizedBox(height: 6),
                    SelectableText(ads.technicalError,
                        textDirection: TextDirection.ltr,
                        style: cairoStyle(11, color: tk.muted)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            // ─ مشاركة ─
            _Panel(
              tk: tk,
              onTap: _share,
              child: _RowHead(
                tk: tk,
                icon: Icons.ios_share_rounded,
                title: 'شارك التطبيق',
                subtitle: 'أرسله لمن تحب، فالدالّ على الخير كفاعله.',
                chevron: true,
              ),
            ),
            const SizedBox(height: 10),
            // ─ دعاء ─
            _Panel(
              tk: tk,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RowHead(
                    tk: tk,
                    icon: Icons.auto_awesome_rounded,
                    title: 'ادعُ لنا بظهر الغيب',
                    subtitle: 'دعوة صادقة منك أغلى ما نريد.',
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: tk.mint,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_duaText,
                            style:
                                amiriStyle(18, color: tk.mintInk, height: 1.9)),
                        const SizedBox(height: 6),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: TextButton.icon(
                            onPressed: _copyDua,
                            icon: Icon(Icons.copy_rounded,
                                size: 16, color: tk.gold),
                            label: Text('نسخ',
                                style: cairoStyle(13,
                                    weight: 700, color: tk.gold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _Heading(tk: tk, text: 'تواصل معنا'),
            _Panel(
              tk: tk,
              onTap: _whatsapp,
              child: _RowHead(
                tk: tk,
                icon: Icons.chat_rounded,
                title: 'واتساب',
                subtitle:
                    'اقتراح أو بلاغ عن مشكلة: ${toArabicDigitsStr('01102855563')}',
                chevron: true,
              ),
            ),
            const SizedBox(height: 10),
            _Panel(
              tk: tk,
              onTap: _email,
              child: _RowHead(
                tk: tk,
                icon: Icons.mail_outline_rounded,
                title: 'البريد الإلكتروني',
                subtitle: _contactEmail,
                chevron: true,
                ltrSubtitle: true,
              ),
            ),
            const SizedBox(height: 22),
            _Impact(tk: tk, count: _count),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final HomeTokens tk;
  const _Hero({required this.tk});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFF0C2B31), Color(0xFF16473F)],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: IslamicPatternPainter(opacity: .12),
              ),
            ),
            Column(
              children: [
                SizedBox(
                  width: 84,
                  height: 84,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(84, 84),
                        painter: IslamicStarPainter(const Color(0xFFE2BC63)),
                      ),
                      const Icon(Icons.favorite_rounded,
                          size: 30, color: Color(0xFF0C2B31)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text('التطبيق مجاني وبلا إعلانات إجبارية',
                    textAlign: TextAlign.center,
                    style: cairoStyle(18,
                        weight: 700, color: const Color(0xFFF1EEE2))),
                const SizedBox(height: 8),
                Text(
                  'إن أحببت أن تدعم استمراره وتطويره فلك طرق كثيرة، أيسرها كلمة طيبة أو دعاء.',
                  textAlign: TextAlign.center,
                  style: cairoStyle(13.5,
                      color: const Color(0xFFB9D3C6), height: 1.7),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  final HomeTokens tk;
  final String text;
  const _Heading({required this.tk, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                  color: tk.gold, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 8),
            Text(text, style: cairoStyle(16, weight: 700, color: tk.ink)),
          ],
        ),
      );
}

class _Panel extends StatelessWidget {
  final HomeTokens tk;
  final Widget child;
  final VoidCallback? onTap;
  const _Panel({required this.tk, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tk.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: tk.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    );
  }
}

class _RowHead extends StatelessWidget {
  final HomeTokens tk;
  final IconData icon;
  final String title, subtitle;
  final bool chevron, ltrSubtitle;
  const _RowHead({
    required this.tk,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.chevron = false,
    this.ltrSubtitle = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: tk.mint, shape: BoxShape.circle),
          child: Icon(icon, size: 22, color: tk.mintInk),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: cairoStyle(15, weight: 700, color: tk.ink)),
              const SizedBox(height: 2),
              Text(subtitle,
                  textDirection: ltrSubtitle ? TextDirection.ltr : null,
                  style: cairoStyle(12.5, color: tk.muted, height: 1.5)),
            ],
          ),
        ),
        if (chevron) Icon(Icons.chevron_left_rounded, color: tk.gold, size: 26),
      ],
    );
  }
}

class _Impact extends StatelessWidget {
  final HomeTokens tk;
  final int count;
  const _Impact({required this.tk, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tk.mint,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tk.gold.withValues(alpha: .5)),
      ),
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
              count == 0
                  ? 'أثرك عندنا غالٍ مهما صغر. جزاك الله خيرًا على نيتك الطيبة.'
                  : 'دعمتَ التطبيق ${toArabicDigits(count)} ${count == 1 ? 'مرة' : 'مرات'}، جزاك الله خيرًا وبارك فيك.',
              style:
                  cairoStyle(13.5, weight: 600, color: tk.mintInk, height: 1.7),
            ),
          ),
        ],
      ),
    );
  }
}
