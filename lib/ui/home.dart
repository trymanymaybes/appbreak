// SPDX-License-Identifier: Apache-2.0
// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'package:flutter/services.dart';
import 'routine_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import '../application/controller.dart';
import '../domain/session.dart';
import '../domain/activity.dart';
import '../domain/progress.dart';
import '../platform/device.dart';

class Home extends StatefulWidget {
  final Companion controller;
  const Home({super.key, required this.controller});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with WidgetsBindingObserver {
  Companion get c => widget.controller;
  int tab = 0;
  bool setupOpen = false;
  bool advancedOpen = false;
  Phase lastPhase = Phase.idle;
  int lastBreakNavigation = 0;
  String search = '';
  bool recording = false, includeAudio = false, dictating = false;
  String transcript = '', dictationStatus = '';
  Future<void> Function()? flushDraft;
  Map<String, dynamic> capabilities = {};
  String? categoryFilter;
  List<Map<String, dynamic>> voices = [];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    c.addListener(changed);
    initializeHome();
    Device.channel.setMethodCallHandler((call) async {
      if (call.method == 'permissionsChanged') await loadCapabilities();
      if (call.method == 'dictation') {
        final args = Map<String, dynamic>.from(call.arguments as Map);
        dictating = args['listening'] == true;
        transcript = args['text'] ?? transcript;
        dictationStatus = args['status'] ?? '';
        if (!dictating) await c.refresh();
        if (mounted) setState(() {});
      }
      if (call.method == 'recordEnded') {
        final args = Map<String, dynamic>.from(call.arguments as Map);
        if (args['error'] != null && mounted) message(args['error']);
        recording = false;
        await c.refresh();
        if (mounted) setState(() {});
      }
    });
  }

  Future<void> initializeHome() async {
    await c.init();
    if (!mounted) return;
    await loadCapabilities();
    if (mounted &&
        capabilities.isNotEmpty &&
        c.settings['permissionSetupSeen'] != true &&
        [Phase.idle, Phase.work].contains(c.session.phase) &&
        c.breakNavigationVersion == 0) {
      setState(() {
        setupOpen = true;
        advancedOpen = false;
      });
      await c.updateSettings({'permissionSetupSeen': true});
    }
  }

  void openSetup() {
    setState(() {
      setupOpen = true;
      advancedOpen = false;
    });
    loadCapabilities();
  }

  Future<void> loadCapabilities() async {
    try {
      final result = await c.device.call<Map>('capabilities');
      if (mounted)
        setState(() => capabilities = Map<String, dynamic>.from(result ?? {}));
    } catch (_) {
      /* Tests and other platform adapters can omit capabilities. */
    }
  }

