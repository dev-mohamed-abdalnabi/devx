import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:provider/provider.dart';
import '../../core/prayer_times.dart';
import '../../core/text_utils.dart';
import '../../providers/prayer_provider.dart';
import 'city_picker_screen.dart';

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  StreamSubscription<CompassEvent>? _sub;
  double? _heading;
  bool _noSensor = false;
  bool _aligned = false;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    final stream = FlutterCompass.events;
    if (stream == null) {
      _noSensor = true;
    } else {
      _sub = stream.listen(_onEvent, onError: (_) {
        if (mounted) setState(() => _noSensor = true);
      });
    }
  }

  void _onEvent(CompassEvent e) {
    final h = e.heading;
    if (h == null) {
      if (_heading == null && mounted) setState(() => _noSensor = true);
      return;
    }
    final target = (h + 360) % 360;
    final old = _heading;
    double next;
    if (old == null) {
      next = target;
    } else {
      // تنعيم دائري كي لا تهتز الإبرة ولا تقفز عند المرور بالصفر.
      final delta = ((target - old + 540) % 360) - 180;
      next = (old + delta * 0.25 + 360) % 360;
    }
    final q = context.read<PrayerProvider>().qibla;
    if (q != null) {
      final diff = ((q - next + 540) % 360) - 180;
      final nowAligned = diff.abs() <= 3;
      if (nowAligned && !_aligned) HapticFeedback.mediumImpact();
      _aligned = nowAligned;
    }
    if (mounted) {
      setState(() {
        _heading = next;
        _noSensor = false;
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PrayerProvider>();
    final scheme = Theme.of(context).colorScheme;

    if (!p.hasLocation) {
      return Scaffold(
        appBar: AppBar(title: const Text('القبلة')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('نحتاج موقعك لحساب اتجاه القبلة.', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const CityPickerScreen())),
                  icon: const Icon(Icons.location_city),
                  label: const Text('اختيار مدينة'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: p.locating
                      ? null
                      : () async {
                          final error = await context.read<PrayerProvider>().useGps();
                          if (mounted && error != null) setState(() => _locationError = error);
                        },
                  icon: const Icon(Icons.my_location),
                  label: const Text('تحديد تلقائي'),
                ),
                if (_locationError != null) ...[
                  const SizedBox(height: 12),
                  Text(_locationError!, textAlign: TextAlign.center),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final q = p.qibla!;
    final km = distanceToKaabaKm(p.lat!, p.lng!);
    final heading = _heading ?? 0;
    final color = _aligned ? scheme.primary : scheme.secondary;

    return Scaffold(
      appBar: AppBar(title: const Text('القبلة')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: SizedBox(
              width: 300,
              height: 320,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Positioned(
                    top: 0,
                    child: Icon(Icons.arrow_drop_down, size: 36, color: color),
                  ),
                  Positioned(
                    bottom: 0,
                    child: Transform.rotate(
                      angle: -heading * math.pi / 180,
                      child: SizedBox(
                        width: 300,
                        height: 300,
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: _aligned ? scheme.primary : scheme.outlineVariant,
                                    width: 3),
                              ),
                            ),
                            const _DialLabel('ش', Alignment.topCenter),
                            const _DialLabel('ق', Alignment.centerRight),
                            const _DialLabel('ج', Alignment.bottomCenter),
                            const _DialLabel('غ', Alignment.centerLeft),
                            Transform.rotate(
                              angle: q * math.pi / 180,
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 34),
                                  child: Icon(Icons.navigation, size: 72, color: color),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _aligned ? 'أنت باتجاه القبلة' : 'دوّر الهاتف حتى تصعد الإبرة إلى العلامة',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: _aligned ? scheme.primary : null),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('الموقع: ${p.placeName}'),
                  const SizedBox(height: 4),
                  Text('اتجاه القبلة: ${toArabicDigits(q.round())}° من الشمال'),
                  const SizedBox(height: 4),
                  Text('المسافة إلى الكعبة: نحو ${toArabicDigits(km.round())} كم'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_noSensor)
            const Text(
              'لا يتوفر مستشعر بوصلة على هذا الجهاز. استخدم زاوية القبلة أعلاه مع بوصلة أخرى.',
              textAlign: TextAlign.center,
            )
          else if (_heading == null)
            const Center(child: CircularProgressIndicator())
          else
            Text(
              'البوصلة تتأثر بالمعادن والمغناطيس القريب. إن بدت غير دقيقة، حرّك الهاتف على شكل ٨ لمعايرتها، '
              'وابتعد عن الأجهزة الكهربائية.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }
}

class _DialLabel extends StatelessWidget {
  final String text;
  final Alignment alignment;
  const _DialLabel(this.text, this.alignment);

  @override
  Widget build(BuildContext context) => Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      );
}
