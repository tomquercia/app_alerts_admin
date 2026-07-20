import 'package:flutter/material.dart';

/// A labeled field for an optional UTC timestamp.
///
/// The contract stores timestamps in UTC (ISO-8601). This field presents and
/// edits them in the user's *local* time for sanity, converting on the way in
/// and out, so `value`/`onChanged` always speak UTC.
class DateTimeField extends StatelessWidget {
  /// Creates the field.
  const DateTimeField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.helperText,
  });

  /// Field label.
  final String label;

  /// Current value in UTC, or null when unset.
  final DateTime? value;

  /// Called with a new UTC value, or null when cleared.
  final ValueChanged<DateTime?> onChanged;

  /// Optional helper text under the field.
  final String? helperText;

  /// Formats a UTC [dt] as a friendly local string.
  static String formatLocal(DateTime dt) {
    final DateTime local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)}  '
        '${two(local.hour)}:${two(local.minute)}';
  }

  Future<void> _pick(BuildContext context) async {
    final DateTime base = (value ?? DateTime.now().toUtc()).toLocal();
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !context.mounted) return;
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null) return;
    final DateTime local =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    onChanged(local.toUtc());
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DateTime? v = value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            helperText: helperText,
            prefixIcon: const Icon(Icons.schedule),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  v == null ? 'Not set' : '${formatLocal(v)}  (local)',
                  style: v == null
                      ? theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant)
                      : theme.textTheme.bodyMedium,
                ),
              ),
              if (v != null)
                IconButton(
                  tooltip: 'Clear',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => onChanged(null),
                ),
              TextButton.icon(
                onPressed: () => _pick(context),
                icon: const Icon(Icons.edit_calendar, size: 18),
                label: Text(v == null ? 'Set' : 'Change'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
