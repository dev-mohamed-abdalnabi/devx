import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart' show Color;
import 'package:just_audio/just_audio.dart';

import '../providers/notification_service.dart';

/// الجسر بين مشغل just_audio وإشعار الميديا (audio_service).
///
/// كل ما يظهر في الإشعار وشاشة القفل يخرج من هنا:
///  - [mediaItem]  = اسم السورة والقارئ
///  - [playbackState] = حالة التشغيل + الأزرار + الموضع
/// والأوامر القادمة من الإشعار (تشغيل/إيقاف/التالي/السابق/تقديم) تُرد إلى المزوّد.
class QuranAudioHandler extends BaseAudioHandler with SeekHandler {
  QuranAudioHandler(this.player) {
    _subs.addAll([
      player.playbackEventStream.listen((_) => _broadcast(), onError: (Object e, StackTrace s) {}),
      player.playingStream.listen((_) => _broadcast()),
      player.processingStateStream.listen((_) => _broadcast()),
      player.speedStream.listen((_) => _broadcast()),
      player.durationStream.listen(_onDuration),
    ]);
  }

  final AudioPlayer player;
  final List<StreamSubscription<dynamic>> _subs = [];

  /// يضبطها المزوّد: ما يحدث عند ضغط أزرار الإشعار.
  Future<void> Function()? onPlay;
  Future<void> Function()? onSkipNext;
  Future<void> Function()? onSkipPrevious;
  Future<void> Function()? onBeforeStop;

  static const Map<ProcessingState, AudioProcessingState> _states = {
    ProcessingState.idle: AudioProcessingState.idle,
    ProcessingState.loading: AudioProcessingState.loading,
    ProcessingState.buffering: AudioProcessingState.buffering,
    ProcessingState.ready: AudioProcessingState.ready,
    ProcessingState.completed: AudioProcessingState.completed,
  };

  // أيقونات الأزرار من حزمة azkari_native (محمية من الحذف بملف keep.xml).
  static const MediaControl _playControl =
      MediaControl(androidIcon: 'drawable/ic_media_play', label: 'تشغيل', action: MediaAction.play);
  static const MediaControl _pauseControl =
      MediaControl(androidIcon: 'drawable/ic_media_pause', label: 'إيقاف مؤقت', action: MediaAction.pause);
  static const MediaControl _nextControl =
      MediaControl(androidIcon: 'drawable/ic_media_next', label: 'التالي', action: MediaAction.skipToNext);
  static const MediaControl _previousControl =
      MediaControl(androidIcon: 'drawable/ic_media_previous', label: 'السابق', action: MediaAction.skipToPrevious);

  void _broadcast() {
    final playing = player.playing;
    playbackState.add(PlaybackState(
      controls: [_previousControl, if (playing) _pauseControl else _playControl, _nextControl],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: _states[player.processingState] ?? AudioProcessingState.idle,
      playing: playing,
      updatePosition: player.position,
      bufferedPosition: player.bufferedPosition,
      speed: player.speed,
    ));
  }

  void _onDuration(Duration? duration) {
    final item = mediaItem.value;
    if (item == null || duration == null || item.duration == duration) return;
    mediaItem.add(item.copyWith(duration: duration));
  }

  @override
  Future<void> play() async {
    final callback = onPlay;
    if (callback != null) {
      await callback();
    } else {
      unawaited(player.play());
    }
  }

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> setSpeed(double speed) => player.setSpeed(speed);

  @override
  Future<void> skipToNext() async {
    final callback = onSkipNext;
    if (callback != null) await callback();
  }

  @override
  Future<void> skipToPrevious() async {
    final callback = onSkipPrevious;
    if (callback != null) await callback();
  }

  @override
  Future<void> stop() async {
    final callback = onBeforeStop;
    if (callback != null) await callback();
    await player.stop();
    await super.stop();
  }
}

/// نقطة التهيئة الوحيدة لخدمة الميديا + المشغل المشترك.
/// لا ترمي أخطاء أبدًا: لو فشلت التهيئة يعمل التشغيل بدون إشعار ويظهر السبب في شاشة الفحص.
class QuranAudioService {
  QuranAudioService._();

  static AudioPlayer? _player;

  /// مشغل واحد مشترك بين الواجهة والإشعار.
  static AudioPlayer get player => _player ??= AudioPlayer();

  static QuranAudioHandler? handler;
  static String? initError;

  static Future<void> init() async {
    if (handler != null) return;
    final done = Completer<void>();
    AudioService.init<QuranAudioHandler>(
      builder: () => QuranAudioHandler(player),
      config: AudioServiceConfig(
        androidNotificationChannelId: NotificationService.mediaChannelId,
        androidNotificationChannelName: 'تلاوة القرآن',
        androidNotificationChannelDescription: 'التحكم في تلاوة القرآن من الإشعارات',
        androidNotificationIcon: NotificationService.mediaIcon,
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
        notificationColor: const Color(0xFF2F6B55),
      ),
    ).then<void>((h) {
      handler = h;
      initError = null;
    }, onError: (Object e) {
      initError = e.toString();
    }).whenComplete(() {
      if (!done.isCompleted) done.complete();
    });
    // لو علّقت التهيئة لا نمنع فتح التطبيق؛ وإن اكتملت لاحقًا يلتقطها المزوّد تلقائيًا.
    await done.future.timeout(const Duration(seconds: 10), onTimeout: () {
      initError ??= 'انتهت مهلة تهيئة خدمة الميديا (10 ثوانٍ)';
    });
  }
}
