import 'package:app_alerts/app_alerts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/alert_draft.dart';
import '../state/admin_controller.dart';
import 'widgets/date_time_field.dart';
import 'widgets/metadata_editor.dart';
import 'widgets/section_card.dart';
import 'widgets/type_badge.dart';

/// The editor for a single alert — one field per JSON-contract property.
///
/// Stateful and expected to be keyed by the alert id by its parent, so its
/// text controllers reset when a different alert is selected.
class AlertEditorPanel extends StatefulWidget {
  /// Creates the editor for [draft], writing changes through [controller].
  const AlertEditorPanel({
    super.key,
    required this.controller,
    required this.draft,
  });

  /// The owning controller (edits route through it for autosave).
  final AdminController controller;

  /// The alert being edited.
  final AlertDraft draft;

  @override
  State<AlertEditorPanel> createState() => _AlertEditorPanelState();
}

class _AlertEditorPanelState extends State<AlertEditorPanel> {
  late final TextEditingController _id;
  late final TextEditingController _title;
  late final TextEditingController _message;
  late final TextEditingController _okLabel;
  late final TextEditingController _url;
  late final TextEditingController _goLabel;
  late final TextEditingController _priority;

  @override
  void initState() {
    super.initState();
    final AlertDraft d = widget.draft;
    _id = TextEditingController(text: d.id);
    _title = TextEditingController(text: d.title);
    _message = TextEditingController(text: d.message);
    _okLabel = TextEditingController(text: d.okLabel);
    _url = TextEditingController(text: d.url);
    _goLabel = TextEditingController(text: d.goLabel);
    _priority = TextEditingController(text: d.priority.toString());
  }

  @override
  void dispose() {
    _id.dispose();
    _title.dispose();
    _message.dispose();
    _okLabel.dispose();
    _url.dispose();
    _goLabel.dispose();
    _priority.dispose();
    super.dispose();
  }

  void _edit(void Function(AlertDraft d) mutate) =>
      widget.controller.editSelected(mutate);

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AlertDraft d = widget.draft;
    final bool idDuplicate =
        widget.controller.duplicateIds.contains(d.id.trim());

    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        _header(theme, d),
        const SizedBox(height: 16),
        if (d.warnings.isNotEmpty) ...<Widget>[
          _warnings(theme, d.warnings),
          const SizedBox(height: 16),
        ],

