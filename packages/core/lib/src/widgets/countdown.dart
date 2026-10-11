import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../settings/app_settings.dart';

/// Rebuilds every second with the time left until [until] (never negative).
class Countdown extends ConsumerStatefulWidget {
  const Countdown({super.key, required this.until, required this.builder});

  final DateTime until;
  final Widget Function(BuildContext context, Duration left) builder;

  @override
  ConsumerState<Countdown> createState() => _CountdownState();
}

class _CountdownState extends ConsumerState<Countdown> {
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
  Widget build(BuildContext context) {
    final left = widget.until.difference(ref.read(clockProvider)());
    return RepaintBoundary(child: widget.builder(context, left.isNegative ? Duration.zero : left));
  }
}
