# app_alerts_admin

A desktop admin portal for authoring and publishing [`app_alerts`](https://pub.dev/packages/app_alerts)
alert feeds.

Create and manage alerts through a friendly UI, see the exact feed JSON update
live, and publish it straight to your NetStorage URL (or any object store /
endpoint) — no hand-editing JSON.

## Why it stays correct

The admin depends on the published `app_alerts` package and serializes through
its `Alert` / `AlertFeed` models. The JSON it produces is therefore *exactly*
what the client consumes — a single source of truth for the wire contract, with
no chance of the two drifting apart.

## Features

- **Full contract coverage** — every field: type (urgent / inline), priority,
  title, message, OK/Go button labels, URL / deep link, created & expiry
  timestamps, and free-form metadata.
- **Live validation** — required fields, unique ids, URL scheme, expiry-after-
  created, plus soft warnings (e.g. an urgent alert with no message). The feed
  can't be published while any blocking issue remains.
- **Live JSON preview** — the exact document that will be uploaded, with a copy
  button.
- **Publish anywhere** — configure one or more destinations (URL, `PUT`/`POST`,
  `Content-Type`, headers). Works with NetStorage's HTTP API, S3/GCS presigned
  URLs, or any endpoint that accepts the feed body.
- **Configurable + pluggable auth** — per-destination auth schemes with no
  code: none/static headers, Bearer token, Basic, and **Akamai NetStorage**
  (HMAC-SHA256 ACS signing). For anything else, inject a custom
  `UploadAuthorizer` — see below.
- **Round-trip existing feeds** — import by fetching the current feed from a
  URL, opening a `.json` file, or pasting JSON; edit; re-publish.
- **Never lose work** — the in-progress feed and destinations autosave locally.
- **Nice to use** — Material 3, light/dark, responsive master–detail layout.

## Running

```sh
flutter pub get
flutter run -d windows   # or macos / linux / chrome
```

Primarily a desktop tool: uploading directly to NetStorage/S3 from a browser
is blocked by CORS, which desktop builds avoid.

## Publishing a feed

1. Click the destination chip in the toolbar → **Add destination**.
2. Enter the URL, choose `PUT` (typical for object stores) or `POST`, and pick
   an **Authentication** scheme: none, Bearer, Basic, or Akamai NetStorage.
3. Author your alerts, then click **Publish**. The feed is validated, then
   uploaded to the selected destination.

## Authentication

Each destination carries an auth scheme, resolved to an `UploadAuthorizer`
that produces the request's final headers. The built-ins cover the common
cases with no code:

| Scheme | Adds |
|---|---|
| None | Just the destination's static headers |
| Bearer | `Authorization: Bearer <token>` |
| Basic | `Authorization: Basic base64(user:pass)` |
| NetStorage | `X-Akamai-ACS-Action/-Auth-Data/-Auth-Sign` (HMAC-SHA256) |

### Custom auth (the override seam)

For anything the built-ins don't cover — AWS SigV4, an OAuth token refresh,
bespoke request signing — implement `UploadAuthorizer` and inject it, the same
way you'd override the client's urgent-alert builder. When supplied, it
authorizes **every** upload, taking precedence over per-destination schemes:

```dart
class MySigV4Authorizer implements UploadAuthorizer {
  @override
  Future<Map<String, String>> authorize(UploadRequest request) async {
    // Sign request.method / request.url / request.body however you need.
    return {...request.headers, 'Authorization': await sign(request)};
  }
}

final controller = AdminController(
  uploader: HttpFeedUploader(authorizer: MySigV4Authorizer()),
);
```

`UploadRequest` gives the authorizer the method, URL, body, content type, and
base headers; `authorize` may be async (for token refresh or remote signing).

## Architecture

```
lib/src/
  models/     AlertDraft (mutable, editable) <-> app_alerts.Alert; MetadataEntry;
              UploadDestination
  services/   HttpFeedUploader (PUT/POST), FeedFetcher (GET), AdminStorage
              (local autosave)
  state/      AdminController (ChangeNotifier) - CRUD, validation, publish
  ui/         HomePage master-detail, editor, list, JSON preview, dialogs
```

The core (models, services, controller) is pure logic with no widget
dependencies and is covered by unit tests; run them with `flutter test`.

## License

MIT — see [LICENSE](LICENSE).
