/// How an [UploadDestination] authenticates its upload requests.
///
/// A small, serializable, sealed union of the built-in schemes. Custom auth
/// beyond these is handled by injecting a custom `UploadAuthorizer` into the
/// uploader (the code override seam) — see `feed_uploader.dart`.
sealed class DestinationAuth {
  /// Const constructor for subclasses.
  const DestinationAuth();

  /// No authentication beyond the destination's static headers.
  static const DestinationAuth none = NoAuth();

  /// Stable discriminator used for persistence and UI.
  String get kind;

  /// A short, secret-free description for display.
  String get summary;

  /// Serializes for local persistence.
  Map<String, Object?> toJson();

  /// Restores from persisted JSON, tolerating unknown/missing kinds.
  factory DestinationAuth.fromJson(Map<String, Object?> json) {
    switch (json['kind']) {
      case 'bearer':
        return BearerAuth(token: json['token'] as String? ?? '');
      case 'basic':
        return BasicAuth(
          username: json['username'] as String? ?? '',
          password: json['password'] as String? ?? '',
        );
      case 'netstorage':
        return NetStorageAuth(
          keyName: json['keyName'] as String? ?? '',
          key: json['key'] as String? ?? '',
          action: json['action'] as String? ?? NetStorageAuth.defaultAction,
        );
      case 'none':
      default:
        return const NoAuth();
    }
  }
}

/// Static headers only (the default).
final class NoAuth extends DestinationAuth {
  /// Creates a no-auth scheme.
  const NoAuth();

  @override
  String get kind => 'none';

  @override
  String get summary => 'Headers only';

  @override
  Map<String, Object?> toJson() => <String, Object?>{'kind': kind};
}

/// `Authorization: Bearer <token>`.
final class BearerAuth extends DestinationAuth {
  /// Creates bearer-token auth.
  const BearerAuth({required this.token});

  /// The bearer token.
  final String token;

  @override
  String get kind => 'bearer';

  @override
  String get summary => 'Bearer token';

  @override
  Map<String, Object?> toJson() =>
      <String, Object?>{'kind': kind, 'token': token};
}

/// HTTP Basic auth (`Authorization: Basic base64(user:pass)`).
final class BasicAuth extends DestinationAuth {
  /// Creates basic auth.
  const BasicAuth({required this.username, required this.password});

  /// The username.
  final String username;

  /// The password.
  final String password;

  @override
  String get kind => 'basic';

  @override
  String get summary => 'Basic ($username)';

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'kind': kind,
        'username': username,
        'password': password,
      };
}

/// Akamai NetStorage HTTP API auth (HMAC-SHA256 signed ACS headers).
final class NetStorageAuth extends DestinationAuth {
  /// Creates NetStorage auth from an upload account's key name and key.
  const NetStorageAuth({
    required this.keyName,
    required this.key,
    this.action = defaultAction,
  });

  /// The default ACS action for a feed upload.
  static const String defaultAction = 'version=1&action=upload';

  /// The upload account's key name (the "id").
  final String keyName;

  /// The upload account's secret key.
  final String key;

  /// The `X-Akamai-ACS-Action` value.
  final String action;

  @override
  String get kind => 'netstorage';

  @override
  String get summary => 'NetStorage ($keyName)';

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'kind': kind,
        'keyName': keyName,
        'key': key,
        'action': action,
      };
}
