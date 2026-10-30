import 'package:flutter/material.dart';
import '../application/controller.dart';
import 'day_timeline.dart';

class DayPlanner extends StatefulWidget {
  final Companion controller;
  const DayPlanner({super.key, required this.controller});
  @override
  State<DayPlanner> createState() => _DayPlannerState();
}

class _DayPlannerState extends State<DayPlanner> {
  DateTime day = DateUtils.dateOnly(DateTime.now());
  late String view;
  bool get calendar => view == 'calendar';
  @override
  void initState() {
    super.initState();
    final saved = widget.controller.settings['plannerView'];
    view = ['calendar', 'day', 'list'].contains(saved) ? saved : 'calendar';
  }

  void selectDate(DateTime value) {
    setState(() {
      day = value;
      view = 'day';
    });
    c.updateSettings({'plannerView': 'day'});
  }

  Companion get c => widget.controller;
  List<Map<String, dynamic>> plansFor(DateTime value) {
    final key = value.toIso8601String().substring(0, 10);
    return c.plans
        .where(
          (p) => (p['days'] as List).isEmpty
              ? p['date'] == key
              : key.compareTo(p['date']) >= 0 &&
                    (p['days'] as List).contains(value.weekday),
        )
        .toList()
      ..sort((a, b) => (a['minute'] as int).compareTo(b['minute'] as int));
  }

