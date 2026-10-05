import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../../core/home_tokens.dart';
import '../../core/star_shape.dart';
import '../../core/text_utils.dart';
import '../../core/theme.dart';
import '../../providers/quran_audio_provider.dart';
import '../home/home_art.dart';

/// نجمة ثمانية تحمل رقم السورة.
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
        painter: IslamicStarPainter(fill),
        child: Center(
          child: Text(
            toArabicDigits(number),
            style: TextStyle(
              fontFamily: 'Cairo',
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
    final tk = HomeTokens.of(context);
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
            color: enabled ? tk.leaf : tk.line,
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
                            strokeWidth: 2.5, color: tk.mintInk),
                      )
                    : Icon(
                        playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: size * 0.6,
                        color: enabled ? tk.mintInk : tk.muted,
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
    final tk = HomeTokens.of(context);
    final surah = audio.displaySurah;
    final canSeek = audio.currentSurah != null;

    return Material(
      color: tk.card,
      elevation: 0,
      shape: Border(top: BorderSide(color: tk.line)),
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
                            fill: tk.mint,
                            textColor: tk.mintInk,
                          )
                        : Icon(Icons.headphones_rounded,
                            size: 32, color: tk.muted),
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
                            style: cairoStyle(15, weight: 700, color: tk.ink),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            audio.sleepActive
                                ? _sleepLabel(audio)
                                : audio.selectedReciter.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: cairoStyle(12, color: tk.muted),
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
                            icon: Icon(Icons.replay_10_rounded, color: tk.gold),
                          ),
                          _PlayButton(audio: audio, size: 48),
                          IconButton(
                            tooltip: 'تقديم ١٠ ثوانٍ',
                            onPressed: canSeek
                                ? () =>
                                    audio.seekBy(QuranAudioProvider.seekStep)
                                : null,
                            icon:
                                Icon(Icons.forward_10_rounded, color: tk.gold),
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
    final tk = HomeTokens.of(context);
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
            backgroundColor: tk.line,
            color: tk.leaf,
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
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    builder: (_) => const _FullPlayer(),
  );
}

// ───────────────────────── المشغل الكامل (هوية التطبيق) ─────────────────────────

