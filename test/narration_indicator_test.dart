import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appbreak/domain/session.dart';
import 'package:appbreak/ui/home.dart';
import 'package:appbreak/ui/attention_outline.dart';
import 'controller_test.dart' show FakeDevice;
import 'widget_test.dart' show ReadyCompanion;

class NarrationDevice extends FakeDevice {
  bool playing = false;
  bool failStatus = false;
  @override
  Future<T?> call<T>(String method, [Map<String, dynamic>? args]) async {
    if (method == 'narrationState') {
      if (failStatus) throw StateError('engine unavailable');
      return {'playing': playing} as T;
    }
    if (method == 'stopSpeech') playing = false;
    return null;
  }
}

void main() {
  testWidgets(
    'popup follows actual speech state including external pause, completion and error',
    (tester) async {
      final d = NarrationDevice()
        ..value = {
          'session': const Session(
            id: 'one',
            activity: 'quiet.soft',
          ).at(Phase.rest, 60000, const Moment(100000, 1000, 1)).toJson(),
        };
      await tester.pumpWidget(
        MaterialApp(home: Home(controller: ReadyCompanion(d), popup: true)),
      );
      await tester.pumpAndSettle();
      AttentionOutline indicator() => tester.widget<AttentionOutline>(
        find.ancestor(
          of: find.byTooltip('Start / replay narration'),
          matching: find.byType(AttentionOutline),
        ),
      );
      expect(indicator().active, isFalse);
      d.playing = true;
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(indicator().active, isTrue);
      d.playing = false;
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(indicator().active, isFalse);
      d.playing = true;
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.tap(find.byTooltip('Stop narration'));
      await tester.pump();
      expect(indicator().active, isFalse);
      d.playing = true;
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      d.failStatus = true;
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(indicator().active, isFalse);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
