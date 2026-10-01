import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../../providers/quran_audio_provider.dart';

class QuranAudioScreen extends StatelessWidget {
  const QuranAudioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<QuranAudioProvider>();
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('القرآن صوتيًا'),
        actions: [
          IconButton(
            tooltip: 'اختيار الشيخ',
            onPressed: audio.downloading ? null : () => _showReciterSettings(context, audio),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          Card(
            color: scheme.primaryContainer,
            child: ListTile(
              leading: Icon(Icons.headphones_rounded, color: scheme.primary, size: 30),
              title: const Text('استمع للقرآن كاملًا'),
              subtitle: Text(audio.selectedReciter.name),
            ),
          ),
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
          ],
          FilledButton.icon(
            onPressed: audio.downloading || audio.isReady || audio.selectedReciter.downloadUrl == null
                ? null
                : audio.downloadPackage,
            icon: Icon(audio.isReady ? Icons.check_circle : Icons.download_rounded),
            label: Text(audio.isReady
                ? 'التلاوة جاهزة'
                : audio.selectedReciter.downloadUrl == null
                    ? 'الرابط غير متاح'
                    : 'تنزيل التلاوة'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('السور', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              if (audio.hasAnyAudio) Text('${audio.downloadedSurahs.length}/114'),
            ],
          ),
          const SizedBox(height: 4),
          ...List.generate(
            QuranAudioProvider.surahCount,
            (index) => _SurahTile(audio: audio, surah: index + 1),
          ),
          const SizedBox(height: 12),
          _PlayerCard(audio: audio),
        ],
      ),
    );
  }
}

Future<void> _showReciterSettings(BuildContext context, QuranAudioProvider audio) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('اختيار الشيخ'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: QuranAudioProvider.reciters
              .map(
                (reciter) => RadioListTile<String>(
                  value: reciter.id,
                  groupValue: audio.selectedReciterId,
                  title: Text(reciter.name),
                  onChanged: (id) async {
                    if (id == null) return;
                    await audio.selectReciter(id);
                    if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                  },
                ),
              )
              .toList(),
        ),
      ),
    ),
  );
}

class _SurahTile extends StatelessWidget {
  final QuranAudioProvider audio;
  final int surah;

  const _SurahTile({required this.audio, required this.surah});

  @override
  Widget build(BuildContext context) {
    final available = audio.hasSurah(surah);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        leading: CircleAvatar(
          radius: 17,
          child: Text('$surah', style: const TextStyle(fontSize: 12)),
        ),
        title: Text(QuranAudioProvider.surahNames[surah - 1]),
        trailing: IconButton(
          tooltip: available ? 'تشغيل' : 'غير متاحة',
          icon: Icon(available ? Icons.play_circle_fill_rounded : Icons.lock_outline_rounded),
          onPressed: available && !audio.downloading ? () => audio.playSurah(surah) : null,
        ),
        onTap: available && !audio.downloading ? () => audio.playSurah(surah) : null,
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
              return Text(index == null ? 'اختر سورة للاستماع' : 'السورة الحالية', style: const TextStyle(fontWeight: FontWeight.bold));
            },
          ),
          const SizedBox(height: 8),
          StreamBuilder<Duration>(
            stream: audio.player.positionStream,
            builder: (_, snap) {
              final position = snap.data ?? Duration.zero;
              final value = max <= 0 ? 0.0 : position.inMilliseconds.clamp(0, duration.inMilliseconds).toDouble();
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