  void move(int direction) => setState(() {
    day = calendar
        ? DateTime(day.year, day.month + direction, 1)
        : DateTime(day.year, day.month, day.day + direction);
  });
  Widget monthGrid() {
    final first = DateTime(day.year, day.month, 1);
    final length = DateTime(day.year, day.month + 1, 0).day;
    final leading = first.weekday - 1;
    final cells = ((leading + length + 6) ~/ 7) * 7;
    final theme = Theme.of(context);
    final today = DateUtils.dateOnly(DateTime.now());
    final local = MaterialLocalizations.of(context);
    return Column(
      children: [
        Row(
          children: [
            for (final name in [
              'Mon',
              'Tue',
              'Wed',
              'Thu',
              'Fri',
              'Sat',
              'Sun',
            ])
              Expanded(
                child: Center(
                  child: Text(name, style: theme.textTheme.labelSmall),
                ),
              ),
          ],
        ),
        GridView.builder(
          key: const ValueKey('planner-calendar'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: 48 + MediaQuery.textScalerOf(context).scale(16),
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: cells,
          itemBuilder: (context, index) {
            final number = index - leading + 1;
            if (number < 1 || number > length) return const SizedBox();
            final value = DateTime(day.year, day.month, number);
            final count = plansFor(value).length;
            final selected = DateUtils.isSameDay(day, value);
            final isToday = DateUtils.isSameDay(today, value);
            return Semantics(
              button: true,
              onTap: () => selectDate(value),
              selected: selected,
              label:
                  '${local.formatFullDate(value)}, $count planned activities${isToday ? ', today' : ''}',
              child: ExcludeSemantics(
                child: Material(
                  color: selected
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: isToday
                        ? BorderSide(color: theme.colorScheme.primary, width: 2)
                        : BorderSide.none,
                  ),
                  child: InkWell(
                    key: ValueKey(
                      'calendar-${value.toIso8601String().substring(0, 10)}',
                    ),
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => selectDate(value),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '$number',
                              style: TextStyle(
                                fontWeight: selected || isToday
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: selected
                                    ? theme.colorScheme.onPrimaryContainer
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (count > 0)
                          Icon(
                            Icons.circle,
                            size: 6,
                            color: theme.colorScheme.primary,
                          )
                        else
                          const SizedBox(height: 6),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'A dot marks a day with planned activities. Tap a date to view or add plans.',
          ),
        ),
      ],
    );
  }

  String get date => day.toIso8601String().substring(0, 10);
  Future<void> edit([Map<String, dynamic>? p]) async {
    final title = TextEditingController(text: p?['title'] ?? '');
    final minutes = TextEditingController(text: '${p?['minutes'] ?? 60}');
    var minute = p?['minute'] ?? 540;
    var routine = p?['routine'] ?? c.profiles.first['id'];
    if (!c.profiles.any((r) => r['id'] == routine))
      routine = c.profiles.first['id'];
    final days = List<int>.from(p?['days'] ?? []);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Plan activity'),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: title,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      labelText: 'Activity name',
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final t = await showTimePicker(
                        context: ctx,
                        initialTime: TimeOfDay(
                          hour: minute ~/ 60,
                          minute: minute % 60,
                        ),
                      );
                      if (t != null) set(() => minute = t.hour * 60 + t.minute);
                    },
                    child: Text(
                      'Starts ${TimeOfDay(hour: minute ~/ 60, minute: minute % 60).format(ctx)}',
                    ),
                  ),
                  TextField(
                    controller: minutes,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Duration: 1–720 minutes',
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: routine,
                    items: c.profiles
                        .map(
                          (r) => DropdownMenuItem<String>(
                            value: r['id'],
                            child: Text(r['name']),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => set(() => routine = v!),
                    decoration: const InputDecoration(
                      labelText: 'Break routine',
                    ),
                  ),
                  const Text(
                    'Repeat on selected weekdays. Leave empty for this date only.',
                  ),
                  Wrap(
                    children: List.generate(
                      7,
                      (i) => FilterChip(
                        label: Text(
                          const ['M', 'Tu', 'W', 'Th', 'F', 'Sa', 'Su'][i],
                        ),
                        selected: days.contains(i + 1),
                        onSelected: (v) =>
                            set(() => v ? days.add(i + 1) : days.remove(i + 1)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final n = int.tryParse(minutes.text);
                if (title.text.trim().isNotEmpty &&
                    n != null &&
                    n >= 1 &&
                    n <= 720)
                  Navigator.pop(ctx, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (saved == true)
      await c.savePlan({
        'id': p?['id'] ?? 'plan-${DateTime.now().microsecondsSinceEpoch}',
        'title': title.text.trim(),
        'date': p?['date'] ?? date,
        'minute': minute,
        'minutes': int.parse(minutes.text),
        'days': days,
        'routine': routine,
      });
    title.dispose();
    minutes.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plans = plansFor(day);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'My Day',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: 'calendar',
                icon: Icon(Icons.calendar_month),
                label: Text('Month'),
              ),
              ButtonSegment(
                value: 'day',
                icon: Icon(Icons.view_day),
                label: Text('Day'),
              ),
              ButtonSegment(
                value: 'list',
                icon: Icon(Icons.view_list),
                label: Text('List'),
              ),
            ],
            selected: {view},
            onSelectionChanged: (values) {
              setState(() => view = values.single);
              c.updateSettings({'plannerView': view});
            },
          ),
        ),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            IconButton(
              tooltip: calendar ? 'Previous month' : 'Previous day',
              onPressed: () => move(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            Text(
              calendar
                  ? MaterialLocalizations.of(context).formatMonthYear(day)
                  : date,
            ),
            IconButton(
              tooltip: calendar ? 'Next month' : 'Next day',
              onPressed: () => move(1),
              icon: const Icon(Icons.chevron_right),
            ),
            TextButton(
              onPressed: () =>
                  setState(() => day = DateUtils.dateOnly(DateTime.now())),
              child: const Text('Today'),
            ),
            TextButton(
              onPressed: () => edit(),
              child: const Text('Plan activity'),
            ),
          ],
        ),
        const Text(
          'Plans invite you to start; time passing never earns completion. Background alerts may be delayed by Android.',
        ),
        if (calendar) monthGrid(),
        Text(
          MaterialLocalizations.of(context).formatFullDate(day),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (plans.isEmpty) const Text('No activities planned.'),
        if (view == 'day')
          DayTimeline(
            day: day,
            plans: plans,
            status: statusFor,
            routine: routineFor,
            onOpen: openPlan,
          )
        else
          for (final p in plans) planCard(p),
      ],
    );
  }

  String routineFor(Map<String, dynamic> p) {
    final profiles = c.profiles.where((r) => r['id'] == p['routine']);
    if (profiles.isEmpty) return 'Break routine removed — edit this plan';
    final r = profiles.first;
    final work = (r['workSeconds'] as num? ?? 1500) / 60;
    final rest = (r['breakSeconds'] as num? ?? 60) / 60;
    String minutes(num n) =>
        n == n.roundToDouble() ? n.toInt().toString() : n.toStringAsFixed(1);
    return '${r['name']} · ${minutes(work)} min ${r['trigger'] == 'screen' ? 'screen use' : 'work'} / ${minutes(rest)} min break';
  }

  String statusFor(Map<String, dynamic> p) {
    final r =
        (c.data['planRecords'] as Map? ?? {})['${p['id']}@$date'] as Map? ?? {};
    return r['status'] ??
        (DateTime.now().isAfter(
              day.add(Duration(minutes: p['minute'] + p['minutes'])),
            )
            ? 'missed'
            : 'planned');
  }

  Future<void> openPlan(Map<String, dynamic> p) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Planned activity'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: AnimatedBuilder(
              animation: c,
              builder: (_, _) {
                final current = c.plans.where((plan) => plan['id'] == p['id']);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (current.isEmpty)
                      const Text('Plan removed. History is retained.')
                    else
                      planCard(current.first),
                    if (c.error != null)
                      Text(
                        c.error!,
                        style: TextStyle(
                          color: Theme.of(ctx).colorScheme.error,
                        ),
                      ),
                  ],
                );
              },
            ),
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

  Widget planCard(Map<String, dynamic> p) {
    final r =
        (c.data['planRecords'] as Map? ?? {})['${p['id']}@$date'] as Map? ?? {};
    final status = statusFor(p);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(p['title'], style: Theme.of(context).textTheme.titleMedium),
            Text(
              '${TimeOfDay(hour: p['minute'] ~/ 60, minute: p['minute'] % 60).format(context)} · ${p['minutes']} min · $status',
            ),
            Text(routineFor(p)),
            if (r['end'] != null && status == 'active')
              Text(
                'Session ends: ${TimeOfDay.fromDateTime(DateTime.fromMillisecondsSinceEpoch(r['end'])).format(context)}',
              ),
            if (r['remindAt'] != null)
              Text(
                'Reminder: ${TimeOfDay.fromDateTime(DateTime.fromMillisecondsSinceEpoch(r['remindAt'])).format(context)}',
              ),
            Wrap(
              children: [
                for (final a in [
                  ('start', 'Start now'),
                  ('delay', 'Delay 10 min'),
                  ('complete', 'Mark completed'),
                  ('extend', 'Extend 15 min'),
                  ('skip', 'Skip block'),
                ])
                  if (switch (a.$1) {
                    'start' => [
                      'planned',
                      'prompted',
                      'delayed',
                      'missed',
                    ].contains(status),
                    'delay' => [
                      'planned',
                      'prompted',
                      'delayed',
                    ].contains(status),
                    'complete' => ['active', 'ended'].contains(status),
                    'extend' => status == 'active',
                    _ => !['completed', 'skipped'].contains(status),
                  })
                    TextButton(
                      onPressed: () => c.planAction(p['id'], date, a.$1),
                      child: Text(a.$2),
                    ),
                if (status != 'active')
                  TextButton(
                    onPressed: () => edit(p),
                    child: const Text('Edit'),
                  ),
                if (status != 'active')
                  TextButton(
                    onPressed: () => c.planAction(p['id'], date, 'delete'),
                    child: const Text('Delete plan'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
