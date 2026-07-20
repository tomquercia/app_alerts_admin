import 'dart:async';
import 'dart:convert';

import 'package:app_alerts/app_alerts.dart';
import 'package:flutter/foundation.dart';

import '../models/alert_draft.dart';
import '../models/upload_destination.dart';
import '../services/admin_storage.dart';
import '../services/feed_fetcher.dart';
import '../services/feed_uploader.dart';

/// The application state: the feed being edited, destinations, validation,
/// persistence, and publishing. UI listens to this [ChangeNotifier].
class AdminController extends ChangeNotifier {
  /// Creates a controller. Dependencies are injectable for tests; sensible
  /// production defaults are used otherwise.
  AdminController({
    AdminStorage? storage,
    FeedUploader? uploader,
    FeedFetcher? fetcher,
    this.autosaveDelay = const Duration(milliseconds: 800),
  })  : _storage = storage ?? AdminStorage(),
        _uploader = uploader ?? HttpFeedUploader(),
        _fetcher = fetcher ?? FeedFetcher();

  final AdminStorage _storage;
  final FeedUploader _uploader;
  final FeedFetcher _fetcher;

  /// Debounce window for autosaving edits to local storage.
  final Duration autosaveDelay;

  final List<AlertDraft> _alerts = <AlertDraft>[];
  final List<UploadDestination> _destinations = <UploadDestination>[];
  String? _selectedId;
  int _selectedDestination = 0;
  bool _loaded = false;
  bool _busy = false;
  String? _status;
  bool _statusIsError = false;
  DateTime? _lastPublishedAt;
  Timer? _saveTimer;

  // --- Read-only state ------------------------------------------------------

  /// The alerts being edited, in author order.
  List<AlertDraft> get alerts => List<AlertDraft>.unmodifiable(_alerts);

  /// Configured destinations.
  List<UploadDestination> get destinations =>
      List<UploadDestination>.unmodifiable(_destinations);

  /// Whether the initial load has completed.
  bool get isLoaded => _loaded;

  /// Whether a network operation is in flight.
  bool get isBusy => _busy;

  /// The last status message (upload/import result), or null.
  String? get status => _status;

  /// Whether [status] represents a failure (for styling).
  bool get statusIsError => _statusIsError;

  /// When the feed was last successfully published, or null.
  DateTime? get lastPublishedAt => _lastPublishedAt;

  /// The currently selected alert id.
  String? get selectedId => _selectedId;

  /// The currently selected draft, or null.
  AlertDraft? get selected {
    for (final AlertDraft d in _alerts) {
      if (d.id == _selectedId) return d;
    }
    return null;
  }

  /// Index of the selected destination.
  int get selectedDestinationIndex => _selectedDestination;

  /// The selected destination, or null when none configured/selected.
  UploadDestination? get selectedDestination {
    if (_selectedDestination < 0 ||
        _selectedDestination >= _destinations.length) {
      return null;
    }
    return _destinations[_selectedDestination];
  }

  // --- Validation -----------------------------------------------------------

