// SPDX-License-Identifier: Apache-2.0
import 'dart:convert';
import 'package:flutter/services.dart';
import '../domain/session.dart';

class Device {
  bool get isDesktop => false;
  static const channel = MethodChannel('org.appbreak/device');
  Future<T?> call<T>(String method, [Map<String, dynamic>? args]) =>
      channel.invokeMethod<T>(method, args);
  Future<Moment> now() async {
    final n = Map<String, dynamic>.from(await call<Map>('now') ?? {});
    return Moment(n['wall'], n['elapsed'], n['boot']);
  }

  Future<Map<String, dynamic>> load() async =>
      jsonDecode(await call<String>('load') ?? '{}');
  Future<void> save(Map<String, dynamic> data) async =>
      call('save', {'json': jsonEncode(data)});
}
