import 'dart:convert';

import 'package:app_alerts_admin/src/models/destination_auth.dart';
import 'package:app_alerts_admin/src/services/upload_authorizer.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

UploadRequest _request({
  String method = 'PUT',
  String url = 'https://ns.example.com/123456/alerts/feed.json',
  Map<String, String> headers = const <String, String>{
    'content-type': 'application/json',
  },
}) {
  return UploadRequest(
    method: method,
    url: Uri.parse(url),
    body: '{"version":1,"alerts":[]}',
    contentType: 'application/json',
    headers: headers,
  );
}

/// Resolves the (possibly async) authorizer result to a concrete map.
Future<Map<String, String>> headersFrom(
        UploadAuthorizer authorizer, UploadRequest request) async =>
    authorizer.authorize(request);

void main() {
  group('built-in authorizers', () {
    test('StaticHeadersAuthorizer passes headers through', () async {
      final Map<String, String> out =
          await headersFrom(const StaticHeadersAuthorizer(), _request());
      expect(out, <String, String>{'content-type': 'application/json'});
    });

    test('BearerTokenAuthorizer adds a bearer Authorization header', () async {
      final Map<String, String> out = await headersFrom(
          const BearerTokenAuthorizer('secret-token'), _request());
      expect(out['Authorization'], 'Bearer secret-token');
      expect(out['content-type'], 'application/json',
          reason: 'base headers are preserved');
    });

    test('BasicAuthAuthorizer base64-encodes user:pass', () async {
      final Map<String, String> out = await headersFrom(
          const BasicAuthAuthorizer('alice', 'p@ss'), _request());
      expect(out['Authorization'],
          'Basic ${base64.encode(utf8.encode('alice:p@ss'))}');
    });
  });

  group('NetStorageAuthorizer', () {
    NetStorageAuthorizer signer() => NetStorageAuthorizer(
          keyName: 'upload-account',
          key: 'abcdefghij0123456789',
          clock: () => DateTime.utc(2026, 7, 20, 12),
          uniqueId: () => 42,
        );

    test('emits the three ACS headers with the expected auth-data tuple',
        () async {
      final Map<String, String> out = await headersFrom(signer(), _request());
      final int epoch =
          DateTime.utc(2026, 7, 20, 12).millisecondsSinceEpoch ~/ 1000;
      expect(out['X-Akamai-ACS-Action'], 'version=1&action=upload');
      expect(out['X-Akamai-ACS-Auth-Data'],
          '5, 0.0.0.0, 0.0.0.0, $epoch, 42, upload-account');
      expect(out['X-Akamai-ACS-Auth-Sign'], isNotEmpty);
      expect(out['content-type'], 'application/json');
    });

    test('signature matches the ACS message construction independently',
        () async {
      final Map<String, String> out = await headersFrom(signer(), _request());
      final int epoch =
          DateTime.utc(2026, 7, 20, 12).millisecondsSinceEpoch ~/ 1000;
      const String action = 'version=1&action=upload';
      const String path = '/123456/alerts/feed.json';
      final String authData = '5, 0.0.0.0, 0.0.0.0, $epoch, 42, upload-account';
      final String message = '$authData$path\nx-akamai-acs-action:$action\n';
      final String expected = base64.encode(
          Hmac(sha256, utf8.encode('abcdefghij0123456789'))
              .convert(utf8.encode(message))
              .bytes);
      expect(out['X-Akamai-ACS-Auth-Sign'], expected);
    });

    test('is deterministic for fixed clock/nonce and varies with the key',
        () async {
      final String a =
          (await headersFrom(signer(), _request()))['X-Akamai-ACS-Auth-Sign']!;
      final String b =
          (await headersFrom(signer(), _request()))['X-Akamai-ACS-Auth-Sign']!;
      expect(a, b);

      final NetStorageAuthorizer other = NetStorageAuthorizer(
        keyName: 'upload-account',
        key: 'DIFFERENT-key-9999999',
        clock: () => DateTime.utc(2026, 7, 20, 12),
        uniqueId: () => 42,
      );
      final String c =
          (await headersFrom(other, _request()))['X-Akamai-ACS-Auth-Sign']!;
      expect(c, isNot(a));
    });
  });

  group('authorizerFor', () {
    test('maps each configured scheme to its authorizer', () {
      expect(authorizerFor(const NoAuth()), isA<StaticHeadersAuthorizer>());
      expect(authorizerFor(const BearerAuth(token: 't')),
          isA<BearerTokenAuthorizer>());
      expect(authorizerFor(const BasicAuth(username: 'u', password: 'p')),
          isA<BasicAuthAuthorizer>());
      expect(authorizerFor(const NetStorageAuth(keyName: 'k', key: 's')),
          isA<NetStorageAuthorizer>());
    });
  });

  group('DestinationAuth serialization', () {
    test('round-trips every scheme', () {
      final List<DestinationAuth> all = <DestinationAuth>[
        const NoAuth(),
        const BearerAuth(token: 'tok'),
        const BasicAuth(username: 'u', password: 'p'),
        const NetStorageAuth(keyName: 'kn', key: 'kk'),
      ];
      for (final DestinationAuth auth in all) {
        final DestinationAuth back = DestinationAuth.fromJson(auth.toJson());
        expect(back.kind, auth.kind);
        expect(back.toJson(), auth.toJson());
      }
    });

    test('unknown/missing kind falls back to NoAuth', () {
      expect(DestinationAuth.fromJson(<String, Object?>{}), isA<NoAuth>());
      expect(DestinationAuth.fromJson(<String, Object?>{'kind': 'mystery'}),
          isA<NoAuth>());
    });
  });
}
