// SPDX-License-Identifier: Apache-2.0
import 'package:flutter/material.dart';
import 'application/controller.dart';
import 'platform/device.dart';
import 'ui/home.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppBreak());
}

class AppBreak extends StatelessWidget {
  const AppBreak({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'AppBreak',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff28594e)),
      scaffoldBackgroundColor: const Color(0xfff6f8f3),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(minimumSize: const Size(48, 52)),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    ),
    home: Home(controller: Companion(Device())),
  );
}
