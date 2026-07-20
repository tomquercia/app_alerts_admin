import 'package:app_alerts/app_alerts.dart';

import 'metadata_entry.dart';

/// A mutable, editable representation of one [Alert].
///
/// The published `app_alerts` [Alert] is immutable and validated — perfect as
/// the serialization target, awkward as form state. [AlertDraft] holds the
/// same fields as plain mutable strings/values for editing, exposes per-field
/// validation, and converts to/from [Alert] so the JSON this admin emits is
/// exactly what the client consumes.
class AlertDraft {
  /// Creates a draft. Prefer [AlertDraft.blank] for new alerts and
  /// [AlertDraft.fromAlert] when importing an existing feed.
  AlertDraft({
    required this.id,
    this.type = AlertType.inline,
    this.priority = 100,
    this.title = '',
    this.message = '',
    this.okLabel = '',
    this.url = '',
    this.goLabel = '',
    this.createdAt,
    this.expiresAt,
    List<MetadataEntry>? metadata,
  }) : metadata = metadata ?? <MetadataEntry>[];

  /// Stable, unique identifier — the client's deduplication key.
  String id;

  /// Whether the alert is an urgent pop-up or an inline banner.
  AlertType type;

  /// Backend ordering; lower is presented first.
  int priority;

  /// Headline (required).
  String title;

  /// Body text.
  String message;

  /// Optional acknowledge/dismiss button label.
  String okLabel;

  /// Optional URL or deep link; blank means none.
  String url;

  /// Optional label for the urgent *Go* button (only meaningful with [url]).
  String goLabel;

  /// When the alert was authored; used as a priority tie-breaker.
  DateTime? createdAt;

  /// When the alert should stop being shown; null means never expires.
  DateTime? expiresAt;

  /// Free-form metadata rows.
  List<MetadataEntry> metadata;

  /// A blank draft with a generated unique [id] and `createdAt` set to now.
  factory AlertDraft.blank({AlertType type = AlertType.inline}) {
    return AlertDraft(
      id: _generateId(),
      type: type,
      priority: 100,
      createdAt: DateTime.now().toUtc(),
    );
  }

  /// Builds a draft from a parsed [Alert] (feed import path).
  factory AlertDraft.fromAlert(Alert alert) {
    return AlertDraft(
      id: alert.id,
      type: alert.type,
      priority: alert.priority,
      title: alert.title,
      message: alert.message,
      okLabel: alert.okLabel ?? '',
      url: alert.url?.toString() ?? '',
      goLabel: alert.goLabel ?? '',
      createdAt: alert.createdAt,
      expiresAt: alert.expiresAt,
      metadata: alert.metadata.entries
          .map((MapEntry<String, Object?> e) =>
              MetadataEntry(key: e.key, value: e.value?.toString() ?? ''))
          .toList(),
    );
  }

  /// A duplicate with a fresh [id] and " (copy)" appended to the title, so it
  /// is a genuinely new alert the client will present anew.
  AlertDraft duplicate() {
    return AlertDraft(
      id: _generateId(),
      type: type,
      priority: priority,
      title: title.isEmpty ? '' : '$title (copy)',
      message: message,
      okLabel: okLabel,
      url: url,
      goLabel: goLabel,
      createdAt: DateTime.now().toUtc(),
      expiresAt: expiresAt,
      metadata: metadata.map((MetadataEntry e) => e.copy()).toList(),
    );
  }

  // --- Validation -----------------------------------------------------------

  /// Error for the id field considered in isolation ([null] if valid).
  /// Uniqueness is enforced by the controller, which sees the whole feed.
  String? get idError => id.trim().isEmpty ? 'ID is required' : null;

  /// Error for the title field.
  String? get titleError => title.trim().isEmpty ? 'Title is required' : null;

  /// Error for the URL field ([null] when blank or a valid absolute URI).
  String? get urlError {
    final String trimmed = url.trim();
    if (trimmed.isEmpty) return null;
    final Uri? parsed = Uri.tryParse(trimmed);
    if (parsed == null || !parsed.hasScheme) {
      return 'Include a scheme, e.g. https://… or myapp://…';
    }
    return null;
  }

  /// Error when the expiry is not strictly after the created time.
  String? get expiresError {
    final DateTime? created = createdAt;
    final DateTime? expires = expiresAt;
    if (created != null && expires != null && !expires.isAfter(created)) {
      return 'Expiry must be after the created time';
    }
    return null;
  }

