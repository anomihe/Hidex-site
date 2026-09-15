import 'dart:async';

import 'package:flutter/material.dart';

/// Ticks once a second and rebuilds [builder] with the remaining
/// duration until [target] (clamped at zero). Stateless from the
/// caller's point of view — just wrap whatever countdown text/UI you
/// need around it.
class CountdownDisplay extends StatefulWidget {
  const CountdownDisplay({
    super.key,
    required this.target,
    required this.builder,
    this.onReached,
  });

  final DateTime target;
  final Widget Function(BuildContext context, Duration remaining) builder;
  final VoidCallback? onReached;

  @override
  State<CountdownDisplay> createState() => _CountdownDisplayState();
}

class _CountdownDisplayState extends State<CountdownDisplay> {
  late Timer _timer;
  late Duration _remaining;
  bool _reachedFired = false;

  @override
  void initState() {
    super.initState();
    _remaining = _computeRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  Duration _computeRemaining() {
    final diff = widget.target.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  void _tick() {
    final remaining = _computeRemaining();
    if (!mounted) return;
    setState(() => _remaining = remaining);
    if (remaining == Duration.zero && !_reachedFired) {
      _reachedFired = true;
      widget.onReached?.call();
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _remaining);
}

String formatDuration(Duration d) {
  final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (d.inHours > 0) {
    return '${d.inHours}:$minutes:$seconds';
  }
  return '$minutes:$seconds';
}
