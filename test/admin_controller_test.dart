import 'package:app_alerts/app_alerts.dart';
import 'package:app_alerts_admin/src/models/upload_destination.dart';
import 'package:app_alerts_admin/src/services/admin_storage.dart';
import 'package:app_alerts_admin/src/services/feed_fetcher.dart';
import 'package:app_alerts_admin/src/services/feed_uploader.dart';
import 'package:app_alerts_admin/src/state/admin_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemStorage extends AdminStorage {
  AdminWorkspace saved = AdminWorkspace.empty;

  @override
  Future<AdminWorkspace> load() async => saved;

  @override
  Future<void> save(AdminWorkspace ws) async => saved = ws;
}

class _FakeUploader implements FeedUploader {
  _FakeUploader(this.result);
  UploadResult result;
  String? lastBody;
  UploadDestination? lastDestination;

  @override
  Future<UploadResult> upload({
    required UploadDestination destination,
    required String body,
  }) async {
    lastBody = body;
    lastDestination = destination;
    return result;
  }
}

class _FakeFetcher extends FeedFetcher {
  _FakeFetcher(this.body);
  final String body;

  @override
  Future<String> fetch(String url) async => body;
}

AdminController _controller({
  FeedUploader? uploader,
  FeedFetcher? fetcher,
  AdminStorage? storage,
}) {
  return AdminController(
    storage: storage ?? _MemStorage(),
    uploader: uploader ??
        _FakeUploader(
            const UploadResult(success: true, statusCode: 200, message: 'ok')),
    fetcher: fetcher ?? _FakeFetcher('{"alerts": []}'),
    autosaveDelay: Duration.zero,
  );
}

