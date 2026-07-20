import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/feed_uploader.dart';
import '../state/admin_controller.dart';
import 'alert_editor_panel.dart';
import 'alert_list_panel.dart';
import 'destination_dialog.dart';
import 'json_preview_panel.dart';

/// The main admin window: master list, editor, and live JSON preview, with
/// publish and import/export actions.
class HomePage extends StatefulWidget {
  /// Creates the home page bound to [controller].
  const HomePage({super.key, required this.controller});

  /// The application controller.
  final AdminController controller;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  AdminController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, _) {
        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool showPreviewInline = constraints.maxWidth >= 1150;
            return Scaffold(
              key: _scaffoldKey,
              appBar: _appBar(context, showPreviewInline),
              endDrawer: showPreviewInline
                  ? null
                  : Drawer(
                      width: 420,
                      child: SafeArea(
                        child: JsonPreviewPanel(controller: controller),
                      ),
                    ),
              body: Column(
                children: <Widget>[
                  Expanded(child: _body(showPreviewInline)),
                  _statusBar(context),
                ],
              ),
            );
          },
        );
      },
    );
  }

  PreferredSizeWidget _appBar(BuildContext context, bool showPreviewInline) {
    final ThemeData theme = Theme.of(context);
    final String destName =
        controller.selectedDestination?.name ?? 'No destination';
    return AppBar(
      titleSpacing: 16,
      title: Row(
        children: <Widget>[
          Icon(Icons.notifications_active_outlined,
              color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Text('app_alerts admin', style: theme.textTheme.titleLarge),
        ],
      ),
      actions: <Widget>[
        // Destination selector.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: ActionChip(
            avatar: const Icon(Icons.cloud_upload_outlined, size: 18),
            label: Text(destName),
            onPressed: () => showDestinationsDialog(context, controller),
          ),
        ),
        const SizedBox(width: 8),
        // Publish.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: FilledButton.icon(
            onPressed: controller.isBusy ? null : () => _publish(context),
            icon: controller.isBusy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.publish, size: 18),
            label: const Text('Publish'),
          ),
        ),
        if (!showPreviewInline)
          IconButton(
            tooltip: 'JSON preview',
            icon: const Icon(Icons.data_object),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        PopupMenuButton<String>(
          tooltip: 'More',
          onSelected: (String value) => _onMenu(context, value),
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
              value: 'destinations',
              child: ListTile(
                leading: Icon(Icons.cloud_outlined),
                title: Text('Manage destinations…'),
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem<String>(
              value: 'import_url',
              child: ListTile(
                leading: Icon(Icons.cloud_download_outlined),
                title: Text('Import from URL…'),
              ),
            ),
            const PopupMenuItem<String>(
              value: 'import_file',
              child: ListTile(
                leading: Icon(Icons.file_open_outlined),
                title: Text('Import from file…'),
              ),
            ),
            const PopupMenuItem<String>(
              value: 'paste',
              child: ListTile(
                leading: Icon(Icons.content_paste),
                title: Text('Paste JSON…'),
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem<String>(
              value: 'export_file',
              child: ListTile(
                leading: Icon(Icons.save_alt),
                title: Text('Export to file…'),
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _body(bool showPreviewInline) {
    final ThemeData theme = Theme.of(context);
    final Widget list = _panel(
      theme,
      width: 300,
      child: AlertListPanel(controller: controller),
    );
    final Widget editor = Expanded(child: _editorArea(theme));
    final List<Widget> panes = <Widget>[list, editor];
    if (showPreviewInline) {
      panes.add(_panel(
        theme,
        width: 400,
        child: JsonPreviewPanel(controller: controller),
        leftBorder: true,
      ));
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: panes);
  }

  Widget _panel(
    ThemeData theme, {
    required double width,
    required Widget child,
    bool leftBorder = false,
  }) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        border: Border(
          right: leftBorder
              ? BorderSide.none
              : BorderSide(color: theme.colorScheme.outlineVariant),
          left: leftBorder
              ? BorderSide(color: theme.colorScheme.outlineVariant)
              : BorderSide.none,
        ),
      ),
      child: child,
    );
  }

  Widget _editorArea(ThemeData theme) {
    final selected = controller.selected;
    if (selected == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.edit_note,
                size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('Select an alert to edit', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('or add a new one from the list',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
          ],
        ),
      );
    }
    return AlertEditorPanel(
      // Key by object identity so editing the id field doesn't remount the
      // editor; switching alerts (a different object) does reset it.
      key: ValueKey<int>(identityHashCode(selected)),
      controller: controller,
      draft: selected,
    );
  }

  Widget _statusBar(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? status = controller.status;
    final DateTime? published = controller.lastPublishedAt;
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: <Widget>[
            if (status != null) ...<Widget>[
              Icon(
                controller.statusIsError
                    ? Icons.error_outline
                    : Icons.check_circle_outline,
                size: 16,
                color: controller.statusIsError
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: controller.statusIsError
                        ? theme.colorScheme.error
                        : null,
                  ),
                ),
              ),
            ] else
              Expanded(
                child: Text(
                  '${controller.alerts.length} alert'
                  '${controller.alerts.length == 1 ? '' : 's'} · autosaved '
                  'locally',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (published != null)
              Text(
                'Last published ${_time(published)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _time(DateTime dt) {
    final DateTime l = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.hour)}:${two(l.minute)}';
  }

  // --- Actions --------------------------------------------------------------

  Future<void> _publish(BuildContext context) async {
    final UploadResult result = await controller.publish();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success
            ? null
            : Theme.of(context).colorScheme.errorContainer,
      ),
    );
  }

  Future<void> _onMenu(BuildContext context, String value) async {
    switch (value) {
      case 'destinations':
        await showDestinationsDialog(context, controller);
      case 'import_url':
        await _importFromUrl(context);
      case 'import_file':
        await _importFromFile(context);
      case 'paste':
        await _pasteJson(context);
      case 'export_file':
        await _exportToFile(context);
    }
  }

  Future<bool> _confirmReplace(BuildContext context) async {
    if (controller.alerts.isEmpty) return true;
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('Replace current feed?'),
            content: Text(
              'Importing replaces the ${controller.alerts.length} alert'
              '${controller.alerts.length == 1 ? '' : 's'} you have now.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Replace'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _importFromUrl(BuildContext context) async {
    final TextEditingController field = TextEditingController(
      text: controller.selectedDestination?.url ?? '',
    );
    final String? url = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Import from URL'),
        content: TextField(
          controller: field,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Feed URL',
            hintText: 'https://…/alerts/feed.json',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, field.text.trim()),
            child: const Text('Load'),
          ),
        ],
      ),
    );
    if (url == null || url.isEmpty || !context.mounted) return;
    if (!await _confirmReplace(context)) return;
    await controller.importFromUrl(url);
  }

  Future<void> _importFromFile(BuildContext context) async {
    final FilePickerResult? picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['json'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty || !context.mounted) return;
    final PlatformFile file = picked.files.single;
    String? content;
    if (file.bytes != null) {
      content = utf8.decode(file.bytes!);
    } else if (file.path != null) {
      content = await File(file.path!).readAsString();
    }
    if (content == null || !context.mounted) return;
    if (!await _confirmReplace(context)) return;
    await controller.importJson(content);
  }

  Future<void> _pasteJson(BuildContext context) async {
    final TextEditingController field = TextEditingController();
    final String? json = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Paste feed JSON'),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: field,
            autofocus: true,
            minLines: 8,
            maxLines: 16,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
            decoration: const InputDecoration(
              hintText: '{ "version": 1, "alerts": [ … ] }',
              alignLabelWithHint: true,
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, field.text),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (json == null || json.trim().isEmpty || !context.mounted) return;
    if (!await _confirmReplace(context)) return;
    await controller.importJson(json);
  }

  Future<void> _exportToFile(BuildContext context) async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('On web, use the Copy button in the JSON preview.')),
      );
      return;
    }
    final String? path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save feed JSON',
      fileName: 'alerts.json',
      type: FileType.custom,
      allowedExtensions: <String>['json'],
    );
    if (path == null) return;
    final String finalPath =
        path.toLowerCase().endsWith('.json') ? path : '$path.json';
    await File(finalPath).writeAsString(controller.feedJson());
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved to $finalPath')),
    );
  }
}
