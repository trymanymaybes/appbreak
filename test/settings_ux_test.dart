import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appbreak/application/controller.dart';
import 'package:appbreak/domain/session.dart';
import 'package:appbreak/ui/home.dart';
import 'controller_test.dart' show FakeDevice;
import 'widget_test.dart' show ReadyCompanion;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'popup pause persists, expires, and never modifies the current timer',
    () async {
      final d = FakeDevice();
      final c = Companion(d);
      await c.start();
      final before = c.session.toJson();
      await c.pausePopups(60);
      expect(c.session.toJson(), before);
      expect(d.value['settings']['popup'], true);
      expect(c.popupPauseRemainingMs, 3600000);
      c.moment = const Moment(3700000, 3601000, 1);
      expect(c.popupPauseRemainingMs, 0);
      await c.setPopups(false);
      expect(c.settings['popup'], false);
      expect(c.settings['popupPausedUntil'], 0);
      c.dispose();
    },
  );
  test(
    'manual resume clears a persisted pause without resetting a session',
    () async {
      final c = Companion(FakeDevice());
      await c.pausePopups(15);
      await c.setPopups(true);
      expect(c.popupPauseRemainingMs, 0);
      expect(c.settings['popup'], true);
      c.dispose();
    },
  );
  testWidgets(
    'everyday settings hide language and expose Advanced in one tap',
    (tester) async {
      final c = ReadyCompanion(FakeDevice());
      await tester.pumpWidget(MaterialApp(home: Home(controller: c)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Everyday settings'), findsOneWidget);
      expect(find.text('Dictation language'), findsNothing);
      expect(find.text('Interrupt with a popup'), findsOneWidget);
      expect(find.text('Pause 15 min'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Advanced settings'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Advanced settings'));
      await tester.tap(find.text('Advanced settings'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Language & interaction'),
        -400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Language & interaction'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Dictation language'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
