import 'package:app_alerts/app_alerts.dart';
import 'package:flutter/material.dart';

/// A small colored chip indicating an alert's [AlertType].
class TypeBadge extends StatelessWidget {
  /// Creates a badge for [type].
  const TypeBadge({super.key, required this.type});

  /// The alert type to represent.
  final AlertType type;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool urgent = type == AlertType.urgent;
    final Color bg = urgent
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.secondaryContainer;
    final Color fg = urgent
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onSecondaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            urgent ? Icons.priority_high : Icons.info_outline,
            size: 13,
            color: fg,
          ),
          const SizedBox(width: 4),
          Text(
            urgent ? 'URGENT' : 'INLINE',
            style: theme.textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
