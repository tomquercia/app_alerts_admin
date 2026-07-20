import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/destination_auth.dart';

/// The outgoing upload, described for an [UploadAuthorizer].
class UploadRequest {
  /// Creates a request context.
  const UploadRequest({
    required this.method,
    required this.url,
    required this.body,
    required this.contentType,
    required this.headers,
  });

  /// The HTTP verb (`PUT` / `POST`).
  final String method;

  /// The destination URL.
  final Uri url;

  /// The serialized feed body.
  final String body;

  /// The configured content type.
  final String contentType;

  /// The base headers (content type plus the destination's static headers).
  final Map<String, String> headers;
}

/// Produces the final request headers for an upload — the extensibility seam
/// for authentication.
///
/// The uploader delegates header construction here. Ship a custom
/// implementation and inject it via `HttpFeedUploader(authorizer: …)` to sign
/// requests any way you like (AWS SigV4, an OAuth token refresh, request
/// signing, …) without touching the package — the same pattern as overriding
/// the client's urgent-alert builder.
abstract class UploadAuthorizer {
  /// Returns the complete header set to send. Typically
  /// `{...request.headers, <auth headers>}`.
  FutureOr<Map<String, String>> authorize(UploadRequest request);
}

/// Passes the base headers through unchanged (the default).
class StaticHeadersAuthorizer implements UploadAuthorizer {
  /// Creates the pass-through authorizer.
  const StaticHeadersAuthorizer();

  @override
  Map<String, String> authorize(UploadRequest request) => request.headers;
}

/// Adds `Authorization: Bearer <token>`.
class BearerTokenAuthorizer implements UploadAuthorizer {
  /// Creates a bearer authorizer.
  const BearerTokenAuthorizer(this.token);

  /// The bearer token.
  final String token;

  @override
  Map<String, String> authorize(UploadRequest request) => <String, String>{
        ...request.headers,
        'Authorization': 'Bearer $token',
      };
}

/// Adds HTTP Basic `Authorization`.
class BasicAuthAuthorizer implements UploadAuthorizer {
  /// Creates a basic-auth authorizer.
  const BasicAuthAuthorizer(this.username, this.password);

  /// The username.
  final String username;

  /// The password.
  final String password;

  @override
  Map<String, String> authorize(UploadRequest request) {
    final String encoded = base64.encode(utf8.encode('$username:$password'));
    return <String, String>{
      ...request.headers,
      'Authorization': 'Basic $encoded',
    };
  }
}

/// Signs requests for Akamai NetStorage's HTTP API.
///
/// Implements the standard ACS auth: an `X-Akamai-ACS-Auth-Data` tuple and an
/// `X-Akamai-ACS-Auth-Sign` HMAC-SHA256 over `authData + path +
/// "\nx-akamai-acs-action:" + action + "\n"`, keyed by the upload account
/// secret. [clock] and [uniqueId] are injectable for deterministic tests.
class NetStorageAuthorizer implements UploadAuthorizer {
  /// Creates a NetStorage authorizer.
  NetStorageAuthorizer({
    required this.keyName,
    required this.key,
    this.action = NetStorageAuth.defaultAction,
    DateTime Function()? clock,
    int Function()? uniqueId,
  })  : _clock = clock ?? DateTime.now,
        _uniqueId = uniqueId ?? _defaultUniqueId;

  /// The upload account key name.
  final String keyName;

  /// The upload account secret key.
  final String key;

  /// The `X-Akamai-ACS-Action` value.
  final String action;

  final DateTime Function() _clock;
  final int Function() _uniqueId;

  @override
  Map<String, String> authorize(UploadRequest request) {
    final int epoch = _clock().toUtc().millisecondsSinceEpoch ~/ 1000;
    final int unique = _uniqueId();
    final String authData = '5, 0.0.0.0, 0.0.0.0, $epoch, $unique, $keyName';
    // NetStorage signs the resource path, not the whole URL.
    final String path = request.url.path;
    final String signString = '$path\nx-akamai-acs-action:$action\n';
    final Digest digest = Hmac(sha256, utf8.encode(key))
        .convert(utf8.encode(authData + signString));
    final String sign = base64.encode(digest.bytes);
    return <String, String>{
      ...request.headers,
      'X-Akamai-ACS-Action': action,
      'X-Akamai-ACS-Auth-Data': authData,
      'X-Akamai-ACS-Auth-Sign': sign,
    };
  }

  static int _counter = 0;
  static int _defaultUniqueId() =>
      (DateTime.now().microsecondsSinceEpoch & 0xffffff) + (_counter++);
}

/// Maps a configured [DestinationAuth] to its built-in [UploadAuthorizer].
///
/// Exhaustive over the sealed union — adding a new scheme is a compile error
/// until it is handled here.
UploadAuthorizer authorizerFor(DestinationAuth auth) {
  return switch (auth) {
    NoAuth() => const StaticHeadersAuthorizer(),
    BearerAuth(:final String token) => BearerTokenAuthorizer(token),
    BasicAuth(:final String username, :final String password) =>
      BasicAuthAuthorizer(username, password),
    NetStorageAuth(
      :final String keyName,
      :final String key,
      :final String action
    ) =>
      NetStorageAuthorizer(keyName: keyName, key: key, action: action),
  };
}