        // Type & priority.
        SectionCard(
          title: 'Type & priority',
          subtitle:
              'Urgent shows a blocking pop-up; inline is handed to the app. '
              'Lower priority number is shown first.',
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: SegmentedButton<AlertType>(
                  segments: const <ButtonSegment<AlertType>>[
                    ButtonSegment<AlertType>(
                      value: AlertType.urgent,
                      icon: Icon(Icons.priority_high),
                      label: Text('Urgent'),
                    ),
                    ButtonSegment<AlertType>(
                      value: AlertType.inline,
                      icon: Icon(Icons.info_outline),
                      label: Text('Inline'),
                    ),
                  ],
                  selected: <AlertType>{d.type},
                  onSelectionChanged: (Set<AlertType> s) =>
                      _edit((AlertDraft d) => d.type = s.first),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 150,
                child: _priorityField(d),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Content.
        SectionCard(
          title: 'Content',
          child: Column(
            children: <Widget>[
              TextField(
                controller: _title,
                decoration: InputDecoration(
                  labelText: 'Title *',
                  hintText: 'Short headline',
                  errorText: d.titleError,
                ),
                textInputAction: TextInputAction.next,
                onChanged: (String v) => _edit((AlertDraft d) => d.title = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _message,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  hintText: 'Body text',
                  alignLabelWithHint: true,
                ),
                minLines: 3,
                maxLines: 6,
                onChanged: (String v) => _edit((AlertDraft d) => d.message = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Link & buttons.
        SectionCard(
          title: 'Link & buttons',
          subtitle:
              'A URL gives urgent alerts a “Go” button; inline alerts receive '
              'it to use as they like. Deep links (myapp://…) are allowed.',
          child: Column(
            children: <Widget>[
              TextField(
                controller: _url,
                decoration: InputDecoration(
                  labelText: 'URL / deep link',
                  hintText: 'https://…  or  myapp://path',
                  errorText: d.urlError,
                  prefixIcon: const Icon(Icons.link),
                ),
                onChanged: (String v) => _edit((AlertDraft d) => d.url = v),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _goLabel,
                      decoration: const InputDecoration(
                        labelText: 'Go button label',
                        hintText: 'Go',
                      ),
                      onChanged: (String v) =>
                          _edit((AlertDraft d) => d.goLabel = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _okLabel,
                      decoration: const InputDecoration(
                        labelText: 'OK / dismiss label',
                        hintText: 'OK',
                      ),
                      onChanged: (String v) =>
                          _edit((AlertDraft d) => d.okLabel = v),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Scheduling.
        SectionCard(
          title: 'Scheduling',
          subtitle: 'Timestamps are stored in UTC; shown here in local time.',
          child: Column(
            children: <Widget>[
              DateTimeField(
                label: 'Created at',
                value: d.createdAt,
                helperText: 'Tie-breaker for equal priority (oldest first).',
                onChanged: (DateTime? v) =>
                    _edit((AlertDraft d) => d.createdAt = v),
              ),
              const SizedBox(height: 12),
              DateTimeField(
                label: 'Expires at',
                value: d.expiresAt,
                helperText: 'After this the alert is dropped and never shown.',
                onChanged: (DateTime? v) =>
                    _edit((AlertDraft d) => d.expiresAt = v),
              ),
              if (d.expiresError != null) ...<Widget>[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    d.expiresError!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Metadata.
        SectionCard(
          title: 'Metadata',
          child: MetadataEditor(
            // Reset rows when switching alerts.
            key: ValueKey<String>('meta-${_stableKey(d)}'),
            entries: d.metadata,
            onChanged: () => _edit((_) {}),
          ),
        ),
        const SizedBox(height: 16),

        // Identifier.
        SectionCard(
          title: 'Identifier',
          subtitle:
              'Stable, unique id. The client dedupes on it — reusing an id '
              'never re-prompts a user; a new id re-prompts.',
          child: TextField(
            controller: _id,
            decoration: InputDecoration(
              labelText: 'ID *',
              prefixIcon: const Icon(Icons.tag),
              errorText: d.idError ??
                  (idDuplicate ? 'This id is used by another alert' : null),
            ),
            onChanged: (String v) => _edit((AlertDraft d) => d.id = v),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  // The metadata editor is keyed by the alert id so it resets on selection;
  // within one alert the key must stay constant.
  String _stableKey(AlertDraft d) => identityHashCode(d).toString();

  Widget _header(ThemeData theme, AlertDraft d) {
    return Row(
      children: <Widget>[
        TypeBadge(type: d.type),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            d.title.trim().isEmpty ? 'Untitled alert' : d.title.trim(),
            style: theme.textTheme.titleLarge,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          tooltip: 'Duplicate',
          icon: const Icon(Icons.copy_all_outlined),
          onPressed: () => widget.controller.duplicate(d.id),
        ),
        IconButton(
          tooltip: 'Delete',
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _confirmDelete(d),
        ),
      ],
    );
  }

  Widget _priorityField(AlertDraft d) {
    return TextField(
      controller: _priority,
      decoration: InputDecoration(
        labelText: 'Priority',
        prefixIcon: IconButton(
          tooltip: 'Higher priority',
          icon: const Icon(Icons.keyboard_arrow_up),
          onPressed: () => _bumpPriority(-1),
        ),
        suffixIcon: IconButton(
          tooltip: 'Lower priority',
          icon: const Icon(Icons.keyboard_arrow_down),
          onPressed: () => _bumpPriority(1),
        ),
      ),
      keyboardType: TextInputType.number,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
      ],
      textAlign: TextAlign.center,
      onChanged: (String v) {
        final int? parsed = int.tryParse(v);
        if (parsed != null) _edit((AlertDraft d) => d.priority = parsed);
      },
    );
  }

  void _bumpPriority(int delta) {
    final int next = widget.draft.priority + delta;
    _priority.text = next.toString();
    _edit((AlertDraft d) => d.priority = next);
  }

  Widget _warnings(ThemeData theme, List<String> warnings) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final String w in warnings)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(Icons.info_outline, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(w, style: theme.textTheme.bodySmall)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(AlertDraft d) async {
    final bool ok = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('Delete alert?'),
            content: Text(
              'Delete “${d.title.trim().isEmpty ? d.id : d.title.trim()}”? '
              'This cannot be undone.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (ok) widget.controller.delete(d.id);
  }
}
