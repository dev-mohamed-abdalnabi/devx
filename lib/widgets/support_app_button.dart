import 'package:flutter/material.dart';

import '../services/ads_service.dart';

class SupportAppButton extends StatefulWidget {
  final bool compact;

  const SupportAppButton({super.key, this.compact = false});

  @override
  State<SupportAppButton> createState() => _SupportAppButtonState();
}

class _SupportAppButtonState extends State<SupportAppButton> {
  bool _loading = false;

  Future<void> _watch() async {
    if (_loading) return;
    setState(() => _loading = true);
    final watched = await AdsService.showSupportRewardedAd();
    if (!mounted) return;
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(watched
          ? 'شكرًا لك، ساعدت في دعم استمرار التطبيق.'
          : 'لا يتوفر إعلان الآن. يمكنك المحاولة لاحقًا.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _loading ? null : _watch,
      icon: _loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.volunteer_activism_rounded),
      label: Text(widget.compact ? 'دعم التطبيق' : 'شاهد إعلانًا لدعم التطبيق'),
    );
  }
}