  void changed() {
    if (c.breakNavigationVersion != lastBreakNavigation) {
      lastBreakNavigation = c.breakNavigationVersion;
      setupOpen = false;
      advancedOpen = false;
      tab = 0;
      // A routine editor or activity chooser may be covering the main page.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      });
    }
    if (c.session.phase == Phase.rest && lastPhase != Phase.rest) {
      tab = 0;
      setupOpen = false;
      advancedOpen = false;
    }
    lastPhase = c.session.phase;
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    c.visible = state == AppLifecycleState.resumed;
    if (!c.visible) flushDraft?.call();
    if (c.visible) {
      c.refresh().then((_) => c.refreshCatalog());
      loadCapabilities();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    c.removeListener(changed);
    c.dispose();
    Device.channel.setMethodCallHandler(null);
    super.dispose();
  }

  Future<void> run(Future<dynamic> Function() fn) async {
    try {
      final result = await fn();
      if (result is String && mounted) message(result);
    } catch (e) {
      if (mounted) message('$e');
    }
  }

  void message(String s) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(s), duration: const Duration(seconds: 7)),
  );
  Future<bool> confirm(String title, String detail) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(detail),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ) ??
      false;
  Widget button(String label, VoidCallback action, {bool enabled = true}) =>
      Padding(
        padding: const EdgeInsets.only(right: 8, bottom: 8),
        child: ElevatedButton(
          onPressed: enabled ? action : null,
          child: Text(label),
        ),
      );
  Widget section(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        ...children,
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final pages = [dashboard, ideas, achievements, settings, routines];
    return PopScope(
      canPop:
          !setupOpen &&
          !advancedOpen &&
          ![Phase.rest, Phase.finished].contains(c.session.phase) &&
          !(c.session.phase == Phase.paused &&
              c.session.resumePhase == Phase.rest),
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          if (advancedOpen) {
            setState(() => advancedOpen = false);
            return;
          }
          if (setupOpen) {
            setState(() => setupOpen = false);
            return;
          }
          await c.leaveBreak();
          if (c.error == null) await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            setupOpen
                ? 'Permissions & setup'
                : advancedOpen
                ? 'Advanced settings'
                : 'AppBreak',
          ),
          leading: setupOpen || advancedOpen
              ? BackButton(
                  onPressed: () => setState(() {
                    setupOpen = false;
                    advancedOpen = false;
                  }),
                )
              : null,
          actions: [
            IconButton(
              tooltip: 'Popup controls',
              icon: const Icon(Icons.notifications_paused_outlined),
              onPressed: () => setState(() {
                tab = 3;
                setupOpen = false;
                advancedOpen = false;
              }),
            ),
            IconButton(
              tooltip: 'Permissions & setup',
              icon: const Icon(Icons.fact_check_outlined),
              onPressed: openSetup,
            ),
            IconButton(
              tooltip: 'Stop all audio',
              icon: const Icon(Icons.volume_off_outlined),
              onPressed: () => run(() => c.device.call('stopAudio')),
            ),
          ],
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                key: ValueKey(
                  setupOpen
                      ? 'setup'
                      : advancedOpen
                      ? 'advanced'
                      : 'tab-$tab',
                ),
                padding: const EdgeInsets.all(20),
                children: [
                  if (c.error != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(c.error!),
                      ),
                    ),
                  if (dictating)
                    Card(
                      child: ListTile(
                        title: const Text(
                          'Microphone active — on-device dictation',
                        ),
                        subtitle: Text(dictationStatus),
                        trailing: IconButton(
                          tooltip: 'Stop dictation',
                          icon: const Icon(Icons.stop),
                          onPressed: () => dictate(),
                        ),
                      ),
                    ),
                  if (recording)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          '● Recording microphone — stops after 5 minutes, on lock, or when you leave this app.',
                        ),
                      ),
                    ),
                  if (setupOpen) ...[
                    const Text(
                      'Enable popup access to interrupt screen time reliably. Notifications are the fallback. You can switch popups off or pause them whenever needed.',
                    ),
                    permissionsPanel(),
                    button(
                      'Continue to app',
                      () => setState(() => setupOpen = false),
                    ),
                  ] else if (advancedOpen)
                    ...advancedSettings()
                  else
                    ...pages[tab](),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (v) => setState(() {
            tab = v;
            setupOpen = false;
            advancedOpen = false;
          }),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.spa_outlined),
              label: 'Today',
            ),
            NavigationDestination(icon: Icon(Icons.edit_note), label: 'Ideas'),
            NavigationDestination(
              icon: Icon(Icons.emoji_events_outlined),
              label: 'Progress',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              label: 'Settings',
            ),
            NavigationDestination(icon: Icon(Icons.alarm), label: 'Routines'),
          ],
        ),
      ),
    );
  }

  List<Widget> dashboard() {
    final s = c.session;
    final rest = [Phase.rest, Phase.finished].contains(s.phase);
    final activity = c.current;
    if (rest && activity != null) return breakPlayer();
    if (s.phase == Phase.pending)
      return [
        Text(
          'Did you take your break?',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const Text(
          'Leaving the break did not record participation. You can confirm or skip.',
        ),
        button('Yes, I did', () => c.complete()),
        button('Skip', () => c.cancel()),
      ];
    final seconds = (s.remaining(c.moment) / 1000).ceil();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final completed = c.history.where((h) => h['date'] == today).length;
    return [
      Text(
        'A little space in your day.',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 16),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                {
                  Phase.idle: 'Ready when you are',
                  Phase.work: 'Work session',
                  Phase.due: 'Break available',
                  Phase.rest: 'Your break',
                  Phase.paused: 'Paused temporarily',
                  Phase.finished: 'Break time ended',
                  Phase.pending: 'Participation unconfirmed',
                }[s.phase]!,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if ([Phase.work, Phase.rest, Phase.paused].contains(s.phase)) ...[
                const SizedBox(height: 12),
                ExcludeSemantics(
                  child: Text(
                    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                ),
                Text(
                  s.phase == Phase.paused
                      ? 'Automatically resumes in about ${(seconds / 60).ceil()} minutes.'
                      : s.timing == 'screen'
                      ? 'Remaining screen-on, unlocked time; next alert depends on use.'
                      : 'Due around ${TimeOfDay.fromDateTime(DateTime.fromMillisecondsSinceEpoch(c.moment.wall + s.remaining(c.moment))).format(context)}',
                ),
                TextButton(
                  onPressed: () => SemanticsService.announce(
                    '$seconds seconds remaining',
                    Directionality.of(context),
                  ),
                  child: const Text('Read remaining time'),
                ),
              ],
              Text(
                s.timing == 'screen'
                    ? 'Counts screen-on, unlocked time. It does not verify attention.'
                    : 'Elapsed time for a session you started, including screen-off time.',
              ),
              if (s.tracking['activeUnavailable'] == true)
                const Text(
                  'Screen-time measurement paused: check Usage access.',
                ),
              if (s.tracking['activeRecovery'] != null)
                Text(s.tracking['activeRecovery']),
              const SizedBox(height: 16),
              Wrap(
                children: [
                  if (s.phase == Phase.idle)
                    button('Start work session', () => c.start()),
                  if (!rest) button('Take a break now', () => c.breakNow()),
                  if ([Phase.work, Phase.rest, Phase.due].contains(s.phase))
                    button('Pause for 15 min', () => c.pause()),
                  if (s.phase == Phase.paused)
                    button('Resume', () => c.resume()),
                  if ([
                    Phase.work,
                    Phase.due,
                    Phase.rest,
                    Phase.finished,
                  ].contains(s.phase))
                    button('Postpone 5 min', () => c.postpone()),
                  if (s.phase != Phase.idle)
                    button('Cancel session', () => c.cancel()),
                ],
              ),
            ],
          ),
        ),
      ),
      if (rest && activity != null)
        section(activity.title, [
          Text(
            '${activity.data['requiresVisualAttention'] == true ? 'Visual recreation' : 'Eyes-away'} • ${activity.category} • ${activity.data['requiresInput'] == true ? 'optional input' : 'no input required'}',
          ),
          const SizedBox(height: 12),
          Text(activity.text, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 16),
          Wrap(
            children: [
              button('Play / replay instructions', () => run(c.narrate)),
              button(
                'Stop narration',
                () => run(() => c.device.call('stopSpeech')),
              ),
              button(
                'Choose quiet rest',
                () => run(
                  () => c.act(() async {
                    final quiet = c.activities.firstWhere(
                      (a) => a.id == 'quiet.soft',
                    );
                    c.session = Session(id: s.id).at(
                      Phase.rest,
                      s.remaining(c.moment),
                      c.moment,
                      activityId: quiet.id,
                    );
                    await c.device.call('stopSpeech');
                  }),
                ),
              ),
              button('Capture an idea', () => editIdea()),
              if (activity.data['answer'] != null)
                button(
                  'Reveal answer',
                  () => showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Answer'),
                      content: Text(activity.data['answer']),
                      actions: [
                        TextButton(
                          onPressed: () => run(
                            () => c.device.call('speak', {
                              'steps': [
                                {
                                  'kind': 'narration',
                                  'text': activity.data['answer'],
                                },
                              ],
                              'voice': c.settings['voice'],
                              'rate': c.settings['rate'] ?? 1.0,
                              'volume': c.settings['volume'] ?? 0.8,
                            }),
                          ),
                          child: const Text('Read answer'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ),
                ),
              button(
                s.phase == Phase.finished
                    ? 'Confirm participation'
                    : 'I participated — finish early',
                () => c.complete(),
              ),
              button('Skip without credit', () => c.cancel()),
            ],
          ),
          const Text(
            'Progress records your participation, not verified movement, hydration, or eye rest. You may leave or skip at any time.',
          ),
        ]),
      if (capabilities['notifications'] == false)
        Card(
          child: ListTile(
            title: const Text('Background notifications are disabled'),
            subtitle: const Text(
              'Open Settings → Permissions & reminders to enable them.',
            ),
            onTap: () => setState(() => tab = 3),
          ),
        ),
      Text(
        'Next work session: ${c.settings['timing'] == 'screen' ? 'active screen time' : 'elapsed time'}',
      ),
      profilePicker(),
      section('Today', [
        Text('$completed completed breaks'),
        const Text(
          'Quiet rest counts too. No streak is lost when you take a day off.',
        ),
        if (c.settings['gamification'] != false)
          Text(
            'Your daily goal: ${c.settings['goal'] ?? 3} breaks. Progress: $completed.',
          ),
      ]),
      const Text(
        'Background reminders can be delayed by Android, battery settings or notification permissions. No overdue backlog is replayed.',
      ),
    ];
  }

  Future<void> dictate() => run(() async {
    if (dictating) {
      await c.device.call('stopDictation');
    } else {
      await c.device.call('dictate', {
        'language': c.settings['dictationLanguage'] ?? 'en-IN',
      });
      if (mounted) setState(() => dictating = true);
    }
  });
  Widget profilePicker() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: DropdownButtonFormField<String>(
      key: ValueKey('profile-${c.profile['id']}'),
      initialValue: c.profile['id'],
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Break profile'),
      items: c.profiles
          .map(
            (p) => DropdownMenuItem<String>(
              value: p['id'],
              child: Text('${p['name']} • ${p['breakSeconds']} seconds'),
            ),
          )
          .toList(),
      onChanged: (v) => c.updateSettings({'profile': v}),
    ),
  );
  Widget permissionsPanel() => section('Permission checklist', [
    popupControls(showPause: false),
    const Text(
      'Notifications — needed for background break reminders. Tapping a notification opens the break without popup permission.',
    ),
    Text(
      'Notifications: ${capabilities['notifications'] == true ? 'enabled' : 'disabled or unchecked'}',
    ),
    Wrap(
      children: [
        button(
          'Request notifications',
          () => run(() async {
            await c.device.call('notifications');
            await loadCapabilities();
          }),
        ),
        button(
          'Notification settings',
          () => run(() => c.device.call('notificationSettings')),
        ),
        button(
          'Test reminder in 10 seconds',
          () => run(() => c.device.call('testReminder')),
        ),
      ],
    ),
    const Text(
      'Usage access — needed for automatic active-screen routines; manual sessions work without it.',
    ),
    Text(
      'Screen-time access: ${capabilities['usage'] == true ? 'granted' : 'not granted'}. Only screen/lock events are counted; app names are not saved.',
    ),
    button(
      'Enable Usage access',
      () => run(() async {
        if (await confirm(
          'Screen-time access',
          'Android exposes usage events through this permission. AppBreak reads screen and lock transitions only; it stores no app-by-app history.',
        ))
          await c.device.call('usageAccess');
      }),
    ),
    Text(
      'Microphone — optional for Speak and Record. Access: ${capabilities['microphone'] == true ? 'granted' : 'not granted'}. Offline dictation: ${capabilities['dictation'] == true ? 'service available; language model still needs testing' : 'unavailable on this device'}. Microphone permission is requested when you tap Speak or Record.',
    ),
    button(
      'Allow microphone',
      () => run(() => c.device.call('microphoneAccess')),
      enabled: capabilities['microphone'] != true,
    ),
    button(
      'App permission settings',
      () => run(() => c.device.call('appSettings')),
    ),
    const Text(
      'If Android no longer shows a permission prompt, use App permission settings. No broad storage permission is needed: backups use the system file picker. Internet access for catalogue updates has no Android runtime prompt and can be disabled in Settings.',
    ),
    button('Refresh permission status', () => loadCapabilities()),
  ]);
  List<Widget> breakPlayer() {
    final a = c.current!;
    final s = c.session;
    final seconds = (s.remaining(c.moment) / 1000).ceil();
    final focus = c.settings['focusMode'] == true && s.phase == Phase.rest;
    final count = c.history.where((h) => h['category'] == a.category).length;
    return [
      Row(
        children: [
          Expanded(
            child: Text(
              s.phase == Phase.finished
                  ? 'Break time ended'
                  : 'Take a little space',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          ExcludeSemantics(
            child: Text(
              '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
        ],
      ),
      TextButton(
        onPressed: () => SemanticsService.announce(
          '$seconds seconds remaining',
          Directionality.of(context),
        ),
        child: const Text('Read remaining time'),
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                a.category == 'quiz'
                    ? Icons.question_mark
                    : a.category == 'imagination'
                    ? Icons.lightbulb_outline
                    : Icons.spa_outlined,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                a.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.primary
                      : Color(c.profile['color'] ?? 0xff356859),
                ),
              ),
              Text(
                a.data['requiresVisualAttention'] == true
                    ? 'Optional visual recreation'
                    : 'Eyes-away activity',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(a.text, style: Theme.of(context).textTheme.bodyLarge),
              if (a.data['answer'] != null)
                button(
                  'Reveal / read answer',
                  () => run(() async {
                    message(a.data['answer']);
                    if ((c.profile['quiet'] ?? true) != true)
                      await c.device.call('speak', {
                        'steps': [
                          {'kind': 'narration', 'text': a.data['answer']},
                        ],
                        'language': a.data['language'],
                        'voice': c.settings['voice'],
                        'rate': c.settings['rate'] ?? 1.0,
                        'volume': c.settings['volume'] ?? 0.8,
                      });
                  }),
                ),
              if (c.settings['gamification'] != false)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    '☆ $count ${a.category} sessions so far. Quiet rest counts too.',
                  ),
                ),
            ],
          ),
        ),
      ),
      SwitchListTile(
        title: const Text('Quiet break'),
        value: c.profile['quiet'] ?? c.settings['quiet'] ?? true,
        onChanged: (v) => run(() async {
          await c.updateProfile({'quiet': v});
          if (v) await c.device.call('stopSpeech');
        }),
      ),
      Text(
        '${c.alternatives.length} activities available to browse. Routine categories guide automatic suggestions.',
      ),
      if (a.seconds > seconds && s.phase == Phase.rest)
        Text(
          'Suggested duration: ${a.seconds} seconds; $seconds seconds remain. Try part of this activity or choose another.',
        ),
      if (s.phase == Phase.rest)
        Wrap(
          children: [
            button('Previous activity', () => c.cycleActivity(-1)),
            button('Next activity', () => c.cycleActivity(1)),
            button('Choose activity', () => chooseActivityDialog()),
            button('Quiet rest', () => c.switchActivity('quiet.soft')),
          ],
        ),
      Wrap(
        children: [
          button('Play / replay', () => run(c.narrate)),
          button(
            'Stop narration',
            () => run(() => c.device.call('stopSpeech')),
          ),
          if (s.phase == Phase.rest) button('Pause break', () => c.pause()),
        ],
      ),
      const Text(
        'Switching activities does not extend the break. Participation is self-reported.',
      ),
      section('Capture an idea', [
        Wrap(
          children: [
            button('Type', () => editIdea()),
            button(
              dictating ? 'Stop dictation' : 'Speak to text',
              () => dictate(),
            ),
            button(
              recording ? 'Stop and save audio' : 'Record audio instead',
              () => run(() async {
                if (recording) {
                  await c.device.call('stopRecord');
                  recording = false;
                } else {
                  await c.device.call('record');
                  recording = true;
                }
                if (mounted) setState(() {});
              }),
            ),
          ],
        ),
        if (dictationStatus.isNotEmpty) Text(dictationStatus),
        if (transcript.isNotEmpty) SelectableText(transcript),
        const Text(
          'Text is saved locally. Audio is retained only when you explicitly choose Record audio instead.',
        ),
      ]),
      Wrap(
        children: [
          if (!focus)
            button(
              s.phase == Phase.finished
                  ? 'Confirm participation'
                  : 'I participated — finish early',
              () => c.complete(),
            ),
          if (!focus) button('Skip without credit', () => c.cancel()),
          button(
            'Emergency exit',
            () => run(() async {
              await c.device.call('stopAudio');
              await c.device.call('stopRecord');
              await c.leaveBreak();
            }),
          ),
        ],
      ),
    ];
  }

  Future<void> chooseActivityDialog() async {
    final fit = c.alternatives;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choose an activity'),
        content: SizedBox(
          width: 480,
          child: ListView(
            shrinkWrap: true,
            children: [
              const Text(
                'Browse all activities except those disabled for this routine. Longer activities may not finish before the break ends; choosing one keeps the current timer.',
              ),
              for (final a in fit)
                ListTile(
                  title: Text(a.title),
                  subtitle: Text(
                    '${a.seconds} seconds • ${a.category}${a.seconds * 1000 > c.session.remaining(c.moment) ? ' • longer than time left' : ''}',
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    c.switchActivity(a.id);
                  },
                ),
              ListTile(
                title: const Text('Quiet rest for the remaining time'),
                onTap: () {
                  Navigator.pop(ctx);
                  c.switchActivity('quiet.soft');
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  List<Widget> routines() => [
    Text(
      'Task & lifestyle routines',
      style: Theme.of(context).textTheme.headlineMedium,
    ),
    const Text(
      'Independent reminders, one break at a time. Android may delay background delivery. Enable Usage access for automatic screen-use breaks. Sound and vibration are configured per routine in Android settings.',
    ),
    button('Permissions & reminders', () => setState(() => tab = 3)),
    button(
      'Add routine',
      () => editProfile({
        'id': 'r${DateTime.now().microsecondsSinceEpoch}',
        'name': 'New routine',
        'trigger': 'screen',
        'enabled': false,
        'breakSeconds': 30,
        'categories': ['quiet'],
        'selection': 'rotation',
      }),
    ),
    for (final p in c.profiles) routineCard(p),
  ];
  Widget routineCard(Map<String, dynamic> p) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = p['goalPeriod'] == 'weekly'
        ? today.subtract(Duration(days: today.weekday - 1))
        : today;
    final count = c.history.where((h) {
      final date = DateTime.tryParse(h['date'] ?? '');
      return h['routine'] == p['id'] &&
          date != null &&
          !date.isBefore(start) &&
          !date.isAfter(today);
    }).length;
    final state = (c.data['routineState'] as Map?)?[p['id']] as Map?;
    final left = state == null
        ? null
        : state['timing'] == 'screen'
        ? state['activeRemaining']
        : ((state['wallDue'] ?? c.moment.wall) - c.moment.wall);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              p['name'],
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Color(p['color'] ?? 0xff356859),
              ),
            ),
            SwitchListTile(
              title: Text('${p['trigger'] ?? 'manual'} routine'),
              value: p['enabled'] ?? false,
              onChanged: (v) => c.saveRoutine({...p, 'enabled': v}),
            ),
            if (state != null)
              Text(
                state['stopped'] == true
                    ? 'Session ended'
                    : state['phase'] == 'presented'
                    ? 'Break awaiting participation'
                    : state['phase'] == 'due'
                    ? 'Break ready; waiting for current break'
                    : p['trigger'] == 'scheduled'
                    ? 'Scheduled at ${((p['minuteOfDay'] ?? 540) ~/ 60).toString().padLeft(2, '0')}:${((p['minuteOfDay'] ?? 540) % 60).toString().padLeft(2, '0')}'
                    : '${((left ?? 0).clamp(0, 14400000) / 60000).ceil()} minutes remaining${state['activeUnavailable'] == true ? ' — Usage access unavailable' : ''}',
              ),
            if ((p['goal'] ?? 0) > 0)
              Text(
                '$count / ${p['goal']} confirmed breaks · ${p['goalPeriod'] ?? 'daily'} goal',
              ),
            Wrap(
              children: [
                button('Customize', () => editProfile(p)),
                if ((p['trigger'] ?? 'manual') == 'manual')
                  button(
                    'Start session',
                    () => run(() => c.startRoutine(p['id'])),
                    enabled: p['enabled'] == true,
                  ),
                button(
                  'Sound & vibration',
                  () => run(
                    () => c.device.call('routineChannel', {'id': p['id']}),
                  ),
                ),
                button(
                  'Delete',
                  () => run(() async {
                    if (await confirm(
                      'Delete this routine?',
                      'Completed participation and notes are kept.',
                    ))
                      await c.deleteRoutine(p['id']);
                  }),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> editProfile([Map<String, dynamic>? source]) async {
    final p = Map<String, dynamic>.from(source ?? c.profile);
    final form = GlobalKey<FormState>();
    final enabled = List<String>.from(p['categories'] ?? categories);
    final disabled = List<String>.from(p['disabledActivities'] ?? []);
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: Text('Customize ${p['name']}'),
          content: SizedBox(
            width: 520,
            child: Form(
              key: form,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...routineFields(ctx, p, update),
                    DropdownButtonFormField<String>(
                      initialValue: p['selection'] ?? 'rotation',
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Activity selection',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'rotation',
                          child: Text('Rotate activities'),
                        ),
                        DropdownMenuItem(
                          value: 'fixed',
                          child: Text('Fixed favourite'),
                        ),
                        DropdownMenuItem(
                          value: 'choose',
                          child: Text('Choose at break start'),
                        ),
                      ],
                      onChanged: (v) => update(() => p['selection'] = v),
                    ),
                    const Text(
                      'Choose at start opens quiet rest; use Choose activity when ready.',
                    ),
                    SwitchListTile(
                      title: const Text('Quiet mode for this profile'),
                      value: p['quiet'] ?? true,
                      onChanged: (v) => update(() => p['quiet'] = v),
                    ),
                    for (final cat in categories)
                      CheckboxListTile(
                        title: Text(cat),
                        value: enabled.contains(cat),
                        onChanged: (v) => update(() {
                          v == true ? enabled.add(cat) : enabled.remove(cat);
                        }),
                      ),
                    const Text(
                      'Individual activities — unchecked items are excluded from rotation and manual browsing. Automatic suggestions also respect category and duration; manual browsing includes other categories and longer activities.',
                    ),
                    for (final a in c.activities)
                      if (enabled.contains(a.category))
                        CheckboxListTile(
                          title: Text('${a.title} (${a.seconds}s)'),
                          value: !disabled.contains(a.id),
                          secondary: IconButton(
                            tooltip: 'Set favourite',
                            icon: Icon(
                              p['favourite'] == a.id
                                  ? Icons.star
                                  : Icons.star_border,
                            ),
                            onPressed: () =>
                                update(() => p['favourite'] = a.id),
                          ),
                          onChanged: (v) => update(() {
                            v == true
                                ? disabled.remove(a.id)
                                : disabled.add(a.id);
                          }),
                        ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (!form.currentState!.validate()) return;
                await c.saveRoutine({
                  ...p,
                  'categories': enabled,
                  'disabledActivities': disabled,
                });
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save routine'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> editIdea([Map<String, dynamic>? idea]) async {
    await c.device.call('stopSpeech');
    if (!mounted) return;
    final text = TextEditingController(
      text: idea?['text'] ?? c.data['ideaDraft']?['text'] ?? '',
    );
    final title = TextEditingController(
      text: idea?['title'] ?? c.data['ideaDraft']?['title'] ?? 'Idea',
    );
    Timer? draftTimer;
    Future<void> writeDraft() async {
      if (idea == null)
        await run(
          () => c.device.call('saveDraft', {
            'text': text.text,
            'title': title.text,
          }),
        );
    }

    void changedDraft() {
      draftTimer?.cancel();
      draftTimer = Timer(const Duration(milliseconds: 600), writeDraft);
    }

    text.addListener(changedDraft);
    title.addListener(changedDraft);
    flushDraft = writeDraft;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(idea == null ? 'Capture an idea' : 'Edit idea'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: text,
                maxLines: 5,
                maxLength: 100000,
                decoration: const InputDecoration(
                  labelText: 'Your private note',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save locally'),
          ),
        ],
      ),
    );
    draftTimer?.cancel();
    flushDraft = null;
    await writeDraft();
    if (saved == true) {
      await c.saveIdea(
        text.text,
        id: idea?['id'],
        recording: idea?['recording'],
        title: title.text,
      );
      if (c.error == null && idea == null) await c.device.call('clearDraft');
    }
    // Dialog transition may still reference its controllers; let Flutter collect them.
  }

  Future<void> sharePreview(String content, {String? audio}) async {
    final text = TextEditingController(text: content);
    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Preview exactly what leaves'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: text,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Selected text only — edit freely',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                audio == null
                    ? 'Only this text leaves. No recording, timestamps, filenames or unrelated history is attached. The receiving app controls it after sharing.'
                    : 'You explicitly selected ONE recording. The attachment will be named voice-note.m4a. Listen to it before sharing; its spoken content may be private. No other notes are included.',
              ),
              if (audio != null)
                TextButton(
                  onPressed: () =>
                      run(() => c.device.call('play', {'name': audio})),
                  child: const Text('Preview selected recording'),
                ),
              const Text('Opening the share sheet does not prove publication.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Open share sheet'),
          ),
        ],
      ),
    );
    if (approved == true)
      await run(
        () => c.device.call(audio == null ? 'shareText' : 'shareAudio', {
          'text': text.text,
          if (audio != null) 'name': audio,
        }),
      );
  }

  List<Widget> ideas() => [
    Text(
      'Ideas, kept here.',
      style: Theme.of(context).textTheme.headlineMedium,
    ),
    const SizedBox(height: 16),
    Wrap(
      children: [
        button('Write an idea', () => editIdea()),
        button(dictating ? 'Stop dictation' : 'Speak to text', () => dictate()),
        button(
          recording ? 'Stop and save recording' : 'Record a voice idea',
          () => run(() async {
            await c.device.call('stopSpeech');
            if (recording) {
              await c.device.call('stopRecord');
              recording = false;
            } else {
              await c.device.call('record');
              recording = true;
            }
            await c.refresh();
            if (mounted) setState(() {});
          }),
        ),
        button('Stop playback', () => run(() => c.device.call('stopAudio'))),
      ],
    ),
    const Text(
      'Speak to text uses only an available on-device recognizer and saves editable text. Record a voice idea separately when you want to retain audio. Both stop when you leave or lock the app. No cloud fallback.',
    ),
    if (dictationStatus.isNotEmpty) Text(dictationStatus),
    if (transcript.isNotEmpty) SelectableText(transcript),
    const SizedBox(height: 16),
    TextField(
      decoration: const InputDecoration(
        labelText: 'Search titles and note text',
        prefixIcon: Icon(Icons.search),
      ),
      onChanged: (v) => setState(() => search = v.toLowerCase()),
    ),
    FilterChip(
      label: const Text('Only voice notes'),
      selected: categoryFilter == 'audio',
      onSelected: (v) => setState(() => categoryFilter = v ? 'audio' : null),
    ),
    ...c.ideas
        .where(
          (n) =>
              '${n['title']} ${n['text']}'.toLowerCase().contains(search) &&
              (categoryFilter != 'audio' || n['recording'] != null),
        )
        .map((raw) {
          final n = Map<String, dynamic>.from(raw);
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n['title'] ?? 'Idea',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(n['text'] ?? ''),
                  if (n['activity'] != null) Text('Activity: ${n['activity']}'),
                  const SizedBox(height: 12),
                  Wrap(
                    children: [
                      button('Edit / rename', () => editIdea(n)),
                      button(
                        'Share selected text',
                        () => sharePreview(shareIdea(n)),
                      ),
                      button(
                        'Save text to file',
                        () => run(
                          () => c.device.call('saveText', {'text': n['text']}),
                        ),
                      ),
                      if (n['recording'] != null) ...[
                        button(
                          'Share this recording…',
                          () =>
                              sharePreview(shareIdea(n), audio: n['recording']),
                        ),
                        button(
                          'Play recording',
                          () => run(
                            () =>
                                c.device.call('play', {'name': n['recording']}),
                          ),
                        ),
                        button(
                          'Save audio to file',
                          () => run(
                            () => c.device.call('saveAudio', {
                              'name': n['recording'],
                            }),
                          ),
                        ),
                      ],
                      button(
                        'Delete',
                        () => run(() async {
                          if (await confirm(
                            'Delete this idea?',
                            'Its text and recording will be removed.',
                          ))
                            await c.deleteIdea(n['id']);
                        }),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
  ];
  List<Widget> achievements() => [
    Text('Break dashboard', style: Theme.of(context).textTheme.headlineMedium),
    Text('${c.history.length} completed • ${c.missedBreaks.length} missed'),
    const Text(
      'Missed includes skipped and unconfirmed breaks. You can confirm an earlier break without changing your current timer.',
    ),
    if (c.breakRecords.isEmpty)
      const ListTile(title: Text('No breaks recorded yet')),
    ...c.breakRecords.map(
      (record) => Card(
        child: ListTile(
          leading: Icon(
            record['status'] == 'Completed'
                ? Icons.check_circle_outline
                : Icons.history,
          ),
          title: Text(
            '${record['status']} • ${c.activities.where((a) => a.id == record['activity']).firstOrNull?.title ?? 'Break'}',
          ),
          subtitle: Text(
            '${record['date']} • ${c.profiles.where((p) => p['id'] == (record['routine'] ?? record['routineId'])).firstOrNull?['name'] ?? 'Routine'}${record['status'] == 'Missed' ? ' • ${record['reason'] ?? 'unconfirmed'}' : ''}',
          ),
          trailing: record['status'] == 'Missed'
              ? TextButton(
                  onPressed: () =>
                      run(() => c.confirmArchivedBreak(record['id'])),
                  child: const Text('I took it'),
                )
              : null,
        ),
      ),
    ),
    const Divider(),
    Text(
      'Participation, at your pace.',
      style: Theme.of(context).textTheme.headlineMedium,
    ),
    const SizedBox(height: 12),
    const Text(
      'These are self-reported participation milestones. Quiet breaks count equally. Sharing never earns rewards.',
    ),
    if (c.settings['gamification'] == false)
      const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Gamification is off. Core break history remains available.',
        ),
      )
    else
      ...badges(c.history).values.map(
        (b) => Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b['title'], style: Theme.of(context).textTheme.titleLarge),
                Text(
                  '${b['count']} of ${b['target']}${b['earned'] != null ? ' • Earned ${b['earned']}' : ''}',
                ),
                if (b['earned'] != null)
                  button(
                    'Share this milestone',
                    () => sharePreview(shareBadge(b)),
                  ),
              ],
            ),
          ),
        ),
      ),
  ];
  Widget toggle(String title, String key, bool initial) => SwitchListTile(
    title: Text(title),
    value: c.settings[key] ?? initial,
    onChanged: (v) => c.updateSettings({key: v}),
  );
  Future<void> number(
    String key,
    String label,
    int value,
    int min,
    int max, {
    bool routine = false,
    int scale = 1,
  }) async {
    final input = TextEditingController(text: '${value ~/ scale}');
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: input,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            helperText: '${min ~/ scale}–${max ~/ scale}',
            labelText: label,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final n = int.tryParse(input.text);
              if (n != null && n >= min ~/ scale && n <= max ~/ scale)
                Navigator.pop(ctx, n * scale);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null) {
      if (routine || key == 'breakSeconds') {
        await c.updateProfile({key: result});
      } else {
        await c.updateSettings({key: result});
      }
    }
  }

  Widget languageAndInteractionSettings() => section('Language & interaction', [
    const Text(
      'English (India), normal speaking speed and quiet instructions are used initially. Change these only if needed.',
    ),
    DropdownButtonFormField<String>(
      initialValue: c.settings['dictationLanguage'] ?? 'en-IN',
      decoration: const InputDecoration(labelText: 'Dictation language'),
      items: const [
        DropdownMenuItem(value: 'en-IN', child: Text('English (India)')),
        DropdownMenuItem(value: 'hi-IN', child: Text('Hindi')),
        DropdownMenuItem(value: 'kn-IN', child: Text('Kannada')),
        DropdownMenuItem(value: 'ta-IN', child: Text('Tamil')),
      ],
      onChanged: (v) => c.updateSettings({'dictationLanguage': v}),
    ),
    toggle(
      'Focus mode: hide ordinary skip / finish-early controls',
      'focusMode',
      false,
    ),
    const Text(
      'Emergency exit and Android navigation always remain available. Speech-to-text saves text only. Audio retention uses the separate Record control; simultaneous transcription plus retained audio is not yet supported.',
    ),
  ]);

  String get popupStatus {
    if (c.settings['popup'] == false) return 'Off';
    if (c.popupPauseRemainingMs > 0)
      return 'Paused · ${(c.popupPauseRemainingMs / 60000).ceil()} min left';
    if (capabilities['overlay'] != true)
      return 'Setup needed · allow display over other apps';
    return 'On · interrupts screen time';
  }

  Widget popupControls({bool showPause = true}) => section('Break popups', [
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Interrupt with a popup'),
      subtitle: Text(popupStatus),
      value: c.settings['popup'] != false,
      onChanged: (enabled) => run(() async {
        await c.setPopups(enabled);
        if (enabled && capabilities['overlay'] != true)
          await c.device.call('overlayAccess');
      }),
    ),
    if (c.settings['popup'] != false && capabilities['overlay'] != true)
      button(
        'Enable popup access',
        () => run(() => c.device.call('overlayAccess')),
      ),
    if (showPause && c.settings['popup'] != false)
      Wrap(
        children: [
          button('Pause 15 min', () => c.pausePopups(15)),
          button('Pause 1 hour', () => c.pausePopups(60)),
          button('Pause 2 hours', () => c.pausePopups(120)),
          if (c.popupPauseRemainingMs > 0)
            button('Resume popups now', () => c.setPopups(true)),
        ],
      ),
    const Text(
      'Pauses end automatically. Notifications and timers continue; an already-open break stays open. Android may delay popups while locked or restricted.',
    ),
  ]);

  List<Widget> settings() => [
    Text('Everyday settings', style: Theme.of(context).textTheme.headlineSmall),
    popupControls(),
    section('Your break routine', [
      profilePicker(),
      Wrap(
        children: [
          button(
            'Work interval: ${(c.profile['workSeconds'] ?? c.workSeconds) ~/ 60} min',
            () => number(
              'workSeconds',
              'Work interval in minutes',
              c.profile['workSeconds'] ?? c.workSeconds,
              60,
              14400,
              routine: true,
              scale: 60,
            ),
          ),
          button(
            'Break duration: ${c.breakSeconds} sec',
            () => number(
              'breakSeconds',
              'Break duration in seconds',
              c.breakSeconds,
              20,
              300,
            ),
          ),
        ],
      ),
      const Text(
        'Configure timing for this routine. Existing break countdowns are not extended.',
      ),
      button('Activity & routine preferences', () => editProfile()),
      button(
        'Notification sound & vibration',
        () =>
            run(() => c.device.call('routineChannel', {'id': c.profile['id']})),
      ),
    ]),
    button('Permissions & setup', openSetup),
    ListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Advanced settings'),
      subtitle: const Text(
        'Language, voices, schedules, activity downloads, progress and backups',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => setState(() => advancedOpen = true),
    ),
  ];

  List<Widget> advancedSettings() => [
    languageAndInteractionSettings(),
    section('Community break activities', [
      SwitchListTile(
        title: const Text('Check for community activities weekly'),
        subtitle: const Text(
          'Downloads reviewed text from GitHub when the app is open and idle. GitHub sees your IP address. Notes and progress are never sent.',
        ),
        value: c.catalogEnabled,
        onChanged: (v) => run(() => c.setCatalogEnabled(v)),
      ),
      Text(c.catalogStatus),
      Text(
        '${c.catalog.length} cached community activities. Manual checks are limited to once per day. Checks wait until your session ends.',
      ),
      button(
        'Check for new activities',
        () => run(() => c.refreshCatalog(manual: true)),
      ),
    ]),
    section('Schedules & manual timing', [
      DropdownButtonFormField<String>(
        initialValue: c.settings['timing'] ?? 'elapsed',
        decoration: const InputDecoration(labelText: 'Count time by'),
        items: const [
          DropdownMenuItem(value: 'elapsed', child: Text('Elapsed time')),
          DropdownMenuItem(value: 'screen', child: Text('Active screen time')),
        ],
        onChanged: (v) async {
          if (v == 'screen' && capabilities['usage'] != true) {
            message(
              'Enable Usage access in Permissions & setup first. Screen-time mode requires Android 9 or later.',
            );
            return;
          }
          await c.updateSettings({'timing': v});
        },
      ),
      const Text(
        'Mode changes apply to the next work session. Existing counters are preserved. Screen time includes video viewing, not verified attention.',
      ),
      toggle('Limit reminders to active hours', 'activeEnabled', false),
      Wrap(
        children: [
          button(
            'Active from ${c.settings['activeStart'] ?? 9}:00',
            () => number(
              'activeStart',
              'Start hour',
              c.settings['activeStart'] ?? 9,
              0,
              23,
            ),
          ),
          button(
            'Active until ${c.settings['activeEnd'] ?? 18}:00',
            () => number(
              'activeEnd',
              'End hour',
              c.settings['activeEnd'] ?? 18,
              0,
              23,
            ),
          ),
        ],
      ),
      toggle('Quiet hours', 'quietHours', false),
      Wrap(
        children: [
          button(
            'Quiet from ${c.settings['quietStart'] ?? 22}:00',
            () => number(
              'quietStart',
              'Quiet start hour',
              c.settings['quietStart'] ?? 22,
              0,
              23,
            ),
          ),
          button(
            'Quiet until ${c.settings['quietEnd'] ?? 7}:00',
            () => number(
              'quietEnd',
              'Quiet end hour',
              c.settings['quietEnd'] ?? 7,
              0,
              23,
            ),
          ),
        ],
      ),
      const Text(
        'Hours use local time. Equal start and end means all day. A reminder outside allowed hours is discarded; start another work session when ready.',
      ),
      button(
        'Enable notifications',
        () => run(() => c.device.call('notifications')),
      ),
    ]),
    button('Import private activity pack', () => run(c.importPack)),
    section('Audio and accessibility', [
      const Text(
        'Narration or quiet mode is selected separately for each break profile.',
      ),
      toggle('Start cue sound and haptic', 'cues', false),
      button(
        'Find installed offline voices',
        () => run(() async {
          final result = await c.device.call<List>('voices');
          voices = (result ?? [])
              .map((v) => Map<String, dynamic>.from(v))
              .toList();
          setState(() {});
          if (voices.isEmpty)
            message(
              'No offline voices found. Install a local voice or use quiet mode.',
            );
        }),
      ),
      ...voices.map(
        (v) => RadioListTile<String>(
          title: Text('${v['language']} • ${v['name']}'),
          value: v['name'],
          groupValue: c.settings['voice'],
          onChanged: (v) => c.updateSettings({'voice': v}),
        ),
      ),
      button(
        'Open speech voice installer',
        () => run(() => c.device.call('installVoice')),
      ),
      const Text(
        'Only installed voices marked offline are used. Installing voice data may need a download from the speech engine. No automatic network fallback.',
      ),
      Text('Speaking rate: ${c.settings['rate'] ?? 1.0}'),
      Slider(
        value: ((c.settings['rate'] ?? 1.0) as num).toDouble(),
        min: 0.5,
        max: 1.5,
        divisions: 10,
        label: 'Speaking rate',
        onChanged: (v) => c.updateSettings({'rate': v}),
      ),
      Text('Narration volume: ${c.settings['volume'] ?? 0.8}'),
      Slider(
        value: ((c.settings['volume'] ?? 0.8) as num).toDouble(),
        min: 0,
        max: 1,
        divisions: 10,
        label: 'Narration volume',
        onChanged: (v) => c.updateSettings({'volume': v}),
      ),
      button(
        'Accessibility walkthrough',
        () => showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Use AppBreak your way'),
            content: const SingleChildScrollView(
              child: Text(
                'Quiet rest needs no screen interaction. Narration is opt-in. With TalkBack active, use its reading controls; app narration is disabled to avoid overlap. System text scaling is supported. Buttons are labelled and keyboard-focusable. Timers are not announced every second; use Read remaining time. There are no animated celebrations. You may always cancel or leave a break. Recording stops if you leave or lock the app.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    ]),
    section('Progress', [
      toggle('Show optional gamification', 'gamification', true),
      button(
        'Daily goal: ${c.settings['goal'] ?? 3}',
        () =>
            number('goal', 'Daily break goal', c.settings['goal'] ?? 3, 1, 30),
      ),
    ]),
    section('Data & backup', [
      const Text(
        'No accounts, analytics, or automatic uploads. The system file picker can include cloud providers: choose your destination carefully. Backups are unencrypted; keep them private.',
      ),
      button(
        'Check storage usage',
        () => run(
          () async =>
              'App-private data: ${((await c.device.call<int>('usage') ?? 0) / 1024).ceil()} KiB',
        ),
      ),
      CheckboxListTile(
        title: const Text('Include recordings in manual backup'),
        value: includeAudio,
        onChanged: (v) => setState(() => includeAudio = v ?? false),
      ),
      button(
        'Save backup to chosen file',
        () => run(() => c.device.call('backup', {'audio': includeAudio})),
      ),
      button(
        'Choose backup to restore',
        () => run(() async {
          final p = await c.device.call<Map>('previewRestore');
          if (p != null &&
              await confirm(
                'Replace local data?',
                'Selected provider: ${p['provider']} (may be cloud-backed). Backup has ${p['ideas']} ideas and ${p['sessions']} sessions. This replaces current data; running sessions are cancelled.',
              )) {
            await c.device.call('restore');
            await c.refresh();
          }
        }),
      ),
      button(
        'Delete session history',
        () => run(() async {
          if (await confirm(
            'Delete session history?',
            'Milestones will be recalculated from the remaining history.',
          ))
            await c.act(() async {
              c.data['history'] = [];
              c.data['missedBreaks'] = [];
            });
        }),
      ),
      button(
        'Delete all personal data',
        () => run(() async {
          if (await confirm(
            'Delete everything?',
            'Settings, history, ideas and recordings will be removed. Export a backup first if needed.',
          )) {
            await c.device.call('deleteAll');
            c.readCatalog(await c.device.call<String>('catalogLoad'));
            await c.refresh();
          }
        }),
      ),
    ]),
  ];
}
