// SPDX-License-Identifier: Apache-2.0
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../domain/profile.dart';
import '../domain/session.dart';
import 'device.dart';
import 'desktop_content.dart';

/// Desktop preview: elapsed timers run while the process is open. No OS
/// permissions, background services or automatic screen tracking are requested.
class DesktopDevice extends Device {
  DesktopDevice({
    Future<Directory> Function()? directory,
    DateTime Function()? clock,
  }) : _directory = directory ?? getApplicationSupportDirectory,
       _clock = clock ?? DateTime.now;
  final Future<Directory> Function() _directory;
  final DateTime Function() _clock;
  Future<void> _pending = Future.value();
  Directory? _root;
  late final DesktopContent content = DesktopContent(() => root);
  @override
  bool get isDesktop => true;
  Future<Directory> get root async {
    final dir = _root ??= await _directory();
    await dir.create(recursive: true);
    return dir;
  }

  Future<T> serial<T>(Future<T> Function() work) {
    final result = _pending.then((_) async {
      final lock = await File(
        '${(await root).path}/state.lock',
      ).open(mode: FileMode.append);
      try {
        await lock.lock(FileLock.blockingExclusive);
        return await work();
      } finally {
        await lock.close();
      }
    });
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Map<String, dynamic> defaults() => {
    'schemaVersion': 1,
    'revision': 0,
    'settings': {
      'autoSetup': false,
      'permissionSetupSeen': true,
      'routinesVersion': 1,
      'timing': 'elapsed',
      'profiles': defaultProfiles
          .map(
            (p) => {
              ...p,
              'enabled': false,
              'trigger': 'manual',
              'popup': false,
              'notifications': false,
            },
          )
          .toList(),
    },
  };
  Future<Map<String, dynamic>> read() async {
    final file = File('${(await root).path}/state.json');
    if (!await file.exists()) return defaults();
    // Never silently replace corrupt or newer data with an empty database.
    final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    if ((data['schemaVersion'] ?? 1) != 1) {
      throw const FormatException('Unsupported saved data version');
    }
    return data;
  }

  Future<void> write(Map<String, dynamic> data) async {
    final path = '${(await root).path}/state.json';
    final next = File('$path.next');
    await next.writeAsString(jsonEncode(data), flush: true);
    // Dart rename replaces the destination on all supported desktop targets.
    await next.rename(path);
  }

  @override
  Future<Map<String, dynamic>> load() => serial(() async {
    final data = await read();
    final records = data['planRecords'] as Map? ?? {};
    var changed = false;
    for (final r in records.values) {
      if (r['status'] == 'active' &&
          _clock().millisecondsSinceEpoch >= r['end']) {
        r['status'] = 'ended';
        stopWork(data);
        changed = true;
      }
    }
    if (changed) {
      data['revision'] = (data['revision'] ?? 0) + 1;
      await write(data);
    }
    return data;
  });
  @override
  Future<void> save(Map<String, dynamic> data) => serial(() async {
    final current = await read();
    if ((data['revision'] ?? 0) != (current['revision'] ?? 0)) {
      throw StateError('Data changed. Please retry.');
    }
    await write({...data, 'revision': (current['revision'] ?? 0) + 1});
  });
  @override
  Future<Moment> now() async {
    // Use wall deadlines across suspend/relaunch. Desktop does not yet have a
    // system boot-clock adapter; boot=-2 differs from persisted session boots.
    final wall = _clock().millisecondsSinceEpoch;
    return Moment(wall, wall, -2);
  }

  Future<void> mutate(void Function(Map<String, dynamic>) change) =>
      serial(() async {
        final data = await read();
        change(data);
        data['revision'] = (data['revision'] ?? 0) + 1;
        await write(data);
      });
  void stopWork(Map<String, dynamic> data) {
    final s = data['session'] as Map?;
    if (['work', 'due'].contains(s?['phase']) ||
        (s?['phase'] == 'paused' && s?['resumePhase'] == 'work')) {
      data.remove('session');
    }
  }

  void startRoutine(Map<String, dynamic> data, String id) {
    final phase = (data['session'] as Map?)?['phase'];
    if (phase != null && phase != 'idle')
      throw StateError('Finish or skip the current session first');
    final profiles = (data['settings'] as Map?)?['profiles'] as List? ?? [];
    final p = profiles.where((p) => p['id'] == id).firstOrNull;
    if (p == null) throw StateError('Routine removed; edit this plan');
    if (p['trigger'] == 'screen')
      throw StateError(
        'Active-screen tracking is not available in the desktop preview. Choose a manual routine.',
      );
    final wall = _clock().millisecondsSinceEpoch;
    data['session'] = Session(id: '$wall-$id', routineId: id)
        .at(
          Phase.work,
          (p['workSeconds'] as int? ?? 1500) * 1000,
          Moment(wall, wall, -2),
        )
        .toJson();
    data['settings']['profile'] = id;
  }

  Future<void> planAction(Map<String, dynamic> args) => mutate((data) {
    final plans = data['plans'] as List? ?? [];
    final p = plans.where((p) => p['id'] == args['id']).firstOrNull;
    if (p == null) throw StateError('Plan no longer exists');
    final records =
        data.putIfAbsent('planRecords', () => <String, dynamic>{}) as Map;
    final key = '${args['id']}@${args['date']}';
    final record = Map<String, dynamic>.from(records[key] ?? {});
    final status = record['status'] ?? 'planned';
    final now = _clock();
    void require(bool allowed) {
      if (!allowed)
        throw StateError('This planner action is no longer available');
    }

    switch (args['action']) {
      case 'start':
        require(
          args['date'] ==
              '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
        );
        require(['planned', 'prompted', 'delayed', 'missed'].contains(status));
        require(!records.values.any((r) => r['status'] == 'active'));
        startRoutine(data, p['routine']);
        record.addAll({
          'status': 'active',
          'end': now.millisecondsSinceEpoch + (p['minutes'] as int) * 60000,
        });
      case 'extend':
        require(status == 'active');
        record['end'] += 900000;
      case 'delay':
        require(['planned', 'prompted', 'delayed'].contains(status));
        final day = DateTime.parse(args['date']);
        final scheduled = day
            .add(Duration(minutes: p['minute']))
            .millisecondsSinceEpoch;
        final target = record['remindAt'] as int? ?? scheduled;
        record.addAll({
          'status': 'delayed',
          'remindAt':
              (target > now.millisecondsSinceEpoch
                  ? target
                  : now.millisecondsSinceEpoch) +
              600000,
        });
      case 'complete':
      case 'skip':
        if (args['action'] == 'complete')
          require(['active', 'ended'].contains(status));
        if (status == 'active') stopWork(data);
        record['status'] = args['action'] == 'complete'
            ? 'completed'
            : 'skipped';
      case 'delete':
        require(status != 'active');
        plans.remove(p);
        return;
      default:
        throw StateError('Unknown planner action');
    }
    records[key] = record;
  });
  Future<void> export(String name, List<int> bytes) async {
    final location = await getSaveLocation(suggestedName: name);
    if (location != null)
      await XFile.fromData(
        Uint8List.fromList(bytes),
        name: name,
      ).saveTo(location.path);
  }

  @override
  Future<T?> call<T>(String method, [Map<String, dynamic>? args]) async {
    final a = args ?? {};
    dynamic value;
    switch (method) {
      case 'isBreakPopup':
      case 'consumeProgressOpen':
        value = false;
      case 'consumeBreakOpen':
        value = null;
      case 'allowed':
        value = true;
      case 'capabilities':
        value = {
          'desktop': true,
          'notifications': false,
          'usage': false,
          'screenSupported': false,
          'overlay': false,
          'dictation': false,
          'microphone': false,
        };
      case 'stopSpeech':
      case 'stopAudio':
      case 'stopRecord':
      case 'stopDictation':
      case 'closePopup':
      case 'notifications':
        break;
      case 'catalogLoad':
      case 'catalogRefresh':
      case 'catalogEnabled':
        value = await content.catalog(method, a);
      case 'startRoutine':
        await mutate((d) => startRoutine(d, a['id']));
      case 'planAction':
        await planAction(a);
      case 'saveDraft':
        if ((a['text'] as String).length > 100000 ||
            (a['title'] as String).length > 200)
          throw const FormatException('Draft too long');
        await mutate(
          (d) => d['ideaDraft'] = {'text': a['text'], 'title': a['title']},
        );
      case 'clearDraft':
        await mutate((d) => d.remove('ideaDraft'));
      case 'saveText':
        await export('idea.txt', utf8.encode(a['text']));
      case 'shareText':
        await Clipboard.setData(ClipboardData(text: a['text']));
        value = 'Copied text to clipboard';
      case 'openExternal':
        final uri = Uri.parse(a['url']);
        if (uri.scheme != 'https' || uri.userInfo.isNotEmpty)
          throw const FormatException('Only HTTPS links are supported');
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication))
          throw StateError('Could not open link');
      case 'backup':
        final data = await load();
        for (final key in [
          'session',
          'revision',
          'routineState',
          'cueEvents',
          'pendingDelete',
        ]) {
          data.remove(key);
        }
        final payload = jsonEncode({'data': data, 'audio': {}});
        await export(
          'appbreak-backup.json',
          utf8.encode(
            jsonEncode({
              'format': 'appbreak-backup',
              'version': 1,
              'payload': payload,
              'sha256': sha256.convert(utf8.encode(payload)).toString(),
            }),
          ),
        );
      case 'usage':
        var size = 0;
        await for (final f in (await root).list(recursive: true)) {
          if (f is File) size += await f.length();
        }
        value = size;
      case 'deleteAll':
        await serial(() async {
          await write(defaults());
          for (final name in ['catalog.json', 'catalog.json.next']) {
            final file = File('${(await root).path}/$name');
            if (await file.exists()) await file.delete();
          }
          final images = Directory('${(await root).path}/images');
          if (await images.exists()) await images.delete(recursive: true);
        });
      case 'contentImage':
        value = await content.image(a['url']);
      case 'importPack':
        final file = await openFile(
          acceptedTypeGroups: [
            const XTypeGroup(
              label: 'Activity JSON',
              extensions: ['json'],
              uniformTypeIdentifiers: ['public.json'],
            ),
          ],
        );
        if (file != null) {
          if (await file.length() > 256 * 1024)
            throw const FormatException('Pack too large');
          final text = await file.readAsString();
          DesktopContent.validate(text, community: false);
          value = text;
        }
      case 'voices':
        value = <Map<String, dynamic>>[];
      default:
        throw PlatformException(
          code: 'desktop_preview',
          message:
              '$method is not available in the desktop preview. Text instructions and manual timers remain available.',
        );
    }
    return value as T?;
  }
}
