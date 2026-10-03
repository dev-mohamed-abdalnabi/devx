import 'package:flutter/material.dart';

import '../features/more/support_screen.dart';

class SupportAppButton extends StatelessWidget {
  final bool compact;
  const SupportAppButton({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SupportScreen()),
      ),
      icon: const Icon(Icons.volunteer_activism_rounded),
      label: Text(compact ? 'دعم التطبيق' : 'شاهد إعلانًا لدعم التطبيق'),
    );
  }
}