  /// Ids that appear on more than one alert (a client dedupe hazard).
  Set<String> get duplicateIds {
    final Map<String, int> counts = <String, int>{};
    for (final AlertDraft d in _alerts) {
      final String id = d.id.trim();
      if (id.isEmpty) continue;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts.entries
        .where((MapEntry<String, int> e) => e.value > 1)
        .map((MapEntry<String, int> e) => e.key)
        .toSet();
  }

  /// Whether the feed can be published (no blocking errors, no duplicate ids).
  bool get isFeedValid =>
      duplicateIds.isEmpty &&
      _alerts.every((AlertDraft d) => !d.hasBlockingError);

  /// Human-readable blocking issues across the whole feed.
  List<String> get feedIssues {
    final List<String> issues = <String>[];
    for (final String id in duplicateIds) {
      issues.add('Duplicate id "$id" — ids must be unique.');
    }
    for (final AlertDraft d in _alerts) {
      final String label = d.title.trim().isEmpty ? d.id : d.title.trim();
      for (final String? e in <String?>[
        d.idError,
        d.titleError,
        d.urlError,
        d.expiresError,
      ]) {
        if (e != null) issues.add('“$label”: $e');
      }
    }
    return issues;
  }

  // --- Lifecycle ------------------------------------------------------------

  /// Loads the persisted workspace. Call once at startup.
  Future<void> load() async {
    final AdminWorkspace ws = await _storage.load();
    _alerts
      ..clear()
      ..addAll(ws.drafts);
    _destinations
      ..clear()
      ..addAll(ws.destinations);
    _selectedDestination = ws.selectedDestination;
    _selectedId = _alerts.isNotEmpty ? _alerts.first.id : null;
    _loaded = true;
    notifyListeners();
  }

  // --- Alert CRUD -----------------------------------------------------------

  /// Adds a new blank alert of [type] and selects it.
  void addAlert({AlertType type = AlertType.inline}) {
    final AlertDraft draft = AlertDraft.blank(type: type);
    _alerts.add(draft);
    _selectedId = draft.id;
    _persistNow();
    notifyListeners();
  }

  /// Duplicates the alert with [id] (or the selection) as a new alert.
  void duplicate(String id) {
    final int index = _indexOf(id);
    if (index < 0) return;
    final AlertDraft copy = _alerts[index].duplicate();
    _alerts.insert(index + 1, copy);
    _selectedId = copy.id;
    _persistNow();
    notifyListeners();
  }

  /// Deletes the alert with [id], selecting a neighbour.
  void delete(String id) {
    final int index = _indexOf(id);
    if (index < 0) return;
    _alerts.removeAt(index);
    if (_selectedId == id) {
      _selectedId = _alerts.isEmpty
          ? null
          : _alerts[index.clamp(0, _alerts.length - 1)].id;
    }
    _persistNow();
    notifyListeners();
  }

  /// Selects the alert with [id] (or clears selection with null).
  void select(String? id) {
    if (_selectedId == id) return;
    _selectedId = id;
    notifyListeners();
  }

  /// Applies [mutate] to the selected draft, then notifies and autosaves.
  ///
  /// The single write path for the editor: keeps live preview in sync and
  /// debounces disk writes so per-keystroke edits don't thrash storage.
  void editSelected(void Function(AlertDraft draft) mutate) {
    final AlertDraft? draft = selected;
    if (draft == null) return;
    mutate(draft);
    // Keep the selection attached to this alert even if the mutation changed
    // its id (the id field is editable).
    _selectedId = draft.id;
    _persistDebounced();
    notifyListeners();
  }

  int _indexOf(String id) => _alerts.indexWhere((AlertDraft d) => d.id == id);

  // --- Serialization --------------------------------------------------------

  /// The feed JSON that would be published — pretty-printed. Alerts with
  /// blocking errors are omitted so the preview always renders.
  String feedJson() {
    final List<Alert> valid = _alerts
        .where((AlertDraft d) => !d.hasBlockingError)
        .map((AlertDraft d) => d.toAlert())
        .toList();
    final AlertFeed feed = AlertFeed(alerts: valid);
    return const JsonEncoder.withIndent('  ').convert(feed.toJson());
  }

  // --- Import ---------------------------------------------------------------

  /// Replaces the current feed with the alerts parsed from [json].
  Future<bool> importJson(String json) async {
    try {
      final AlertFeed feed = AlertFeed.parse(json);
      _alerts
        ..clear()
        ..addAll(feed.alerts.map(AlertDraft.fromAlert));
      _selectedId = _alerts.isNotEmpty ? _alerts.first.id : null;
      _persistNow();
      final String malformed = feed.malformedCount > 0
          ? ' (${feed.malformedCount} malformed entr'
              '${feed.malformedCount == 1 ? 'y' : 'ies'} skipped)'
          : '';
      _setStatus('Imported ${feed.alerts.length} alert'
          '${feed.alerts.length == 1 ? '' : 's'}$malformed.');
      return true;
    } on FormatException catch (e) {
      _setStatus('Import failed: ${e.message}', isError: true);
      return false;
    }
  }

  /// Loads and imports the feed currently at [url].
  Future<bool> importFromUrl(String url) async {
    _setBusy(true);
    try {
      final String body = await _fetcher.fetch(url);
      return await importJson(body);
    } on FeedFetchException catch (e) {
      _setStatus(e.message, isError: true);
      return false;
    } finally {
      _setBusy(false);
    }
  }

  // --- Destinations ---------------------------------------------------------

  /// Adds [destination] and selects it.
  void addDestination(UploadDestination destination) {
    _destinations.add(destination);
    _selectedDestination = _destinations.length - 1;
    _persistNow();
    notifyListeners();
  }

  /// Replaces the destination at [index].
  void updateDestination(int index, UploadDestination destination) {
    if (index < 0 || index >= _destinations.length) return;
    _destinations[index] = destination;
    _persistNow();
    notifyListeners();
  }

  /// Removes the destination at [index].
  void removeDestination(int index) {
    if (index < 0 || index >= _destinations.length) return;
    _destinations.removeAt(index);
    if (_selectedDestination >= _destinations.length) {
      _selectedDestination =
          _destinations.isEmpty ? 0 : _destinations.length - 1;
    }
    _persistNow();
    notifyListeners();
  }

  /// Selects the destination at [index].
  void selectDestination(int index) {
    if (index < 0 || index >= _destinations.length) return;
    _selectedDestination = index;
    _persistNow();
    notifyListeners();
  }

  // --- Publish --------------------------------------------------------------

  /// Publishes the feed to the selected destination.
  Future<UploadResult> publish() async {
    final UploadDestination? dest = selectedDestination;
    if (dest == null || !dest.isComplete) {
      const UploadResult result = UploadResult(
          success: false,
          message: 'Configure a destination with a valid URL first.');
      _setStatus(result.message, isError: true);
      return result;
    }
    if (!isFeedValid) {
      final int n = feedIssues.length;
      final UploadResult result = UploadResult(
          success: false,
          message: 'Fix $n issue${n == 1 ? '' : 's'} before publishing.');
      _setStatus(result.message, isError: true);
      return result;
    }

    _setBusy(true);
    try {
      final UploadResult result =
          await _uploader.upload(destination: dest, body: feedJson());
      if (result.success) _lastPublishedAt = DateTime.now();
      _setStatus(result.message, isError: !result.success);
      return result;
    } finally {
      _setBusy(false);
    }
  }

  // --- Internals ------------------------------------------------------------

  void _setBusy(bool value) {
    _busy = value;
    notifyListeners();
  }

  void _setStatus(String message, {bool isError = false}) {
    _status = message;
    _statusIsError = isError;
    notifyListeners();
  }

  void _persistDebounced() {
    _saveTimer?.cancel();
    _saveTimer = Timer(autosaveDelay, _persistNow);
  }

  void _persistNow() {
    _saveTimer?.cancel();
    // Fire-and-forget; storage is best-effort and never blocks the UI.
    unawaited(_storage.save(AdminWorkspace(
      drafts: List<AlertDraft>.of(_alerts),
      destinations: List<UploadDestination>.of(_destinations),
      selectedDestination: _selectedDestination,
    )));
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}
