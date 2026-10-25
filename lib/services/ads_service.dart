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
  static const String rewardedUnitId = 'ca-app-pub-1413284900163582/2806535772';

  // أثناء التطوير (debug) نستخدم إعلانات الاختبار الرسمية من Google لتجنب حظر الحساب.
  static const String _testRewarded = 'ca-app-pub-3940256099942544/5224354917';

  String get _rewardedId => kDebugMode ? _testRewarded : rewardedUnitId;

  Future<void>? _initFuture;
  Future<bool>? _loading;
  RewardedAd? _rewarded;

  /// آخر خطأ حدث أثناء التحميل (كود AdMob + الرسالة) لعرضه للمستخدم وللتشخيص.
  int? lastErrorCode;
  String? lastErrorMessage;

  Future<void> init() {
    return _initFuture ??= MobileAds.instance.initialize().then((_) {}).catchError((Object e) {
      lastErrorCode = -1;
      lastErrorMessage = 'فشل تهيئة SDK: $e';
      _initFuture = null;
    });
  }

  bool get rewardedReady => _rewarded != null;

  /// رسالة مفهومة للمستخدم حسب كود الخطأ.
  String get friendlyError {
    switch (lastErrorCode) {
      case 3:
        return 'لا يوجد إعلان متاح الآن (No fill). غالبًا وحدة الإعلان جديدة أو التطبيق لم يُراجَع بعد في AdMob.';
      case 2:
        return 'تعذّر الاتصال. تأكد من الإنترنت ثم أعد المحاولة.';
      case 1:
        return 'معرّف وحدة الإعلان غير صحيح أو لا يطابق معرّف التطبيق في AdMob.';
      case 0:
        return 'خطأ داخلي في خدمة الإعلانات. أعد المحاولة بعد قليل.';
      case 9:
        return 'انتهت مهلة تحميل الإعلان. أعد المحاولة.';
      case -1:
        return 'تعذّرت تهيئة خدمة الإعلانات.';
      default:
        return 'لا يوجد إعلان متاح الآن، جرّب لاحقًا.';
    }
  }

  String get technicalError => 'AdMob [${lastErrorCode ?? '-'}] ${lastErrorMessage ?? ''}'.trim();

  /// يحمّل إعلان المكافأة مع محاولة ثانية تلقائية. الطلبات المتزامنة تشارك نفس التحميل.
  Future<bool> loadRewarded({int attempts = 2}) {
    if (_rewarded != null) return Future.value(true);
    return _loading ??= _loadWithRetry(attempts).whenComplete(() => _loading = null);
  }

  Future<bool> _loadWithRetry(int attempts) async {
    await init();
    for (var i = 0; i < attempts; i++) {
      if (await _loadOnce()) {
        lastErrorCode = null;
        lastErrorMessage = null;
        return true;
      }
      // كود 1 = طلب غير صالح (معرّف خاطئ)، إعادة المحاولة لا تفيد.
      if (lastErrorCode == 1 || i == attempts - 1) break;
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    return false;
  }

  Future<bool> _loadOnce() async {
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
          onAdFailedToLoad: (LoadAdError error) {
            _rewarded = null;
            lastErrorCode = error.code;
            lastErrorMessage = error.message;
            debugPrint('AdMob load failed: code=${error.code} domain=${error.domain} message=${error.message}');
            if (!completer.isCompleted) completer.complete(false);
          },
        ),
      );
    } catch (e) {
      lastErrorCode = -1;
      lastErrorMessage = '$e';
      if (!completer.isCompleted) completer.complete(false);
    }
    return completer.future.timeout(const Duration(seconds: 15), onTimeout: () {
      lastErrorCode = 9;
      lastErrorMessage = 'timeout';
      return false;
    });
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
      onAdFailedToShowFullScreenContent: (ad, error) {
        lastErrorCode = error.code;
        lastErrorMessage = error.message;
        ad.dispose();
        if (!done.isCompleted) done.complete(false);
      },
    );
    try {
      await ad.show(onUserEarnedReward: (_, __) => earned = true);
    } catch (e) {
      lastErrorCode = -1;
      lastErrorMessage = '$e';
      ad.dispose();
      return false;
    }
    return done.future;
  }
}
