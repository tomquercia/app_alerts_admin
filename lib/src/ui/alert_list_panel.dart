import 'package:app_alerts/app_alerts.dart';
import 'package:flutter/material.dart';

import '../models/alert_draft.dart';
import '../state/admin_controller.dart';
import 'widgets/date_time_field.dart';
import 'widgets/type_badge.dart';

/// The master list of alerts in the feed, with add/select.
class AlertListPanel extends StatelessWidget {
  /// Creates the list bound to [controller].
  const AlertListPanel({super.key, required this.controller});

  /// The owning controller.
  final AdminController controller;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<AlertDraft> alerts = controller.alerts;
    final Set<String> duplicates = controller.duplicateIds;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Alerts (${alerts.length})',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              MenuAnchor(
                builder: (BuildContext context, MenuController menu, _) {
                  return FilledButton.tonalIcon(
                    onPressed: () => menu.isOpen ? menu.close() : menu.open(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add'),
                  );
                },
                menuChildren: <Widget>[
                  MenuItemButton(
                    leadingIcon: const Icon(Icons.priority_high),
                    onPressed: () =>
                        controller.addAlert(type: AlertType.urgent),
                    child: const Text('Urgent alert'),
                  ),
                  MenuItemButton(
                    leadingIcon: const Icon(Icons.info_outline),
                    onPressed: () =>
                        controller.addAlert(type: AlertType.inline),
                    child: const Text('Inline alert'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: alerts.isEmpty
              ? _empty(theme)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: alerts.length,
                  itemBuilder: (BuildContext context, int i) {
                    final AlertDraft d = alerts[i];
                    return _tile(
                      context,
                      d,
                      selected: d.id == controller.selectedId,
                      hasError: d.hasBlockingError ||
                          duplicates.contains(d.id.trim()),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _empty(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.notifications_off_outlined,
                size: 40, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('No alerts yet', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'Add one, or import an existing feed.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    AlertDraft d, {
    required bool selected,
    required bool hasError,
  }) {
    final ThemeData theme = Theme.of(context);
    final String title =
        d.title.trim().isEmpty ? 'Untitled alert' : d.title.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Material(
        color:
            selected ? theme.colorScheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => controller.select(d.id),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    TypeBadge(type: d.type),
                    const Spacer(),
                    if (hasError)
                      Icon(Icons.error_outline,
                          size: 16, color: theme.colorScheme.error),
                    const SizedBox(width: 6),
                    Text('P${d.priority}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        )),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _subtitle(d),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _subtitle(AlertDraft d) {
    final DateTime? exp = d.expiresAt;
    if (exp != null) {
      final bool expired = exp.isBefore(DateTime.now().toUtc());
      return expired
          ? 'Expired ${DateTimeField.formatLocal(exp)}'
          : 'Expires ${DateTimeField.formatLocal(exp)}';
    }
    return d.id;
  }
}
