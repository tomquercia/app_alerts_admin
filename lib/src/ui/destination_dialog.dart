import 'package:flutter/material.dart';

import '../models/destination_auth.dart';
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
                            '${d.method.verb} · ${d.auth.summary} · ${d.url}',
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

enum _AuthKind { none, bearer, basic, netStorage }

class _DestinationEditorDialogState extends State<_DestinationEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _url;
  late final TextEditingController _contentType;
  late UploadMethod _method;
  late final List<_HeaderRow> _headers;

  late _AuthKind _authKind;
  late final TextEditingController _bearerToken;
  late final TextEditingController _basicUser;
  late final TextEditingController _basicPass;
  late final TextEditingController _nsKeyName;
  late final TextEditingController _nsKey;

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

    // Seed the auth fields from the destination's current scheme.
    final DestinationAuth auth = widget.initial.auth;
    _authKind = switch (auth) {
      NoAuth() => _AuthKind.none,
      BearerAuth() => _AuthKind.bearer,
      BasicAuth() => _AuthKind.basic,
      NetStorageAuth() => _AuthKind.netStorage,
    };
    _bearerToken =
        TextEditingController(text: auth is BearerAuth ? auth.token : '');
    _basicUser =
        TextEditingController(text: auth is BasicAuth ? auth.username : '');
    _basicPass =
        TextEditingController(text: auth is BasicAuth ? auth.password : '');
    _nsKeyName =
        TextEditingController(text: auth is NetStorageAuth ? auth.keyName : '');
    _nsKey =
        TextEditingController(text: auth is NetStorageAuth ? auth.key : '');
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
    _bearerToken.dispose();
    _basicUser.dispose();
    _basicPass.dispose();
    _nsKeyName.dispose();
    _nsKey.dispose();
    super.dispose();
  }

  DestinationAuth _buildAuth() {
    return switch (_authKind) {
      _AuthKind.none => const NoAuth(),
      _AuthKind.bearer => BearerAuth(token: _bearerToken.text.trim()),
      _AuthKind.basic => BasicAuth(
          username: _basicUser.text.trim(),
          password: _basicPass.text,
        ),
      _AuthKind.netStorage => NetStorageAuth(
          keyName: _nsKeyName.text.trim(),
          key: _nsKey.text.trim(),
        ),
    };
  }

  List<Widget> _authFields(ThemeData theme) {
    switch (_authKind) {
      case _AuthKind.none:
        return const <Widget>[];
      case _AuthKind.bearer:
        return <Widget>[
          const SizedBox(height: 12),
          TextField(
            controller: _bearerToken,
            decoration: const InputDecoration(
              labelText: 'Token',
              hintText: 'Sent as: Authorization: Bearer …',
            ),
            obscureText: true,
          ),
        ];
      case _AuthKind.basic:
        return <Widget>[
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _basicUser,
                  decoration: const InputDecoration(labelText: 'Username'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _basicPass,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                ),
              ),
            ],
          ),
        ];
      case _AuthKind.netStorage:
        return <Widget>[
          const SizedBox(height: 12),
          TextField(
            controller: _nsKeyName,
            decoration: const InputDecoration(
              labelText: 'Key name (id)',
              hintText: 'NetStorage upload account key name',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nsKey,
            decoration: const InputDecoration(
              labelText: 'Key',
              hintText: 'Upload account secret key',
            ),
            obscureText: true,
          ),
          const SizedBox(height: 6),
          Text(
            'Requests are signed with HMAC-SHA256 into X-Akamai-ACS-* headers. '
            'For other schemes, inject a custom UploadAuthorizer in code.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ];
    }
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
        auth: _buildAuth(),
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
              Text('Authentication', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              DropdownButtonFormField<_AuthKind>(
                initialValue: _authKind,
                decoration: const InputDecoration(labelText: 'Scheme'),
                items: const <DropdownMenuItem<_AuthKind>>[
                  DropdownMenuItem<_AuthKind>(
                      value: _AuthKind.none,
                      child: Text('None (headers only)')),
                  DropdownMenuItem<_AuthKind>(
                      value: _AuthKind.bearer, child: Text('Bearer token')),
                  DropdownMenuItem<_AuthKind>(
                      value: _AuthKind.basic,
                      child: Text('Basic (user / pass)')),
                  DropdownMenuItem<_AuthKind>(
                      value: _AuthKind.netStorage,
                      child: Text('Akamai NetStorage (HMAC)')),
                ],
                onChanged: (_AuthKind? v) =>
                    setState(() => _authKind = v ?? _AuthKind.none),
              ),
              ..._authFields(theme),
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
                'Extra headers sent with every upload, composed on top of the '
                'auth scheme above.',
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
