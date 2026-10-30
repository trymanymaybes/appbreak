// SPDX-License-Identifier: Apache-2.0
import 'package:flutter/foundation.dart';
import 'device.dart';
import 'desktop_device.dart';

final Device _android = Device();
final Device _desktop = DesktopDevice();
Device platformDevice() => switch (defaultTargetPlatform) {
  TargetPlatform.windows ||
  TargetPlatform.macOS ||
  TargetPlatform.linux => _desktop,
  _ => _android,
};
