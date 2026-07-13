import 'package:flutter/material.dart';

import 'common.dart';

/// The weekly timetable, shared by the student and teacher screens —
/// both APIs return the same shape:
///   { "today": "mon", "days": { "mon": [ {period, start, end, subject, ...} ] } }
///
/// A day-picker chip row on top, the chosen day's periods below as a
/// timeline: time pill on the left, subject card (colour-coded by
/// subject) on the right.
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
    final today = widget.data['today'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day picker — pills, with a dot marking today.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _dayLabels.entries.map((entry) {
              final selected = entry.key == _selected;
              final isToday = entry.key == today;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _selected = entry.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? scheme.primary : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: selected ? null : softShadow(context),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          entry.value,
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : const Color(0xFF4A5568),
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isToday
                                ? (selected ? Colors.white : scheme.primary)
                                : Colors.transparent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 18),

        if (periods.isEmpty)
          const EmptyState(
            icon: Icons.free_breakfast_outlined,
            message: 'No classes on this day.',
          )
        else
          ...periods.map((p) {
            final period = p as Map<String, dynamic>;
            final subject = (period['subject'] as String?) ?? 'Class';
            final tint = colorFor(subject);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time column.
                  SizedBox(
                    width: 52,
                    child: Column(
                      children: [
                        Text(
                          period['start'] ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          period['end'] ?? '',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF8A94A6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Subject card with a colour spine.
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: softShadow(context),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 40,
                            decoration: BoxDecoration(
                              color: tint,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  subject,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  [
                                    // Student payload has `teacher`;
                                    // teacher payload has `section`.
                                    if (period['teacher'] != null)
                                      period['teacher'],
                                    if (period['section'] != null)
                                      period['section'],
                                    if (period['room'] != null)
                                      'Room ${period['room']}',
                                  ].join(' · '),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF6B7686),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: tint.withValues(alpha: .1),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'P${period['period']}',
                              style: TextStyle(
                                color: tint,
                                fontWeight: FontWeight.w800,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}
