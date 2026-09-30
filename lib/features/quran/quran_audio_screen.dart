import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/quran_audio_provider.dart';

class QuranAudioScreen extends StatelessWidget {
  const QuranAudioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<QuranAudioProvider>();
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('القرآن صوتيًا')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: scheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.headphones_rounded, color: scheme.primary, size: 30),
                  const SizedBox(width: 10),
                  Expanded(child: Text('استمع للقرآن كاملًا', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
                ]),
                const SizedBox(height: 10),
                const Text('اختر القارئ ثم نزّل ملف ZIP من مجلد audio_packages في GitHub. الملفات لا تدخل داخل التطبيق وتُفك خارجيًا بعد التثبيت.'),
                const SizedBox(height: 8),
                Text('جودة اقتصادية مضغوطة · سقف التنزيل ١٠٠ ميجابايت', style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Text('اختر الشيخ', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...QuranAudioProvider.reciters.map((reciter) => RadioListTile<String>(
                value: reciter.id,
                groupValue: audio.selectedReciterId,
                onChanged: audio.downloading ? null : (id) => audio.selectReciter(id!),
                title: Text(reciter.name),
                subtitle: Text(reciter.subtitle),
                contentPadding: EdgeInsets.zero,
              )),
          const SizedBox(height: 8),
          if (audio.error != null)
            Card(
              color: scheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text('${audio.error}'),
              ),
            ),
          if (audio.downloading) ...[
            LinearProgressIndicator(value: audio.downloadProgress == 0 ? null : audio.downloadProgress),
            const SizedBox(height: 8),
            Text(audio.downloadingSurah == null
                ? 'جاري فحص حجم الملفات...'
                : 'جاري تنزيل السورة ${audio.downloadingSurah} من ١١٤'),
            const SizedBox(height: 12),
          ],
          FilledButton.icon(
            onPressed: audio.downloading || audio.isReady ? null : audio.downloadPackage,
            icon: Icon(audio.isReady ? Icons.check_circle : Icons.download_rounded),
            label: Text(audio.isReady ? 'التلاوة جاهزة للاستماع' : 'تنزيل القرآن كاملًا'),
          ),
          if (audio.hasAnyAudio) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: audio.downloading ? null : () => audio.playFrom(audio.downloadedSurahs.reduce((a, b) => a < b ? a : b)),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('تشغيل من البداية'),
            ),
          ],
          if (audio.hasAnyAudio && !audio.isReady) ...[
            const SizedBox(height: 8),
            Text('تم تنزيل ${audio.downloadedSurahs.length} سورة. يمكنك تشغيل المتاح الآن.', textAlign: TextAlign.center),
          ],
          const SizedBox(height: 22),
          _PlayerCard(audio: audio),
        ],
      ),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  final QuranAudioProvider audio;
  const _PlayerCard({required this.audio});

  @override
  Widget build(BuildContext context) {
    final duration = audio.player.duration ?? Duration.zero;
    final max = duration.inMilliseconds.toDouble();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          StreamBuilder<SequenceState?>(
            stream: audio.player.sequenceStateStream,
            builder: (_, snapshot) {
              final index = snapshot.data?.currentIndex;
              return Text(index == null ? 'اختر سورة للاستماع' : 'سورة ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold));
            },
          ),
          const SizedBox(height: 8),
          StreamBuilder<Duration>(
            stream: audio.player.positionStream,
            builder: (_, snap) {
              final value = max <= 0 ? 0.0 : snap.data!.inMilliseconds.clamp(0, duration.inMilliseconds).toDouble();
              return Slider(
                value: value.clamp(0, max == 0 ? 1 : max),
                max: max == 0 ? 1 : max,
                onChanged: max == 0 ? null : (v) => audio.player.seek(Duration(milliseconds: v.round())),
              );
            },
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(icon: const Icon(Icons.skip_previous_rounded), onPressed: audio.player.hasPrevious ? audio.player.seekToPrevious : null),
            IconButton(
              iconSize: 52,
              icon: Icon(audio.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded),
              onPressed: audio.isPlaying ? audio.pause : (audio.player.audioSource == null ? null : audio.resume),
            ),
            IconButton(icon: const Icon(Icons.skip_next_rounded), onPressed: audio.player.hasNext ? audio.player.seekToNext : null),
          ]),
        ]),
      ),
    );
  }
}
