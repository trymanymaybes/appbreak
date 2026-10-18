// SPDX-License-Identifier: Apache-2.0
import 'package:flutter/material.dart';
import 'application/controller.dart';
import 'domain/session.dart';
import 'platform/device.dart';
import 'ui/home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final popup = await Device().call<bool>('isBreakPopup') ?? false;
  runApp(AppBreak(popup: popup));
}

ThemeData appTheme(Brightness brightness) => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xff28594e),
    brightness: brightness,
  ),
  scaffoldBackgroundColor: brightness == Brightness.dark
      ? const Color(0xff101714)
      : const Color(0xfff6f8f3),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(minimumSize: const Size(48, 52)),
  ),
  inputDecorationTheme: const InputDecorationTheme(
    border: OutlineInputBorder(),
  ),
);

bool darkBreakSurface(bool popup, Session session) =>
    popup ||
    [Phase.rest, Phase.finished, Phase.pending].contains(session.phase) ||
    (session.phase == Phase.paused && session.resumePhase == Phase.rest);

class AppBreak extends StatefulWidget {
  final bool popup;
  const AppBreak({super.key, this.popup = false});
  @override
  State<AppBreak> createState() => _AppBreakState();
}

class _AppBreakState extends State<AppBreak> {
  final controller = Companion(Device());
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => MaterialApp(
      title: 'AppBreak',
      debugShowCheckedModeBanner: false,
      theme: appTheme(Brightness.light),
      darkTheme: appTheme(Brightness.dark),
      themeMode: darkBreakSurface(widget.popup, controller.session)
          ? ThemeMode.dark
          : ThemeMode.light,
      home: Home(controller: controller),
    ),
  );
}
