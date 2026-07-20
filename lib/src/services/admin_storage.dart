import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/alert_draft.dart';
import '../models/upload_destination.dart';

/// The persisted admin workspace: the in-progress feed plus configured
/// destinations and which one is selected.
class AdminWorkspace {
  /// Creates a workspace snapshot.
  const AdminWorkspace({
    required this.drafts,
    required this.destinations,
    required this.selectedDestination,
  });

  /// An empty workspace (first run).
  static const AdminWorkspace empty = AdminWorkspace(
    drafts: <AlertDraft>[],
    destinations: <UploadDestination>[],
    selectedDestination: 0,
  );

  /// The alerts being edited, in author-defined order.
  final List<AlertDraft> drafts;

  /// Configured upload destinations.
  final List<UploadDestination> destinations;

  /// Index of the selected destination in [destinations].
  final int selectedDestination;
}

/// Persists the [AdminWorkspace] locally so nothing is lost between sessions.
///
/// Uses the platform application-support directory via `path_provider`.
/// Persistence is best-effort: on platforms without a filesystem (web) or on
/// any I/O error, load/save degrade to no-ops so the app stays usable.
class AdminStorage {
  /// Creates storage. [directoryOverride] lets tests point at a temp dir.
  AdminStorage({Directory? directoryOverride}) : _override = directoryOverride;

  final Directory? _override;

  static const String _fileName = 'workspace.json';

  Future<File?> _file() async {
    try {
      final Directory dir = _override ?? await getApplicationSupportDirectory();
      return File('${dir.path}${Platform.pathSeparator}$_fileName');
    } on Exception {
      return null; // Unsupported platform (e.g. web) — degrade gracefully.
    } on Error {
      return null;
    }
  }

  /// Loads the saved workspace, or [AdminWorkspace.empty] if none/unreadable.
  Future<AdminWorkspace> load() async {
    try {
      final File? file = await _file();
      if (file == null || !await file.exists()) return AdminWorkspace.empty;
      final Object? decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return AdminWorkspace.empty;

      final Object? rawDrafts = decoded['drafts'];
      final Object? rawDests = decoded['destinations'];
      final List<AlertDraft> drafts = rawDrafts is List
          ? rawDrafts
              .whereType<Map<Object?, Object?>>()
              .map((Map<Object?, Object?> e) => AlertDraft.fromStorageJson(
                  e.map((Object? k, Object? v) =>
                      MapEntry<String, Object?>(k.toString(), v))))
              .toList()
          : <AlertDraft>[];
      final List<UploadDestination> destinations = rawDests is List
          ? rawDests
              .whereType<Map<Object?, Object?>>()
              .map((Map<Object?, Object?> e) => UploadDestination.fromJson(
                  e.map((Object? k, Object? v) =>
                      MapEntry<String, Object?>(k.toString(), v))))
              .toList()
          : <UploadDestination>[];
      return AdminWorkspace(
        drafts: drafts,
        destinations: destinations,
        selectedDestination:
            (decoded['selectedDestination'] as num?)?.toInt() ?? 0,
      );
    } on Exception {
      return AdminWorkspace.empty;
    }
  }

  /// Saves the workspace. Silently no-ops if the platform has no filesystem.
  Future<void> save(AdminWorkspace workspace) async {
    try {
      final File? file = await _file();
      if (file == null) return;
      final Map<String, Object?> json = <String, Object?>{
        'drafts':
            workspace.drafts.map((AlertDraft d) => d.toStorageJson()).toList(),
        'destinations': workspace.destinations
            .map((UploadDestination d) => d.toJson())
            .toList(),
        'selectedDestination': workspace.selectedDestination,
      };
      await file
          .writeAsString(const JsonEncoder.withIndent('  ').convert(json));
    } on Exception {
      // Best-effort; losing autosave is not worth crashing the app.
    }
  }
}
