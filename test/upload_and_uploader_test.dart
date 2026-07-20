import 'package:app_alerts_admin/src/models/upload_destination.dart';
import 'package:app_alerts_admin/src/services/feed_uploader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('UploadDestination', () {
    test('isComplete requires an absolute URL', () {
      expect(const UploadDestination(name: 'n', url: '').isComplete, isFalse);
      expect(
          const UploadDestination(name: 'n', url: 'foo').isComplete, isFalse);
      expect(
          const UploadDestination(name: 'n', url: 'https://x.y/f.json')
              .isComplete,
          isTrue);
    });

    test('round-trips through JSON', () {
      const UploadDestination dest = UploadDestination(
        name: 'Prod',
        url: 'https://ns.example.com/alerts.json',
        method: UploadMethod.post,
        contentType: 'application/json',
        headers: <String, String>{'Authorization': 'Bearer x'},
      );
      final UploadDestination back = UploadDestination.fromJson(dest.toJson());
      expect(back.name, 'Prod');
      expect(back.url, dest.url);
      expect(back.method, UploadMethod.post);
      expect(back.headers['Authorization'], 'Bearer x');
    });
  });

  group('HttpFeedUploader', () {
    const UploadDestination dest = UploadDestination(
      name: 'Prod',
      url: 'https://ns.example.com/alerts.json',
      headers: <String, String>{'Authorization': 'Bearer token'},
    );

    test('PUTs the body with configured headers on success', () async {
      late http.Request seen;
      final HttpFeedUploader uploader = HttpFeedUploader(
        client: MockClient((http.Request req) async {
          seen = req;
          return http.Response('', 200);
        }),
      );
      final UploadResult result =
          await uploader.upload(destination: dest, body: '{"ok":true}');

      expect(result.success, isTrue);
      expect(result.statusCode, 200);
      expect(seen.method, 'PUT');
      expect(seen.url, Uri.parse(dest.url));
      expect(seen.body, '{"ok":true}');
      expect(seen.headers['Authorization'], 'Bearer token');
      expect(seen.headers['content-type'], contains('application/json'));
    });

    test('uses POST when configured', () async {
      late String method;
      final HttpFeedUploader uploader = HttpFeedUploader(
        client: MockClient((http.Request req) async {
          method = req.method;
          return http.Response('', 201);
        }),
      );
      final UploadResult result = await uploader.upload(
        destination: dest.copyWith(method: UploadMethod.post),
        body: '{}',
      );
      expect(method, 'POST');
      expect(result.success, isTrue);
    });

    test('reports a non-2xx response as failure with the status', () async {
      final HttpFeedUploader uploader = HttpFeedUploader(
        client: MockClient(
            (http.Request req) async => http.Response('denied', 403)),
      );
      final UploadResult result =
          await uploader.upload(destination: dest, body: '{}');
      expect(result.success, isFalse);
      expect(result.statusCode, 403);
      expect(result.message, contains('403'));
    });

    test('never throws on a transport error', () async {
      final HttpFeedUploader uploader = HttpFeedUploader(
        client: MockClient(
            (http.Request req) async => throw http.ClientException('down')),
      );
      final UploadResult result =
          await uploader.upload(destination: dest, body: '{}');
      expect(result.success, isFalse);
      expect(result.message, contains('failed'));
    });

    test('rejects an invalid destination URL without a request', () async {
      final HttpFeedUploader uploader = HttpFeedUploader(
        client: MockClient((http.Request req) async {
          fail('should not send a request for an invalid URL');
        }),
      );
      final UploadResult result = await uploader.upload(
        destination: const UploadDestination(name: 'x', url: 'not-a-url'),
        body: '{}',
      );
      expect(result.success, isFalse);
    });
  });
}
