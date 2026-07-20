/// A single editable `metadata` key/value pair.
///
/// The alert contract's `metadata` is a free-form JSON object; this admin
/// edits it as an ordered list of string key/value rows (the common case:
/// links, categories, flags). Values are emitted as JSON strings.
class MetadataEntry {
  /// Creates an entry. Both fields default to empty for a fresh row.
  MetadataEntry({this.key = '', this.value = ''});

  /// The metadata key.
  String key;

  /// The metadata value (emitted as a JSON string).
  String value;

  /// A deep copy, so duplicating an alert doesn't share row instances.
  MetadataEntry copy() => MetadataEntry(key: key, value: value);
}
