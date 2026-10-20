import 'package:flutter/material.dart';

/// Bundled, decorative illustrations; never fetch media from catalogue URLs.
class ActivityVisual extends StatefulWidget {
  final String category;
  const ActivityVisual({super.key, required this.category});
  @override
  State<ActivityVisual> createState() => _ActivityVisualState();
}
class _ActivityVisualState extends State<ActivityVisual> {
  bool playing = false;
  @override
  Widget build(BuildContext context) {
    final name = switch(widget.category) {
      'movement' => 'movement',
      'hydration' => 'water',
      'quiz' || 'imagination' => 'ideas',
      _ => 'calm',
    };
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final animate = playing && !reduceMotion;
    return Column(children: [
      ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.asset(
        'assets/activity_visuals/$name.${animate ? 'gif' : 'png'}',
        key: ValueKey('$name-$animate'),
        height: 150, width: double.infinity, fit: BoxFit.contain,
        excludeFromSemantics: true,
      )),
      if (!reduceMotion) TextButton.icon(
        onPressed: () => setState(() => playing = !playing),
        icon: Icon(animate ? Icons.pause : Icons.play_arrow),
        label: Text(animate ? 'Pause animation' : 'Play animation'),
      ),
      const Text('Optional illustration — follow the written instructions.', textAlign: TextAlign.center),
    ]);
  }
}
