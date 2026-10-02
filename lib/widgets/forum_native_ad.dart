import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/ads_service.dart';

class ForumNativeAd extends StatefulWidget {
  const ForumNativeAd({super.key});

  @override
  State<ForumNativeAd> createState() => _ForumNativeAdState();
}

class _ForumNativeAdState extends State<ForumNativeAd> {
  NativeAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    final ad = NativeAd(
      adUnitId: AdsService.nativeAdUnitId,
      factoryId: 'forum',
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) => ad.dispose(),
      ),
    );
    _ad = ad;
    ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _ad == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Text('إعلان', style: TextStyle(fontSize: 11)),
            ),
            SizedBox(height: 105, child: AdWidget(ad: _ad!)),
          ],
        ),
      ),
    );
  }
}
