import 'destination_auth.dart';

/// The HTTP method used to publish the feed document.
enum UploadMethod {
  /// `PUT` — the default for object stores (NetStorage, S3 presigned URLs).
  put,

  /// `POST` — for endpoints that accept the feed as a posted body.
  post;

  /// The wire/HTTP verb.
  String get verb => name.toUpperCase();
}

/// A configured place to publish the alert feed: a URL, an HTTP method, and
/// any headers needed to authenticate (e.g. an auth token, or the headers
/// NetStorage's HTTP API expects).
class UploadDestination {
  /// Creates a destination.
  const UploadDestination({
    required this.name,
    required this.url,
    this.method = UploadMethod.put,
    this.contentType = 'application/json',
    this.headers = const <String, String>{},
    this.auth = const NoAuth(),
  });

  /// A human label shown in the UI (e.g. "Production NetStorage").
  final String name;

  /// The full destination URL the feed is written to.
  final String url;

  /// The HTTP method used to publish.
  final UploadMethod method;

  /// The `Content-Type` header sent with the body.
  final String contentType;

  /// Extra request headers sent with every upload (added on top of, and
  /// composed with, whatever [auth] contributes).
  final Map<String, String> headers;

  /// How the upload authenticates. Defaults to [NoAuth] (headers only).
  final DestinationAuth auth;

  /// Whether this destination has enough to attempt an upload.
  bool get isComplete {
    final Uri? parsed = Uri.tryParse(url.trim());
    return url.trim().isNotEmpty && parsed != null && parsed.hasScheme;
  }

  /// Returns a copy with the given fields replaced.
  UploadDestination copyWith({
    String? name,
    String? url,
    UploadMethod? method,
    String? contentType,
    Map<String, String>? headers,
    DestinationAuth? auth,
  }) {
    return UploadDestination(
      name: name ?? this.name,
      url: url ?? this.url,
      method: method ?? this.method,
      contentType: contentType ?? this.contentType,
      headers: headers ?? this.headers,
      auth: auth ?? this.auth,
    );
  }

  /// Serializes for local persistence.
  Map<String, Object?> toJson() => <String, Object?>{
        'name': name,
        'url': url,
        'method': method.name,
        'contentType': contentType,
        'headers': headers,
        'auth': auth.toJson(),
      };

  /// Restores from persisted JSON, tolerating missing/legacy fields.
  factory UploadDestination.fromJson(Map<String, Object?> json) {
    final Object? rawHeaders = json['headers'];
    final Object? rawAuth = json['auth'];
    return UploadDestination(
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? json['name'] as String
          : 'Destination',
      url: (json['url'] as String?) ?? '',
      method: (json['method'] as String?) == 'post'
          ? UploadMethod.post
          : UploadMethod.put,
      contentType: (json['contentType'] as String?) ?? 'application/json',
      headers: rawHeaders is Map
          ? rawHeaders.map((Object? k, Object? v) =>
              MapEntry<String, String>(k.toString(), v?.toString() ?? ''))
          : const <String, String>{},
      auth: rawAuth is Map
          ? DestinationAuth.fromJson(rawAuth.map((Object? k, Object? v) =>
              MapEntry<String, Object?>(k.toString(), v)))
          : const NoAuth(),
    );
  }
}
