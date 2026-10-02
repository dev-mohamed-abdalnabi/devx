import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/ads_service.dart';
import '../../widgets/app_ui.dart';

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
  bool _bannerOn = false;
  bool _bannerLoaded = false;
  BannerAd? _banner;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => _count = p.getInt(_countKey) ?? 0);
    });
  }

  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _watch() async {
    if (_loading) return;
    setState(() => _loading = true);
    final ready = AdsService.instance.rewardedReady || await AdsService.instance.loadRewarded();
    if (!mounted) return;
    if (!ready) {
      setState(() => _loading = false);
      _snack('لا يوجد إعلان متاح الآن، جرّب لاحقًا. شكرًا لنيتك الطيبة 🤍');
      return;
    }
    setState(() => _loading = false);
    final watched = await AdsService.instance.showRewarded();
    if (watched) {
      final prefs = await SharedPreferences.getInstance();
      final next = (prefs.getInt(_countKey) ?? 0) + 1;
      await prefs.setInt(_countKey, next);
      if (mounted) setState(() => _count = next);
      _snack('جزاك الله خيرًا، شكرًا لدعمك التطبيق 🤍');
    }
  }

  Future<void> _toggleBanner(bool on) async {
    if (!on) {
      _banner?.dispose();
      setState(() {
        _banner = null;
        _bannerOn = false;
        _bannerLoaded = false;
      });
      return;
    }
    setState(() => _bannerOn = true);
    await AdsService.instance.init();
    if (!mounted || !_bannerOn) return;
    final banner = AdsService.instance.createBanner(
      onLoaded: () {
        if (mounted) setState(() => _bannerLoaded = true);
      },
      onFailed: () {
        if (mounted) {
          setState(() {
            _banner = null;
            _bannerOn = false;
            _bannerLoaded = false;
          });
          _snack('تعذر تحميل الإعلان الآن.');
        }
      },
    );
    setState(() => _banner = banner);
    await banner.load();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('ادعم التطبيق')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.volunteer_activism_outlined, color: scheme.primary, size: 30),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('التطبيق مجاني وبلا إعلانات إجبارية',
                          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Text(
                    'إن أحببت أن تدعم استمرار التطبيق وتطويره، يمكنك مشاهدة إعلان قصير بإرادتك. لا شيء يتغير في التطبيق إن لم تفعل، وهو اختياري تمامًا.',
                    style: text.bodyMedium?.copyWith(height: 1.7, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loading ? null : _watch,
              icon: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.play_circle_outline_rounded),
              label: Text(_loading ? 'جارٍ تحميل الإعلان...' : 'شاهد إعلانًا قصيرًا لدعم التطبيق'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            ),
            if (_count > 0) ...[
              const SizedBox(height: 10),
              Text('دعمتَ التطبيق $_count ${_count == 1 ? 'مرة' : 'مرات'}، جزاك الله خيرًا',
                  textAlign: TextAlign.center,
                  style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            ],
            const SizedBox(height: 20),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: SwitchListTile(
                value: _bannerOn,
                onChanged: _toggleBanner,
                title: const Text('إظهار إعلان صغير في هذه الشاشة', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('يظهر هنا فقط ما دمت فاتح هذه الشاشة'),
              ),
            ),
            if (_bannerOn && _bannerLoaded && _banner != null) ...[
              const SizedBox(height: 12),
              Center(
                child: SizedBox(
                  width: _banner!.size.width.toDouble(),
                  height: _banner!.size.height.toDouble(),
                  child: AdWidget(ad: _banner!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
