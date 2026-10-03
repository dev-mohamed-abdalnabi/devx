import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/ads_service.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/support_app_button.dart';

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
    final ok = AdsService.instance.rewardedReady || await AdsService.instance.loadRewarded();
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final ads = AdsService.instance;
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
              onPressed: _loading ? null : (_failed ? _prepare : _watch),
              icon: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(_failed ? Icons.refresh_rounded : Icons.play_circle_outline_rounded),
              label: Text(_loading
                  ? 'جارٍ تحميل الإعلان...'
                  : _failed
                      ? 'إعادة المحاولة'
                      : 'شاهد إعلانًا قصيرًا لدعم التطبيق'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            ),
            if (_failed) ...[
              const SizedBox(height: 12),
              AppCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ads.friendlyError,
                        style: text.bodyMedium?.copyWith(height: 1.6, color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    SelectableText(ads.technicalError,
                        textDirection: TextDirection.ltr,
                        style: text.bodySmall?.copyWith(color: scheme.outline)),
                  ],
                ),
              ),
            ],
            if (_count > 0) ...[
              const SizedBox(height: 10),
              Text('دعمتَ التطبيق $_count ${_count == 1 ? 'مرة' : 'مرات'}، جزاك الله خيرًا',
                  textAlign: TextAlign.center,
                  style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }
}
