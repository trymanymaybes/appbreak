import 'package:flutter/material.dart';
import '../domain/activity.dart';

/// Raster media is optional. Text remains available even when offline.
class ContentMedia extends StatelessWidget {
  final Activity activity;
  const ContentMedia({super.key, required this.activity});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final m in (activity.data['media'] as List? ?? [])) ...[
        Image.network(
          m['url'],
          height: 180,
          fit: BoxFit.contain,
          semanticLabel: m['alt'],
          errorBuilder: (_, _, _) =>
              Text('Image unavailable. ${m['fallbackText']}'),
          loadingBuilder: (_, child, progress) =>
              progress == null ? child : Text(m['fallbackText']),
        ),
        Text(m['alt']),
        Text(m['fallbackText']),
      ],
    ],
  );
}
