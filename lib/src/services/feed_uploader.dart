import 'package:http/http.dart' as http;

import '../models/upload_destination.dart';

/// The outcome of an upload attempt.
class UploadResult {
  /// Creates a result.
  const UploadResult({
    required this.success,
    this.statusCode,
    required this.message,
  });

  /// Whether the destination accepted the feed (2xx response).
  final bool success;

  /// The HTTP status code, when a response was received.
  final int? statusCode;

  /// A human-readable summary suitable for display.
  final String message;
}

/// Publishes a serialized feed document to an [UploadDestination].
abstract class FeedUploader {
  /// Uploads [body] to [destination]. Never throws — transport failures are
  /// returned as an unsuccessful [UploadResult].
  Future<UploadResult> upload({
    required UploadDestination destination,
    required String body,
  });
}

/// A [FeedUploader] over plain HTTP(S), suitable for NetStorage's HTTP API,
/// S3/GCS presigned URLs, and any object store or endpoint that accepts a
/// `PUT`/`POST` of the JSON body with configured headers.
class HttpFeedUploader implements FeedUploader {
  /// Creates an uploader. Inject a [client] in tests; a default is created
  /// (and closed) per call otherwise.
  HttpFeedUploader({
    http.Client? client,
    this.timeout = const Duration(seconds: 30),
  }) : _client = client;

  final http.Client? _client;

  /// Per-request timeout.
  final Duration timeout;

  @override
  Future<UploadResult> upload({
    required UploadDestination destination,
    required String body,
  }) async {
    final Uri? uri = Uri.tryParse(destination.url.trim());
    if (uri == null || !uri.hasScheme) {
      return const UploadResult(
          success: false,
          message: 'The destination URL is not a valid absolute URL.');
    }

    final http.Client client = _client ?? http.Client();
    try {
      final http.Request request = http.Request(destination.method.verb, uri)
        ..body = body
        ..headers['content-type'] = destination.contentType;
      destination.headers.forEach((String k, String v) {
        if (k.trim().isNotEmpty) request.headers[k] = v;
      });

      final http.StreamedResponse streamed =
          await client.send(request).timeout(timeout);
      final http.Response response = await http.Response.fromStream(streamed);
      final bool ok = response.statusCode >= 200 && response.statusCode < 300;
      return UploadResult(
        success: ok,
        statusCode: response.statusCode,
        message: ok
            ? 'Published successfully (HTTP ${response.statusCode}).'
            : 'Destination rejected the upload (HTTP '
                '${response.statusCode})${_snippet(response.body)}',
      );
    } on Exception catch (e) {
      return UploadResult(
        success: false,
        message: 'Upload failed: $e',
      );
    } finally {
      if (_client == null) client.close();
    }
  }

  String _snippet(String body) {
    final String trimmed = body.trim();
    if (trimmed.isEmpty) return '.';
    final String oneLine = trimmed.replaceAll(RegExp(r'\s+'), ' ');
    return ': ${oneLine.length > 200 ? '${oneLine.substring(0, 200)}…' : oneLine}';
  }
}
