import 'dart:typed_data';
import '../platform/platform_device.dart';
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
        CachedContentImage(
          url: m['url'],
          alt: m['alt'],
          fallback: 'Image unavailable. ${m['fallbackText']}',
          height: 180,
        ),
        Text(m['alt']),
        Text(m['fallbackText']),
      ],
    ],
  );
}

/// One bounded native request per URL. Native cache survives app restarts.
class CachedContentImage extends StatefulWidget {
  final String url, alt, fallback;
  final double height;
  const CachedContentImage({
    super.key,
    required this.url,
    required this.alt,
    required this.fallback,
    required this.height,
  });
  @override
  State<CachedContentImage> createState() => _CachedContentImageState();
}

class _CachedContentImageState extends State<CachedContentImage> {
  late Future<Uint8List?> bytes;
  void load() {
    bytes = platformDevice().call<Uint8List>('contentImage', {
      'url': widget.url,
    });
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(CachedContentImage old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
    future: bytes,
    builder: (_, snapshot) {
      if (!snapshot.hasData)
        return SizedBox(
          height: widget.height,
          child: Center(child: Text(widget.fallback)),
        );
      return Image.memory(
        snapshot.data!,
        height: widget.height,
        fit: BoxFit.contain,
        semanticLabel: widget.alt,
        errorBuilder: (_, _, _) => Text(widget.fallback),
      );
    },
  );
}
