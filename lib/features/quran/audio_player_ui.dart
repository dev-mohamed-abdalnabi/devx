import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../../core/text_utils.dart';
import '../../core/theme.dart';
import '../../providers/quran_audio_provider.dart';

/// نجمة خماسية تحمل رقم السورة.
class StarBadge extends StatelessWidget {
  final int number;
  final double size;
  final Color fill;
  final Color textColor;

  const StarBadge({
    super.key,
    required this.number,
    required this.fill,
    required this.textColor,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _StarPainter(fill),
        child: Center(
          child: Text(
            toArabicDigits(number),
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w700,
              fontSize: size * (number > 99 ? 0.28 : 0.34),
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _StarPainter extends CustomPainter {
  final Color color;
  _StarPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final radius = i.isEven ? r : r * 0.46;
      final a = -math.pi / 2 + i * math.pi / 5;
      final p =
          Offset(c.dx + radius * math.cos(a), c.dy + radius * math.sin(a));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.color != color;
}

/// أعمدة موجية صغيرة تدل على أن السورة تعمل الآن.
class EqualizerBars extends StatefulWidget {
  final bool animate;
  final Color color;
  const EqualizerBars({super.key, required this.animate, required this.color});

  @override
  State<EqualizerBars> createState() => _EqualizerBarsState();
}

class _EqualizerBarsState extends State<EqualizerBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat();
  }

  @override
  void didUpdateWidget(EqualizerBars old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.animate && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 18,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < 3; i++)
              Container(
                width: 4,
                height: widget.animate
                    ? 5 +
                        13 *
                            (0.5 +
                                    0.5 *
                                        math.sin(
                                            _c.value * 2 * math.pi + i * 1.9))
                                .abs()
                    : 7,
                decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(2)),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  final QuranAudioProvider audio;
  final double size;
  const _PlayButton({required this.audio, required this.size});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<PlayerState>(
      stream: audio.player.playerStateStream,
      builder: (_, snap) {
        final state = snap.data;
        final loading = state != null &&
            (state.processingState == ProcessingState.loading ||
                state.processingState == ProcessingState.buffering);
        final playing = state?.playing ?? false;
        final enabled = audio.hasAnyAudio;
        return Tooltip(
          message: playing ? 'إيقاف مؤقت' : 'تشغيل',
          child: Material(
            color: enabled ? scheme.primary : scheme.surfaceContainerHighest,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: enabled ? audio.togglePlay : null,
              child: SizedBox(
                width: size,
                height: size,
                child: loading
                    ? Padding(
                        padding: EdgeInsets.all(size * 0.3),
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: scheme.onPrimary),
                      )
                    : Icon(
                        playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: size * 0.6,
                        color: enabled
                            ? scheme.onPrimary
                            : scheme.onSurfaceVariant,
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// المشغل المصغّر الثابت أسفل الشاشة. يظهر دائمًا ويفتح المشغل الكامل عند الضغط.
class AudioMiniPlayer extends StatelessWidget {
  const AudioMiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<QuranAudioProvider>();
    final scheme = Theme.of(context).colorScheme;
    final surah = audio.displaySurah;
    final canSeek = audio.currentSurah != null;

    return Material(
      color: scheme.surface,
      elevation: 8,
      shadowColor: Colors.black54,
      surfaceTintColor: scheme.primary,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ThinProgress(audio: audio),
            InkWell(
              onTap: surah != null ? () => showFullPlayer(context) : null,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  children: [
                    surah != null
                        ? StarBadge(
                            number: surah,
                            size: 44,
                            fill: scheme.primaryContainer,
                            textColor: scheme.primary,
                          )
                        : Icon(Icons.headphones_rounded,
                            size: 32, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            surah != null
                                ? 'سورة ${QuranAudioProvider.surahName(surah)}'
                                : 'اختر سورة للاستماع',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            audio.sleepActive
                                ? _sleepLabel(audio)
                                : audio.selectedReciter.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'تأخير ١٠ ثوانٍ',
                            onPressed: canSeek
                                ? () =>
                                    audio.seekBy(-QuranAudioProvider.seekStep)
                                : null,
                            icon: const Icon(Icons.replay_10_rounded),
                          ),
                          _PlayButton(audio: audio, size: 48),
                          IconButton(
                            tooltip: 'تقديم ١٠ ثوانٍ',
                            onPressed: canSeek
                                ? () =>
                                    audio.seekBy(QuranAudioProvider.seekStep)
                                : null,
                            icon: const Icon(Icons.forward_10_rounded),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _sleepLabel(QuranAudioProvider audio) {
  if (audio.sleepAtSurahEnd) return 'سيتوقف عند نهاية السورة';
  final left = audio.sleepRemaining ?? Duration.zero;
  return 'سيتوقف بعد ${formatAudioTime(left)}';
}

class _ThinProgress extends StatelessWidget {
  final QuranAudioProvider audio;
  const _ThinProgress({required this.audio});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<Duration>(
      stream: audio.player.positionStream,
      builder: (_, snap) {
        final total = audio.player.duration?.inMilliseconds ?? 0;
        final pos = snap.data?.inMilliseconds ?? 0;
        return Directionality(
          textDirection: TextDirection.ltr,
          child: LinearProgressIndicator(
            minHeight: 3,
            value: total <= 0 ? 0 : (pos / total).clamp(0.0, 1.0),
            backgroundColor: scheme.surfaceContainerHighest,
            color: scheme.primary,
          ),
        );
      },
    );
  }
}

Future<void> showFullPlayer(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const _FullPlayer(),
  );
}

class _FullPlayer extends StatelessWidget {
  const _FullPlayer();

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<QuranAudioProvider>();
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final surah = audio.displaySurah;
    final canSeek = audio.currentSurah != null;

    if (surah == null) {
      return const SizedBox(
          height: 200, child: Center(child: Text('اختر سورة للاستماع')));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          StarBadge(
              number: surah,
              size: 132,
              fill: scheme.primaryContainer,
              textColor: scheme.primary),
          const SizedBox(height: 16),
          Text(
            'سورة ${QuranAudioProvider.surahName(surah)}',
            style: TextStyle(
              fontFamily: AppTheme.quranFont,
              fontSize: 32,
              color: scheme.onSurface,
              height: 1.4,
            ),
          ),
          Text(audio.selectedReciter.name,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 20),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Column(
              children: [
                _SeekBar(audio: audio),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _ShuffleButton(audio: audio),
                    IconButton(
                      iconSize: 34,
                      tooltip: 'السابق',
                      onPressed: canSeek ? audio.previous : null,
                      icon: const Icon(Icons.skip_previous_rounded),
                    ),
                    IconButton(
                      iconSize: 36,
                      tooltip: 'تأخير ١٠ ثوانٍ',
                      onPressed: canSeek
                          ? () => audio.seekBy(-QuranAudioProvider.seekStep)
                          : null,
                      icon: const Icon(Icons.replay_10_rounded),
                    ),
                    _PlayButton(audio: audio, size: 68),
                    IconButton(
                      iconSize: 36,
                      tooltip: 'تقديم ١٠ ثوانٍ',
                      onPressed: canSeek
                          ? () => audio.seekBy(QuranAudioProvider.seekStep)
                          : null,
                      icon: const Icon(Icons.forward_10_rounded),
                    ),
                    IconButton(
                      iconSize: 34,
                      tooltip: 'التالي',
                      onPressed: canSeek ? audio.next : null,
                      icon: const Icon(Icons.skip_next_rounded),
                    ),
                    _RepeatButton(audio: audio),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text('سرعة التشغيل', style: text.labelLarge),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in QuranAudioProvider.speeds)
                ChoiceChip(
                  label: Text(_speedLabel(s)),
                  selected: audio.speed == s,
                  onSelected: (_) => audio.setSpeed(s),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showSleepSheet(context),
                  icon: Icon(audio.sleepActive
                      ? Icons.bedtime_rounded
                      : Icons.bedtime_outlined),
                  label: Text(
                    audio.sleepActive ? _sleepLabel(audio) : 'مؤقت النوم',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filledTonal(
                tooltip: audio.isFavorite(surah)
                    ? 'إزالة من المفضلة'
                    : 'إضافة إلى المفضلة',
                onPressed: () => audio.toggleFavorite(surah),
                icon: Icon(audio.isFavorite(surah)
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _speedLabel(double s) =>
    s == s.truncateToDouble() ? '${s.toInt()}×' : '$s×';

class _ShuffleButton extends StatelessWidget {
  final QuranAudioProvider audio;
  const _ShuffleButton({required this.audio});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: audio.shuffle ? 'إيقاف العشوائي' : 'تشغيل عشوائي',
      onPressed: audio.toggleShuffle,
      icon: Icon(Icons.shuffle_rounded,
          color: audio.shuffle ? scheme.primary : scheme.onSurfaceVariant),
    );
  }
}

class _RepeatButton extends StatelessWidget {
  final QuranAudioProvider audio;
  const _RepeatButton({required this.audio});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final on = audio.repeat != AudioRepeat.off;
    return IconButton(
      tooltip: switch (audio.repeat) {
        AudioRepeat.off => 'بدون تكرار',
        AudioRepeat.all => 'تكرار الكل',
        AudioRepeat.one => 'تكرار السورة',
      },
      onPressed: audio.cycleRepeat,
      icon: Icon(
        audio.repeat == AudioRepeat.one
            ? Icons.repeat_one_rounded
            : Icons.repeat_rounded,
        color: on ? scheme.primary : scheme.onSurfaceVariant,
      ),
    );
  }
}

class _SeekBar extends StatefulWidget {
  final QuranAudioProvider audio;
  const _SeekBar({required this.audio});

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? _drag;

  @override
  Widget build(BuildContext context) {
    final player = widget.audio.player;
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return StreamBuilder<Duration?>(
      stream: player.durationStream,
      builder: (_, durSnap) {
        final duration = durSnap.data ?? player.duration ?? Duration.zero;
        final max = duration.inMilliseconds.toDouble();
        return StreamBuilder<Duration>(
          stream: player.positionStream,
          builder: (_, posSnap) {
            final pos =
                (posSnap.data ?? Duration.zero).inMilliseconds.toDouble();
            final value = (_drag ?? pos).clamp(0.0, max <= 0 ? 1.0 : max);
            return Column(
              children: [
                Slider(
                  value: value,
                  max: max <= 0 ? 1.0 : max,
                  onChanged: max <= 0 ? null : (v) => setState(() => _drag = v),
                  onChangeEnd: (v) {
                    widget.audio.seekTo(Duration(milliseconds: v.round()));
                    setState(() => _drag = null);
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                          formatAudioTime(
                              Duration(milliseconds: value.round())),
                          style: style),
                      Text(formatAudioTime(duration), style: style),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

Future<void> _showSleepSheet(BuildContext context) {
  final audio = context.read<QuranAudioProvider>();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      void pick(VoidCallback action) {
        action();
        Navigator.of(sheetContext).pop();
      }

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text('إيقاف التشغيل تلقائيًا',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              ),
            ),
            for (final m in const [10, 15, 30, 45, 60])
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: Text('بعد ${toArabicDigits(m)} دقيقة'),
                onTap: () =>
                    pick(() => audio.setSleepTimer(Duration(minutes: m))),
              ),
            ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: const Text('عند نهاية السورة'),
              onTap: () => pick(audio.setSleepAtSurahEnd),
            ),
            if (audio.sleepActive)
              ListTile(
                leading: const Icon(Icons.timer_off_outlined),
                title: const Text('إلغاء المؤقت'),
                onTap: () => pick(audio.clearSleepTimer),
              ),
          ],
        ),
      );
    },
  );
}
