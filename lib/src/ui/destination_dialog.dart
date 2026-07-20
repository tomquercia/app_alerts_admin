import 'package:flutter/material.dart';

import '../models/upload_destination.dart';
import '../state/admin_controller.dart';

/// Opens the destinations manager.
Future<void> showDestinationsDialog(
  BuildContext context,
  AdminController controller,
) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: _DestinationsManager(controller: controller),
      ),
    ),
  );
}

class _DestinationsManager extends StatelessWidget {
  const _DestinationsManager({required this.controller});

  final AdminController controller;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, _) {
        final List<UploadDestination> dests = controller.destinations;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text('Upload destinations',
                        style: theme.textTheme.titleLarge),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Flexible(
              child: dests.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'No destinations yet. Add one — a NetStorage URL, an '
                        'S3/GCS presigned URL, or any endpoint that accepts a '
                        'PUT/POST of the feed.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: dests.length,
                      itemBuilder: (BuildContext context, int i) {
                        final UploadDestination d = dests[i];
                        final bool selected =
                            controller.selectedDestinationIndex == i;
                        return ListTile(
                          onTap: () => controller.selectDestination(i),
                          leading: Icon(
                            selected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: selected ? theme.colorScheme.primary : null,
                          ),
                          title: Text(d.name),
                          subtitle: Text(
                            '${d.method.verb}  ${d.url}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              IconButton(
                                tooltip: 'Edit',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () async {
                                  final UploadDestination? edited =
                                      await _editDestination(context, d);
                                  if (edited != null) {
                                    controller.updateDestination(i, edited);
                                  }
                                },
                              ),
                              IconButton(
                                tooltip: 'Remove',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () =>
                                    controller.removeDestination(i),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () async {
                    final UploadDestination? created = await _editDestination(
                      context,
                      const UploadDestination(name: '', url: ''),
                    );
                    if (created != null) controller.addDestination(created);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add destination'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<UploadDestination?> _editDestination(
    BuildContext context,
    UploadDestination initial,
  ) {
    return showDialog<UploadDestination>(
      context: context,
      builder: (BuildContext context) =>
          _DestinationEditorDialog(initial: initial),
    );
  }
}

class _DestinationEditorDialog extends StatefulWidget {
  const _DestinationEditorDialog({required this.initial});

  final UploadDestination initial;

  @override
  State<_DestinationEditorDialog> createState() =>
      _DestinationEditorDialogState();
}

class _HeaderRow {
  _HeaderRow(this.key, this.value);
  final TextEditingController key;
  final TextEditingController value;
}

class _DestinationEditorDialogState extends State<_DestinationEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _url;
  late final TextEditingController _contentType;
  late UploadMethod _method;
  late final List<_HeaderRow> _headers;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial.name);
    _url = TextEditingController(text: widget.initial.url);
    _contentType = TextEditingController(text: widget.initial.contentType);
    _method = widget.initial.method;
    _headers = widget.initial.headers.entries
        .map((MapEntry<String, String> e) => _HeaderRow(
              TextEditingController(text: e.key),
              TextEditingController(text: e.value),
            ))
        .toList();
  }

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _contentType.dispose();
    for (final _HeaderRow h in _headers) {
      h.key.dispose();
      h.value.dispose();
    }
    super.dispose();
  }

  bool get _valid {
    final Uri? uri = Uri.tryParse(_url.text.trim());
    return _name.text.trim().isNotEmpty &&
        _url.text.trim().isNotEmpty &&
        uri != null &&
        uri.hasScheme;
  }

  void _save() {
    final Map<String, String> headers = <String, String>{};
    for (final _HeaderRow h in _headers) {
      final String k = h.key.text.trim();
      if (k.isNotEmpty) headers[k] = h.value.text;
    }
    Navigator.pop(
      context,
      UploadDestination(
        name: _name.text.trim(),
        url: _url.text.trim(),
        method: _method,
        contentType: _contentType.text.trim().isEmpty
            ? 'application/json'
            : _contentType.text.trim(),
        headers: headers,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AlertDialog(
      title: Text(
          widget.initial.url.isEmpty ? 'Add destination' : 'Edit destination'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  hintText: 'e.g. Production NetStorage',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _url,
                decoration: const InputDecoration(
                  labelText: 'URL *',
                  hintText: 'https://…/alerts/feed.json',
                  prefixIcon: Icon(Icons.link),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  SegmentedButton<UploadMethod>(
                    segments: const <ButtonSegment<UploadMethod>>[
                      ButtonSegment<UploadMethod>(
                          value: UploadMethod.put, label: Text('PUT')),
                      ButtonSegment<UploadMethod>(
                          value: UploadMethod.post, label: Text('POST')),
                    ],
                    selected: <UploadMethod>{_method},
                    onSelectionChanged: (Set<UploadMethod> s) =>
                        setState(() => _method = s.first),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _contentType,
                      decoration: const InputDecoration(
                        labelText: 'Content-Type',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text('Headers', style: theme.textTheme.titleSmall),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() => _headers.add(_HeaderRow(
                        TextEditingController(), TextEditingController()))),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add header'),
                  ),
                ],
              ),
              Text(
                'For authentication — e.g. Authorization, or NetStorage’s '
                'X-Akamai-ACS-* headers.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              for (int i = 0; i < _headers.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _headers[i].key,
                          decoration:
                              const InputDecoration(labelText: 'Header'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _headers[i].value,
                          decoration: const InputDecoration(labelText: 'Value'),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () {
                          setState(() {
                            _headers[i].key.dispose();
                            _headers[i].value.dispose();
                            _headers.removeAt(i);
                          });
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _valid ? _save : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
