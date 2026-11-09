// SPDX-License-Identifier: Apache-2.0
import 'package:flutter/material.dart';

/// Three gentle pulses when use starts, then a steady active outline.
/// Inactive controls have no outline or animation.
/// Paints inside the existing bounds so compact toolbar hit targets do not move.
class AttentionOutline extends StatefulWidget {
  final Widget child;
  final bool active;
  final Color? color;
  const AttentionOutline({
    super.key,
    required this.child,
    this.active = false,
    this.color,
  });

  @override
  State<AttentionOutline> createState() => _AttentionOutlineState();
}

class _AttentionOutlineState extends State<AttentionOutline>
    with SingleTickerProviderStateMixin {
  late final AnimationController pulse;
  int cycles = 0;
  bool reduceMotion = false;
  bool resetting = false;

  @override
  void initState() {
    super.initState();
    pulse =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 900),
        )..addStatusListener((status) {
          if (resetting) return;
          if (status == AnimationStatus.completed) {
            pulse.reverse();
          } else if (status == AnimationStatus.dismissed && ++cycles < 3) {
            pulse.forward();
          }
        });
  }

  void restart() {
    resetting = true;
    pulse.stop();
    pulse.value = 0;
    cycles = 0;
    resetting = false;
    if (widget.active && !reduceMotion) pulse.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    reduceMotion = MediaQuery.disableAnimationsOf(context);
    restart();
  }

  @override
  void didUpdateWidget(AttentionOutline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) restart();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: pulse,
    child: widget.child,
    builder: (context, child) {
      final color = widget.color ?? Theme.of(context).colorScheme.primary;
      final strength = reduceMotion
          ? 1.0
          : Curves.easeInOut.transform(pulse.value);
      return DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withValues(
              alpha: widget.active ? 0.65 + 0.35 * strength : 0,
            ),
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
