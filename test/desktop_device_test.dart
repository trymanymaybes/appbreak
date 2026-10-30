import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:appbreak/platform/desktop_device.dart';

void main() {
  late Directory dir;
  late DesktopDevice device;
  var clock = DateTime(2026, 10, 27, 10);
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('appbreak-desktop-test');
    clock = DateTime(2026, 10, 27, 10);
    device = DesktopDevice(directory: () async => dir, clock: () => clock);
  });
  tearDown(() async => dir.delete(recursive: true));
  test(
    'offline defaults are manual and opt-in, data persists across reopen',
    () async {
      final data = await device.load();
      expect(
        data['settings']['profiles'].every(
          (p) => p['enabled'] == false && p['trigger'] == 'manual',
        ),
        isTrue,
      );
      data['ideas'] = [
        {'id': 'personal', 'text': 'Keep this note'},
      ];
      data['activitySelection'] = {
        'short': {
          'seen': ['quiet.soft'],
          'last': 'quiet.soft',
        },
      };
      await device.save(data);
      final reopened = DesktopDevice(directory: () async => dir);
      expect((await reopened.load())['ideas'], data['ideas']);
      expect(
        (await reopened.load())['activitySelection'],
        data['activitySelection'],
      );
      await expectLater(device.save(data), throwsStateError);
    },
  );
  test('corrupt storage is not silently overwritten', () async {
    await File('${dir.path}/state.json').writeAsString('broken');
    await expectLater(device.load(), throwsFormatException);
    await expectLater(device.save({}), throwsFormatException);
    expect(await File('${dir.path}/state.json').readAsString(), 'broken');
  });
  test(
    'elapsed routine survives restart; active-screen routine is rejected',
    () async {
      await device.call('startRoutine', {'id': 'short'});
      final data = await device.load();
      expect(data['session']['routineId'], 'short');
      expect(data['session']['timing'], 'elapsed');
      final reopened = DesktopDevice(
        directory: () async => dir,
        clock: () => clock,
      );
      expect((await reopened.load())['session'], data['session']);
      await expectLater(
        device.call('startRoutine', {'id': 'movement'}),
        throwsStateError,
      );
    },
  );
  test(
    'planner start, extend, end and complete preserve historical record',
    () async {
      final data = await device.load();
      data['plans'] = [
        {'id': 'p', 'routine': 'short', 'minutes': 30, 'minute': 600},
      ];
      await device.save(data);
      Future<void> action(String value) => device.call('planAction', {
        'id': 'p',
        'date': '2026-10-27',
        'action': value,
      });
      await action('start');
      await action('extend');
      expect(
        (await device.load())['planRecords']['p@2026-10-27']['end'],
        clock.add(const Duration(minutes: 45)).millisecondsSinceEpoch,
      );
      clock = clock.add(const Duration(hours: 1));
      expect(
        (await device.load())['planRecords']['p@2026-10-27']['status'],
        'ended',
      );
      await action('complete');
      await action('delete');
      expect((await device.load())['plans'], isEmpty);
      expect(
        (await device.load())['planRecords']['p@2026-10-27']['status'],
        'completed',
      );
    },
  );
  test('unknown platform features fail explicitly', () async {
    expect(await device.call<bool>('isBreakPopup'), isFalse);
    expect(
      (await device.call<Map>('capabilities'))!['screenSupported'],
      isFalse,
    );
    await expectLater(device.call('record'), throwsA(isA<Exception>()));
  });
}
