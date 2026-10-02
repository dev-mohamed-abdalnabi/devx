import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// إعلانات اختيارية فقط: لا يتم تهيئة SDK ولا تحميل أي إعلان إلا عندما
/// يفتح المستخدم شاشة «ادعم التطبيق» بنفسه.
class AdsService {
  AdsService._();
<<<<<<< HEAD
  static final AdsService instance = AdsService._();

  // معرّفات AdMob (App ID موجود في AndroidManifest عبر tool/patch_android.py)
  static const String rewardedUnitId = 'ca-app-pub-6238197963590573/9944188563';
  static const String bannerUnitId = 'ca-app-pub-6238197963590573/8854293168';

  // أثناء التطوير (debug) نستخدم إعلانات الاختبار الرسمية من Google لتجنب حظر الحساب.
  static const String _testRewarded = 'ca-app-pub-3940256099942544/5224354917';
  static const String _testBanner = 'ca-app-pub-3940256099942544/6300978111';

  String get _rewardedId => kDebugMode ? _testRewarded : rewardedUnitId;
  String get _bannerId => kDebugMode ? _testBanner : bannerUnitId;

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
=======
  static const appId = 'ca-app-pub-6238197963590573~3817588900';
  static const rewardedAdUnitId = 'ca-app-pub-6238197963590573/8854293168';
  static Future<String> showSupportRewardedAd() async {
    final done = Completer<bool>();
    var earned = false;
    var reason = 'لا يتوفر إعلان الآن.';
>>>>>>> 35ff277 (fix: protect AdMob release startup and explain no-fill)
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
<<<<<<< HEAD
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
=======
          onAdFailedToLoad: (error) {
            reason = error.code == 3
                ? 'لا يوجد إعلان متاح حاليًا. جرّب لاحقًا.'
                : 'تعذر تحميل الإعلان الآن.';
            if (!done.isCompleted) done.complete(false);
          },
        ),
      );
    } catch (_) { if (!done.isCompleted) done.complete(false); }
    final ok = await done.future;
    return ok ? 'شكرًا لك، ساعدت في دعم التطبيق.' : reason;
>>>>>>> 35ff277 (fix: protect AdMob release startup and explain no-fill)
  }

  BannerAd createBanner({required VoidCallback onLoaded, required VoidCallback onFailed}) {
    return BannerAd(
      adUnitId: _bannerId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => onLoaded(),
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          onFailed();
        },
      ),
    );
  }
}
