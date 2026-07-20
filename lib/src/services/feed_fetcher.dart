import 'dart:convert';

import 'package:http/http.dart' as http;

/// Fetches the current feed document from a URL so an existing feed can be
/// pulled in and edited (the round-trip: GET → edit → PUT back).
class FeedFetcher {
  /// Creates a fetcher. Inject a [client] in tests.
  FeedFetcher({http.Client? client, this.timeout = const Duration(seconds: 20)})
      : _client = client;

  final http.Client? _client;

  /// Per-request timeout.
  final Duration timeout;

  /// GETs [url] and returns the response body as UTF-8 text.
  ///
  /// Throws [FeedFetchException] on a non-200 response or transport failure,
  /// with a message suitable for display.
  Future<String> fetch(String url) async {
    final Uri? uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme) {
      throw const FeedFetchException('Enter a valid absolute URL to load.');
    }
    final http.Client client = _client ?? http.Client();
    try {
      final http.Response response = await client.get(uri).timeout(timeout);
      if (response.statusCode != 200) {
        throw FeedFetchException(
            'Could not load the feed (HTTP ${response.statusCode}).');
      }
      return utf8.decode(response.bodyBytes);
    } on FeedFetchException {
      rethrow;
    } on Exception catch (e) {
      throw FeedFetchException('Could not load the feed: $e');
    } finally {
      if (_client == null) client.close();
    }
  }
}

/// Thrown by [FeedFetcher.fetch] on failure.
class FeedFetchException implements Exception {
  /// Creates the exception with a display [message].
  const FeedFetchException(this.message);

  /// What went wrong.
  final String message;

  @override
  String toString() => message;
}
