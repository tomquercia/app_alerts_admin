import 'package:flutter/material.dart';

import '../../models/metadata_entry.dart';

/// Edits an alert's `metadata` as a list of key/value rows.
///
/// Mutates [entries] in place and calls [onChanged] so the owning controller
/// can autosave. Give this widget (or its ancestor) a key tied to the alert
/// id so its per-row text controllers reset when a different alert is
/// selected.
class MetadataEditor extends StatefulWidget {
  /// Creates the editor over [entries].
  const MetadataEditor({
    super.key,
    required this.entries,
    required this.onChanged,
  });

  /// The rows to edit (mutated in place).
  final List<MetadataEntry> entries;

  /// Called after any add/remove/edit.
  final VoidCallback onChanged;

  @override
  State<MetadataEditor> createState() => _MetadataEditorState();
}

class _MetadataEditorState extends State<MetadataEditor> {
  late final List<TextEditingController> _keyCtrls;
  late final List<TextEditingController> _valCtrls;

  @override
  void initState() {
    super.initState();
    _keyCtrls = widget.entries
        .map((MetadataEntry e) => TextEditingController(text: e.key))
        .toList();
    _valCtrls = widget.entries
        .map((MetadataEntry e) => TextEditingController(text: e.value))
        .toList();
  }

  @override
  void dispose() {
    for (final TextEditingController c in _keyCtrls) {
      c.dispose();
    }
    for (final TextEditingController c in _valCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _add() {
    setState(() {
      widget.entries.add(MetadataEntry());
      _keyCtrls.add(TextEditingController());
      _valCtrls.add(TextEditingController());
    });
    widget.onChanged();
  }

  void _remove(int index) {
    setState(() {
      widget.entries.removeAt(index);
      _keyCtrls.removeAt(index).dispose();
      _valCtrls.removeAt(index).dispose();
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (widget.entries.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'No metadata. Add key/value pairs to pass through to the app '
              '(links, categories, flags).',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        for (int i = 0; i < widget.entries.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _keyCtrls[i],
                    decoration: const InputDecoration(labelText: 'Key'),
                    onChanged: (String v) {
                      widget.entries[i].key = v;
                      widget.onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _valCtrls[i],
                    decoration: const InputDecoration(labelText: 'Value'),
                    onChanged: (String v) {
                      widget.entries[i].value = v;
                      widget.onChanged();
                    },
                  ),
                ),
                IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => _remove(i),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _add,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add metadata'),
          ),
        ),
      ],
    );
  }
}