void main() {
  group('CRUD', () {
    test('addAlert appends and selects it', () async {
      final AdminController c = _controller();
      await c.load();
      c.addAlert(type: AlertType.urgent);
      expect(c.alerts, hasLength(1));
      expect(c.selected, isNotNull);
      expect(c.selected!.type, AlertType.urgent);
      expect(c.selectedId, c.alerts.first.id);
    });

    test('duplicate inserts after the original and selects the copy', () async {
      final AdminController c = _controller();
      await c.load();
      c.addAlert();
      final String id = c.alerts.first.id;
      c.editSelected((d) => d.title = 'Original');
      c.duplicate(id);
      expect(c.alerts, hasLength(2));
      expect(c.selected!.title, 'Original (copy)');
      expect(c.alerts[0].id, id);
    });

    test('delete removes and reselects a neighbour', () async {
      final AdminController c = _controller();
      await c.load();
      c.addAlert();
      c.addAlert();
      final String second = c.alerts[1].id;
      c.delete(c.alerts[0].id);
      expect(c.alerts, hasLength(1));
      expect(c.selectedId, second);
    });

    test('editSelected follows an id rename', () async {
      final AdminController c = _controller();
      await c.load();
      c.addAlert();
      c.editSelected((d) => d.id = 'renamed');
      expect(c.selectedId, 'renamed');
      expect(c.selected, isNotNull);
    });
  });

  group('validation', () {
    test('detects duplicate ids', () async {
      final AdminController c = _controller();
      await c.load();
      c.addAlert();
      c.editSelected((d) => d.id = 'dupe');
      c.addAlert();
      c.editSelected((d) => d.id = 'dupe');
      expect(c.duplicateIds, contains('dupe'));
      expect(c.isFeedValid, isFalse);
    });

    test('a feed with a titleless alert is invalid and lists the issue',
        () async {
      final AdminController c = _controller();
      await c.load();
      c.addAlert(); // blank title
      expect(c.isFeedValid, isFalse);
      expect(c.feedIssues, isNotEmpty);
    });

    test('a complete alert makes the feed valid', () async {
      final AdminController c = _controller();
      await c.load();
      c.addAlert();
      c.editSelected((d) {
        d.id = 'a';
        d.title = 'Hello';
      });
      expect(c.isFeedValid, isTrue);
      expect(c.feedIssues, isEmpty);
    });
  });

  group('feedJson', () {
    test('excludes alerts with blocking errors', () async {
      final AdminController c = _controller();
      await c.load();
      c.addAlert();
      c.editSelected((d) {
        d.id = 'good';
        d.title = 'Valid';
      });
      c.addAlert(); // invalid (blank title) — excluded
      final AlertFeed feed = AlertFeed.parse(c.feedJson());
      expect(feed.alerts, hasLength(1));
      expect(feed.alerts.single.id, 'good');
    });
  });

  group('import', () {
    test('importJson replaces the feed with parsed alerts', () async {
      final AdminController c = _controller();
      await c.load();
      c.addAlert();
      final bool ok =
          await c.importJson('{"alerts":[{"id":"x","title":"Imported"}]}');
      expect(ok, isTrue);
      expect(c.alerts, hasLength(1));
      expect(c.alerts.single.title, 'Imported');
    });

    test('importJson reports a parse failure and keeps state', () async {
      final AdminController c = _controller();
      await c.load();
      c.addAlert();
      final bool ok = await c.importJson('not json');
      expect(ok, isFalse);
      expect(c.statusIsError, isTrue);
      expect(c.alerts, hasLength(1));
    });

    test('importFromUrl pulls and imports via the fetcher', () async {
      final AdminController c = _controller(
        fetcher: _FakeFetcher('{"alerts":[{"id":"u","title":"From URL"}]}'),
      );
      await c.load();
      final bool ok = await c.importFromUrl('https://e.com/feed.json');
      expect(ok, isTrue);
      expect(c.alerts.single.title, 'From URL');
    });
  });

  group('publish', () {
    test('fails without a destination', () async {
      final AdminController c = _controller();
      await c.load();
      c.addAlert();
      c.editSelected((d) {
        d.id = 'a';
        d.title = 't';
      });
      final UploadResult r = await c.publish();
      expect(r.success, isFalse);
      expect(r.message, contains('destination'));
    });

    test('fails when the feed is invalid', () async {
      final AdminController c = _controller();
      await c.load();
      c.addDestination(
          const UploadDestination(name: 'd', url: 'https://e.com/f.json'));
      c.addAlert(); // invalid
      final UploadResult r = await c.publish();
      expect(r.success, isFalse);
      expect(r.message, contains('issue'));
    });

    test('publishes the feed JSON to the selected destination', () async {
      final _FakeUploader uploader = _FakeUploader(const UploadResult(
          success: true, statusCode: 200, message: 'Published'));
      final AdminController c = _controller(uploader: uploader);
      await c.load();
      c.addDestination(
          const UploadDestination(name: 'Prod', url: 'https://e.com/f.json'));
      c.addAlert();
      c.editSelected((d) {
        d.id = 'a';
        d.title = 'Ship it';
      });

      final UploadResult r = await c.publish();

      expect(r.success, isTrue);
      expect(c.lastPublishedAt, isNotNull);
      expect(uploader.lastDestination!.name, 'Prod');
      final AlertFeed sent = AlertFeed.parse(uploader.lastBody!);
      expect(sent.alerts.single.id, 'a');
    });
  });

  group('destinations', () {
    test('add, select, and remove maintain a valid selection', () async {
      final AdminController c = _controller();
      await c.load();
      c.addDestination(const UploadDestination(name: 'A', url: 'https://a'));
      c.addDestination(const UploadDestination(name: 'B', url: 'https://b'));
      expect(c.selectedDestination!.name, 'B');
      c.selectDestination(0);
      expect(c.selectedDestination!.name, 'A');
      c.removeDestination(0);
      expect(c.destinations, hasLength(1));
      expect(c.selectedDestination!.name, 'B');
    });
  });

  group('persistence', () {
    test('structural changes persist to storage', () async {
      final _MemStorage storage = _MemStorage();
      final AdminController c = _controller(storage: storage);
      await c.load();
      c.addAlert();
      c.editSelected((d) => d.title = 'Persisted');
      // editSelected debounces with a zero delay; let it flush.
      await Future<void>.delayed(Duration.zero);
      expect(storage.saved.drafts, isNotEmpty);
    });
  });
}
