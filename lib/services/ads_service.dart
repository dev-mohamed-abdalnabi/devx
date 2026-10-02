import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdsService {
  AdsService._();

  static const appId = 'ca-app-pub-6238197963590573~3817588900';
  static const rewardedAdUnitId = 'ca-app-pub-6238197963590573/8854293168';

  static Future<bool> showSupportRewardedAd() async {
    final completer = Completer<bool>();
    var earned = false;
    await RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              if (!completer.isCompleted) completer.complete(earned);
            },
            onAdFailedToShowFullScreenContent: (ad, _) {
              ad.dispose();
              if (!completer.isCompleted) completer.complete(false);
            },
          );
          ad.show(onUserEarnedReward: (_, __) => earned = true);
        },
        onAdFailedToLoad: (_) {
          if (!completer.isCompleted) completer.complete(false);
        },
      ),
    );
    return completer.future;
  }
}
