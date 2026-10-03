import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// إعلانات اختيارية فقط: لا يتم تهيئة SDK ولا تحميل أي إعلان إلا عندما
/// يفتح المستخدم شاشة «ادعم التطبيق» بنفسه.
class AdsService {
  AdsService._();
  static final AdsService instance = AdsService._();

  // معرّفات AdMob (App ID موجود في AndroidManifest عبر tool/patch_android.py)
  // /885... هو Rewarded الذي أرسله المستخدم، و/994... وحدة Native وليست Banner.
  static const String rewardedUnitId = 'ca-app-pub-6238197963590573/8854293168';

  // أثناء التطوير (debug) نستخدم إعلانات الاختبار الرسمية من Google لتجنب حظر الحساب.
  static const String _testRewarded = 'ca-app-pub-3940256099942544/5224354917';

  String get _rewardedId => kDebugMode ? _testRewarded : rewardedUnitId;

  Future<void>? _initFuture;
  RewardedAd? _rewarded;
  bool _loadingRewarded = false;

  Future<void> init() {
    return _initFuture ??= MobileAds.instance.initialize().then((_) {}).catchError((_) {
      _initFuture = null;
    });
  }

  bool get rewardedReady => _rewarded != null;

  Future<bool> loadRewarded() async {
    if (_rewarded != null) return true;
    if (_loadingRewarded) return false;
    _loadingRewarded = true;
    await init();
    final completer = Completer<bool>();
    try {
      await RewardedAd.load(
        adUnitId: _rewardedId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewarded = ad;
            if (!completer.isCompleted) completer.complete(true);
          },
          onAdFailedToLoad: (_) {
            _rewarded = null;
            if (!completer.isCompleted) completer.complete(false);
          },
        ),
      );
    } catch (_) {
      if (!completer.isCompleted) completer.complete(false);
    }
    final ok = await completer.future.timeout(const Duration(seconds: 20), onTimeout: () => false);
    _loadingRewarded = false;
    return ok;
  }

  /// يعرض إعلان المكافأة. يرجع true إذا شاهده المستخدم حتى النهاية.
  Future<bool> showRewarded() async {
    final ad = _rewarded;
    if (ad == null) return false;
    _rewarded = null;
    final done = Completer<bool>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!done.isCompleted) done.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        if (!done.isCompleted) done.complete(false);
      },
    );
    try {
      await ad.show(onUserEarnedReward: (_, __) => earned = true);
    } catch (_) {
      ad.dispose();
      return false;
    }
    return done.future;
  }

}
