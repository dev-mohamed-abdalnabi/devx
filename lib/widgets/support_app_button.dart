import 'package:flutter/material.dart';

import '../services/ads_service.dart';

class SupportAppButton extends StatefulWidget {
  final bool compact;
  const SupportAppButton({super.key, this.compact = false});

  @override
  State<SupportAppButton> createState() => _SupportAppButtonState();
}

class _SupportAppButtonState extends State<SupportAppButton> {
  bool loading = false;

  Future<void> watch() async {
    if (loading) return;
    setState(() => loading = true);
    final watched = await AdsService.showSupportRewardedAd();
    if (!mounted) return;
    setState(() => loading = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(watched
          ? 'شكرًا لك، ساعدت في دعم استمرار التطبيق.'
          : 'لا يتوفر إعلان الآن. يمكنك المحاولة لاحقًا.'),
    ));
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: loading ? null : watch,
        icon: loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.volunteer_activism_rounded),
        label: Text(widget.compact ? 'دعم التطبيق' : 'شاهد إعلانًا لدعم التطبيق'),
      );
}