  /// Non-blocking advisories worth surfacing to the author.
  List<String> get warnings {
    final List<String> out = <String>[];
    if (goLabel.trim().isNotEmpty && url.trim().isEmpty) {
      out.add('“Go” label is set but there is no URL for it to open.');
    }
    if (type == AlertType.urgent && message.trim().isEmpty) {
      out.add('Urgent alerts read better with a message, not just a title.');
    }
    if (expiresAt != null &&
        expiresAt!.isBefore(DateTime.now().toUtc()) &&
        expiresError == null) {
      out.add('This alert is already expired and will not be shown.');
    }
    return out;
  }

  /// Whether the draft has any field-level error that blocks serialization.
  bool get hasBlockingError =>
      idError != null ||
      titleError != null ||
      urlError != null ||
      expiresError != null;

  // --- Serialization --------------------------------------------------------

  /// Converts to an immutable [Alert].
  ///
  /// Must only be called when [hasBlockingError] is false; callers gate on
  /// validity first. The URL is included only when it parses to an absolute
  /// URI, mirroring the client's own tolerance.
  Alert toAlert() {
    final String trimmedUrl = url.trim();
    Uri? uri;
    if (trimmedUrl.isNotEmpty) {
      final Uri? parsed = Uri.tryParse(trimmedUrl);
      if (parsed != null && parsed.hasScheme) uri = parsed;
    }
    final Map<String, Object?> meta = <String, Object?>{};
    for (final MetadataEntry entry in metadata) {
      final String key = entry.key.trim();
      if (key.isNotEmpty) meta[key] = entry.value;
    }
    return Alert(
      id: id.trim(),
      title: title.trim(),
      message: message.trim(),
      type: type,
      priority: priority,
      okLabel: _nullIfBlank(okLabel),
      url: uri,
      goLabel: _nullIfBlank(goLabel),
      createdAt: createdAt,
      expiresAt: expiresAt,
      metadata: meta,
    );
  }

  static String? _nullIfBlank(String value) {
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static int _idCounter = 0;

  // Timestamp plus a monotonic counter so ids stay unique even when several
  // are generated within the same microsecond (rapid add/duplicate).
  static String _generateId() {
    final String time = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final String seq = (_idCounter++).toRadixString(36);
    return 'alert-$time-$seq';
  }

  // --- Local persistence (lossless) ----------------------------------------
  //
  // Distinct from [toAlert]: autosave must round-trip in-progress drafts that
  // are not yet valid (blank title, half-typed URL), which the validated
  // [Alert] cannot represent.

  /// Serializes every raw field for local autosave.
  Map<String, Object?> toStorageJson() => <String, Object?>{
        'id': id,
        'type': type.wireName,
        'priority': priority,
        'title': title,
        'message': message,
        'okLabel': okLabel,
        'url': url,
        'goLabel': goLabel,
        'createdAt': createdAt?.toIso8601String(),
        'expiresAt': expiresAt?.toIso8601String(),
        'metadata': metadata
            .map((MetadataEntry e) =>
                <String, String>{'key': e.key, 'value': e.value})
            .toList(),
      };

  /// Restores a draft saved by [toStorageJson], tolerating missing fields.
  factory AlertDraft.fromStorageJson(Map<String, Object?> json) {
    final Object? rawMeta = json['metadata'];
    return AlertDraft(
      id: (json['id'] as String?)?.trim().isNotEmpty == true
          ? json['id'] as String
          : _generateId(),
      type: AlertType.fromWire(json['type'] as String?),
      priority: (json['priority'] as num?)?.toInt() ?? 100,
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      okLabel: json['okLabel'] as String? ?? '',
      url: json['url'] as String? ?? '',
      goLabel: json['goLabel'] as String? ?? '',
      createdAt: _parseDate(json['createdAt']),
      expiresAt: _parseDate(json['expiresAt']),
      metadata: rawMeta is List
          ? rawMeta
              .whereType<Map<Object?, Object?>>()
              .map((Map<Object?, Object?> e) => MetadataEntry(
                    key: e['key']?.toString() ?? '',
                    value: e['value']?.toString() ?? '',
                  ))
              .toList()
          : <MetadataEntry>[],
    );
  }

  static DateTime? _parseDate(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}
