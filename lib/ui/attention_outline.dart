// SPDX-License-Identifier: Apache-2.0
import 'dart:async';
import 'package:flutter/material.dart';
import '../platform/device.dart';

/// Pulse only while active; idle and reduced-motion outlines remain steady.
/// Paints inside the existing bounds so compact toolbar hit targets do not move.
class AttentionOutline extends StatefulWidget {
  final Widget child;
  final bool active;
  final Color? color;
  const AttentionOutline({super.key, required this.child, this.active = false, this.color});

  @override
  State<AttentionOutline> createState() => _AttentionOutlineState();
}

class _AttentionOutlineState extends State<AttentionOutline>
    with SingleTickerProviderStateMixin {
  late final AnimationController pulse;
  bool reduceMotion = false;

  @override
  void initState() {
    super.initState();
    pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  }

  void updateAnimation() {
    if (widget.active && !reduceMotion) {
      if (!pulse.isAnimating) pulse.repeat(reverse: true);
    } else {
      pulse.stop();
      pulse.value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    reduceMotion = MediaQuery.disableAnimationsOf(context);
    updateAnimation();
  }

  @override
  void didUpdateWidget(AttentionOutline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) updateAnimation();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: pulse,
    child: widget.child,
    builder: (context, child) {
      final color = widget.color ?? Theme.of(context).colorScheme.primary;
      final strength = reduceMotion ? 1.0 : Curves.easeInOut.transform(pulse.value);
      return DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withValues(alpha: (widget.active ? 0.65 : 0.30) + (widget.active ? 0.35 : 0.50) * strength),
            width: widget.active ? 2.5 : 2,
          ),
        ),
        child: child,
      );
    },
  );

  @override
  void dispose() {
    pulse.dispose();
    super.dispose();
  }
}

/// Follow native speech, including completion, focus loss and notification controls.
class SpeechOutline extends StatefulWidget {
  final Device device;
  final Widget child;
  const SpeechOutline({super.key, required this.device, required this.child});
  @override
  State<SpeechOutline> createState() => _SpeechOutlineState();
}

class _SpeechOutlineState extends State<SpeechOutline> {
  Timer? timer;
  bool active = false;
  bool refreshing = false;

  @override
  void initState() {
    super.initState();
    refresh();
    timer = Timer.periodic(const Duration(milliseconds: 500), (_) => refresh());
  }

  Future<void> refresh() async {
    if (refreshing || widget.device.isDesktop) return;
    refreshing = true;
    try {
      final next = await widget.device.call<bool>('speechActive') ?? false;
      if (mounted && active != next) setState(() => active = next);
    } catch (_) {
      if (mounted && active) setState(() => active = false);
    } finally {
      refreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) => AttentionOutline(active: active, child: widget.child);

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }
}
