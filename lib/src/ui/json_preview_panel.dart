import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/admin_controller.dart';

/// A live, read-only view of the exact feed JSON that would be published,
/// plus any blocking validation issues.
class JsonPreviewPanel extends StatelessWidget {
  /// Creates the panel bound to [controller].
  const JsonPreviewPanel({super.key, required this.controller});

  /// The owning controller.
  final AdminController controller;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String json = controller.feedJson();
    final List<String> issues = controller.feedIssues;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
          child: Row(
            children: <Widget>[
              Icon(Icons.data_object,
                  size: 18, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Feed JSON', style: theme.textTheme.titleSmall),
              ),
              IconButton(
                tooltip: 'Copy JSON',
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: json));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Feed JSON copied to clipboard'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
        if (issues.isNotEmpty) _issues(theme, issues),
        const Divider(height: 1),
        Expanded(
          child: Container(
            width: double.infinity,
            color: theme.colorScheme.surfaceContainerLowest,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                json,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _issues(ThemeData theme, List<String> issues) {
    return Container(
      width: double.infinity,
      color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.report_outlined,
                  size: 16, color: theme.colorScheme.error),
              const SizedBox(width: 6),
              Text(
                '${issues.length} issue${issues.length == 1 ? '' : 's'} '
                'blocking publish',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final String issue in issues)
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 22),
              child: Text('• $issue', style: theme.textTheme.bodySmall),
            ),
        ],
      ),
    );
  }
}
