import 'package:flutter/material.dart';

class AdhanScreen extends StatelessWidget {
  final String prayerName;

  const AdhanScreen({super.key, this.prayerName = 'الصلاة'});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [scheme.primary, scheme.primary.withValues(alpha: 0.78)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.volume_up_rounded,
                      size: 84, color: Colors.white.withValues(alpha: 0.92)),
                  const SizedBox(height: 28),
                  Text('حان الآن وقت الصلاة',
                      textAlign: TextAlign.center,
                      style: text.headlineSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontWeight: FontWeight.w600,
                      )),
                  const SizedBox(height: 10),
                  Text('أذان $prayerName',
                      textAlign: TextAlign.center,
                      style: text.displaySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      )),
                  const SizedBox(height: 20),
                  Text('اللهم اجعل الصلاة قرة عين لنا',
                      textAlign: TextAlign.center,
                      style: text.titleMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.88),
                        height: 1.7,
                      )),
                  const SizedBox(height: 44),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: scheme.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('حسنًا'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
