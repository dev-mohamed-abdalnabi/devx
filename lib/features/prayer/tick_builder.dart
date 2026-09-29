import 'dart:async';
import 'package:flutter/widgets.dart';

/// يعيد بناء نفسه كل ثانية (للعدّاد التنازلي).
class TickBuilder extends StatefulWidget {
  final Widget Function(BuildContext context, DateTime now) builder;
  const TickBuilder({super.key, required this.builder});

  @override
  State<TickBuilder> createState() => _TickBuilderState();
}

class _TickBuilderState extends State<TickBuilder> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, DateTime.now());
}