class _FullPlayer extends StatelessWidget {
  const _FullPlayer();

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<QuranAudioProvider>();
    final tk = HomeTokens.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surah = audio.displaySurah;
    final canSeek = audio.currentSurah != null;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tk.bg,
          border:
              Border(top: BorderSide(color: tk.gold.withValues(alpha: .45))),
        ),
        child: Stack(
          children: [
            // نقش النجمة نفسه المستخدم في كل الشاشات.
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: IslamicPatternPainter(opacity: dark ? .07 : .10),
                ),
              ),
            ),
            // وهج علوي ناعم خلف النجمة.
            Positioned(
              top: -60,
              left: 0,
              right: 0,
              height: 340,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -.2),
                      radius: .8,
                      colors: [
                        tk.leaf.withValues(alpha: dark ? .20 : .16),
                        tk.leaf.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: surah == null
                  ? SizedBox(
                      height: 220,
                      child: Center(
                        child: Text('اختر سورة للاستماع',
                            style:
                                cairoStyle(15, weight: 600, color: tk.muted)),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(22, 10, 22, 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 44,
                            height: 4,
                            decoration: BoxDecoration(
                              color: tk.gold.withValues(alpha: .55),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: tk.mint,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    EqualizerBars(
                                        animate: audio.player.playing,
                                        color: tk.mintInk),
                                    const SizedBox(width: 8),
                                    Text('القرآن صوتيًا',
                                        style: cairoStyle(12,
                                            weight: 600, color: tk.mintInk)),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                tooltip: 'إغلاق',
                                onPressed: () => Navigator.of(context).pop(),
                                icon: Icon(Icons.keyboard_arrow_down_rounded,
                                    size: 30, color: tk.muted),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          _StarArt(audio: audio, surah: surah, tk: tk),
                          const SizedBox(height: 14),
                          Text(
                            'سورة ${QuranAudioProvider.surahName(surah)}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: AppTheme.quranFont,
                              fontSize: 36,
                              color: tk.ink,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                    color: tk.gold, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  audio.selectedReciter.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: cairoStyle(14,
                                      weight: 600, color: tk.gold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: Column(
                              children: [
                                _SeekBar(audio: audio, tk: tk),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    _CtrlIcon(
                                      icon: Icons.skip_previous_rounded,
                                      size: 36,
                                      tooltip: 'السابق',
                                      color: tk.ink,
                                      onTap: canSeek ? audio.previous : null,
                                    ),
                                    _CtrlIcon(
                                      icon: Icons.replay_10_rounded,
                                      size: 34,
                                      tooltip: 'تأخير ١٠ ثوانٍ',
                                      color: tk.gold,
                                      onTap: canSeek
                                          ? () => audio.seekBy(
                                              -QuranAudioProvider.seekStep)
                                          : null,
                                    ),
                                    _BigPlay(audio: audio, tk: tk),
                                    _CtrlIcon(
                                      icon: Icons.forward_10_rounded,
                                      size: 34,
                                      tooltip: 'تقديم ١٠ ثوانٍ',
                                      color: tk.gold,
                                      onTap: canSeek
                                          ? () => audio.seekBy(
                                              QuranAudioProvider.seekStep)
                                          : null,
                                    ),
                                    _CtrlIcon(
                                      icon: Icons.skip_next_rounded,
                                      size: 36,
                                      tooltip: 'التالي',
                                      color: tk.ink,
                                      onTap: canSeek ? audio.next : null,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          _SpeedPicker(audio: audio, tk: tk),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _Tile(
                                  tk: tk,
                                  icon: Icons.shuffle_rounded,
                                  label: 'عشوائي',
                                  active: audio.shuffle,
                                  onTap: audio.toggleShuffle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _Tile(
                                  tk: tk,
                                  icon: audio.repeat == AudioRepeat.one
                                      ? Icons.repeat_one_rounded
                                      : Icons.repeat_rounded,
                                  label: switch (audio.repeat) {
                                    AudioRepeat.off => 'بدون تكرار',
                                    AudioRepeat.all => 'تكرار الكل',
                                    AudioRepeat.one => 'تكرار السورة',
                                  },
                                  active: audio.repeat != AudioRepeat.off,
                                  onTap: audio.cycleRepeat,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _Tile(
                                  tk: tk,
                                  icon: audio.sleepActive
                                      ? Icons.bedtime_rounded
                                      : Icons.bedtime_outlined,
                                  label: audio.sleepActive
                                      ? (audio.sleepAtSurahEnd
                                          ? 'نهاية السورة'
                                          : formatAudioTime(
                                              audio.sleepRemaining ??
                                                  Duration.zero))
                                      : 'مؤقت النوم',
                                  active: audio.sleepActive,
                                  onTap: () => _showSleepSheet(context),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _Tile(
                                  tk: tk,
                                  icon: audio.isFavorite(surah)
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  label: audio.isFavorite(surah)
                                      ? 'في المفضلة'
                                      : 'المفضلة',
                                  active: audio.isFavorite(surah),
                                  onTap: () => audio.toggleFavorite(surah),
                                ),
                              ),
                            ],
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

/// نجمة الغلاف: نجمة مملوءة بتدرّج + إطاران ذهبيان يدوران ببطء أثناء التشغيل.
class _StarArt extends StatefulWidget {
  final QuranAudioProvider audio;
  final int surah;
  final HomeTokens tk;
  const _StarArt({required this.audio, required this.surah, required this.tk});

  @override
  State<_StarArt> createState() => _StarArtState();
}

class _StarArtState extends State<_StarArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 48));
  StreamSubscription<bool>? _sub;

  @override
  void initState() {
    super.initState();
    if (widget.audio.player.playing) _c.repeat();
    _sub = widget.audio.player.playingStream.listen((p) {
      if (!mounted) return;
      if (p && !_c.isAnimating) {
        _c.repeat();
      } else if (!p && _c.isAnimating) {
        _c.stop();
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tk = widget.tk;
    final fillB = Color.lerp(tk.mint, tk.leaf, .42)!;
    return SizedBox(
      width: 250,
      height: 250,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RotationTransition(
            turns: _c,
            child: CustomPaint(
              size: const Size(250, 250),
              painter: _StarOutlinePainter(tk.gold.withValues(alpha: .55), 1.3),
            ),
          ),
          RotationTransition(
            turns: ReverseAnimation(_c),
            child: Transform.scale(
              scale: .84,
              child: Transform.rotate(
                angle: math.pi / 8,
                child: CustomPaint(
                  size: const Size(250, 250),
                  painter:
                      _StarOutlinePainter(tk.gold.withValues(alpha: .32), 1),
                ),
              ),
            ),
          ),
          Container(
            width: 168,
            height: 168,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: tk.leaf.withValues(alpha: .30),
                  blurRadius: 40,
                  spreadRadius: 4,
                ),
              ],
            ),
          ),
          CustomPaint(
            size: const Size(172, 172),
            painter:
                _GradStarPainter(tk.mint, fillB, tk.gold.withValues(alpha: .6)),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('سورة',
                  style: cairoStyle(12,
                      weight: 600, color: tk.mintInk.withValues(alpha: .8))),
              Text(
                toArabicDigits(widget.surah),
                style: TextStyle(
                  fontFamily: 'Amiri',
                  fontWeight: FontWeight.w700,
                  fontSize: widget.surah > 99 ? 50 : 58,
                  height: 1.05,
                  color: tk.mintInk,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StarOutlinePainter extends CustomPainter {
  final Color color;
  final double width;
  const _StarOutlinePainter(this.color, this.width);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      islamicStarPath(size),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_StarOutlinePainter o) =>
      o.color != color || o.width != width;
}

class _GradStarPainter extends CustomPainter {
  final Color a, b, stroke;
  const _GradStarPainter(this.a, this.b, this.stroke);

  @override
  void paint(Canvas canvas, Size size) {
    final path = islamicStarPath(size);
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [a, b],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeJoin = StrokeJoin.round
        ..color = stroke,
    );
  }

  @override
  bool shouldRepaint(_GradStarPainter o) =>
      o.a != a || o.b != b || o.stroke != stroke;
}

class _CtrlIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final String tooltip;
  final Color color;
  final VoidCallback? onTap;
  const _CtrlIcon({
    required this.icon,
    required this.size,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      iconSize: size,
      tooltip: tooltip,
      onPressed: onTap,
      color: color,
      disabledColor: color.withValues(alpha: .35),
      icon: Icon(icon),
    );
  }
}

class _BigPlay extends StatelessWidget {
  final QuranAudioProvider audio;
  final HomeTokens tk;
  const _BigPlay({required this.audio, required this.tk});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlayerState>(
      stream: audio.player.playerStateStream,
      builder: (_, snap) {
        final st = snap.data;
        final loading = st != null &&
            (st.processingState == ProcessingState.loading ||
                st.processingState == ProcessingState.buffering);
        final playing = st?.playing ?? false;
        final enabled = audio.hasAnyAudio;
        return Tooltip(
          message: playing ? 'إيقاف مؤقت' : 'تشغيل',
          child: GestureDetector(
            onTap: enabled ? audio.togglePlay : null,
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: enabled
                      ? [Color.lerp(tk.leaf, Colors.white, .12)!, tk.leaf]
                      : [tk.line, tk.line],
                ),
                border: Border.all(
                    color: tk.gold.withValues(alpha: .7), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: tk.leaf.withValues(alpha: enabled ? .40 : 0),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: loading
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: CircularProgressIndicator(
                          strokeWidth: 3, color: tk.mintInk),
                    )
                  : Icon(
                      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 44,
                      color: enabled ? Colors.white : tk.muted,
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _SpeedPicker extends StatelessWidget {
  final QuranAudioProvider audio;
  final HomeTokens tk;
  const _SpeedPicker({required this.audio, required this.tk});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.speed_rounded, size: 18, color: tk.gold),
            const SizedBox(width: 6),
            Text('سرعة التشغيل',
                style: cairoStyle(13, weight: 600, color: tk.muted)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: tk.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: tk.line),
          ),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              children: [
                for (final sp in QuranAudioProvider.speeds)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => audio.setSpeed(sp),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color:
                              audio.speed == sp ? tk.mint : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: audio.speed == sp
                                ? tk.leaf.withValues(alpha: .6)
                                : Colors.transparent,
                          ),
                        ),
                        child: Text(
                          '${sp == sp.truncateToDouble() ? sp.toInt().toString() : sp.toString()}×',
                          style: cairoStyle(13,
                              weight: audio.speed == sp ? 700 : 600,
                              color: audio.speed == sp ? tk.mintInk : tk.muted),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  final HomeTokens tk;
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Tile({
    required this.tk,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 74,
        decoration: BoxDecoration(
          color: active ? tk.mint : tk.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: active ? tk.gold.withValues(alpha: .7) : tk.line),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: active ? tk.gold : tk.muted),
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: cairoStyle(11,
                    weight: 600, color: active ? tk.mintInk : tk.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeekBar extends StatefulWidget {
  final QuranAudioProvider audio;
  final HomeTokens tk;
  const _SeekBar({required this.audio, required this.tk});

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? _drag;

  @override
  Widget build(BuildContext context) {
    final tk = widget.tk;
    final player = widget.audio.player;
    final style = cairoStyle(12, weight: 600, color: tk.muted)
        .copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
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
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 5,
                    activeTrackColor: tk.leaf,
                    inactiveTrackColor: tk.line,
                    thumbColor: tk.gold,
                    overlayColor: tk.gold.withValues(alpha: .16),
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 8),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 20),
                    trackShape: const RoundedRectSliderTrackShape(),
                  ),
                  child: Slider(
                    value: value,
                    max: max <= 0 ? 1.0 : max,
                    onChanged:
                        max <= 0 ? null : (v) => setState(() => _drag = v),
                    onChangeEnd: (v) {
                      widget.audio.seekTo(Duration(milliseconds: v.round()));
                      setState(() => _drag = null);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
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
  final tk = HomeTokens.of(context);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: tk.bg,
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      side: BorderSide(color: tk.gold.withValues(alpha: .45)),
    ),
    builder: (sheetContext) {
      void pick(VoidCallback action) {
        action();
        Navigator.of(sheetContext).pop();
      }

      Widget row(IconData icon, String title, VoidCallback onTap) => ListTile(
            onTap: onTap,
            leading: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: tk.mint, shape: BoxShape.circle),
              child: Icon(icon, size: 20, color: tk.mintInk),
            ),
            title:
                Text(title, style: cairoStyle(15, weight: 600, color: tk.ink)),
          );

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: tk.gold.withValues(alpha: .55),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text('إيقاف التشغيل تلقائيًا',
                    style: cairoStyle(18, weight: 700, color: tk.ink)),
              ),
            ),
            for (final m in const [10, 15, 30, 45, 60])
              row(Icons.timer_outlined, 'بعد ${toArabicDigits(m)} دقيقة',
                  () => pick(() => audio.setSleepTimer(Duration(minutes: m)))),
            row(Icons.menu_book_outlined, 'عند نهاية السورة',
                () => pick(audio.setSleepAtSurahEnd)),
            if (audio.sleepActive)
              row(Icons.timer_off_outlined, 'إلغاء المؤقت',
                  () => pick(audio.clearSleepTimer)),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
