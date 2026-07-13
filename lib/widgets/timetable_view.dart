import 'package:flutter/material.dart';

import 'common.dart';

/// The weekly timetable, shared by the student and teacher screens —
/// both APIs return the same shape:
///   { "today": "mon", "days": { "mon": [ {period, start, end, subject, ...} ] } }
///
/// A day-picker chip row on top, the chosen day's periods below.
class TimetableView extends StatefulWidget {
  const TimetableView({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  State<TimetableView> createState() => _TimetableViewState();
}

class _TimetableViewState extends State<TimetableView> {
  static const _dayLabels = {
    'mon': 'Mon',
    'tue': 'Tue',
    'wed': 'Wed',
    'thu': 'Thu',
    'fri': 'Fri',
    'sat': 'Sat',
    'sun': 'Sun',
  };

  late String _selected;

  @override
  void initState() {
    super.initState();
    // Open on today's column (fall back to Monday on weekends with no data).
    _selected = (widget.data['today'] as String?) ?? 'mon';
    if (_periodsFor(_selected).isEmpty) _selected = 'mon';
  }

  List<dynamic> _periodsFor(String day) {
    final days = widget.data['days'] as Map<String, dynamic>? ?? {};
    return (days[day] as List<dynamic>?) ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final periods = _periodsFor(_selected);
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day picker.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _dayLabels.entries.map((entry) {
              final selected = entry.key == _selected;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(entry.value),
                  selected: selected,
                  onSelected: (_) => setState(() => _selected = entry.key),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),

        if (periods.isEmpty)
          const EmptyState(
            icon: Icons.free_breakfast_outlined,
            message: 'No classes on this day.',
          )
        else
          ...periods.map((p) {
            final period = p as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  child: Text(
                    '${period['period']}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
                title: Text(
                  (period['subject'] as String?) ?? 'Class',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text([
                  // Student payload has `teacher`; teacher payload has `section`.
                  if (period['teacher'] != null) period['teacher'],
                  if (period['section'] != null) period['section'],
                  if (period['room'] != null) 'Room ${period['room']}',
                ].join(' · ')),
                trailing: Text(
                  '${period['start'] ?? ''}\n${period['end'] ?? ''}',
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            );
          }),
      ],
    );
  }
}
