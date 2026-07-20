import 'package:app_alerts/app_alerts.dart';
import 'package:app_alerts_admin/src/models/alert_draft.dart';
import 'package:app_alerts_admin/src/models/metadata_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AlertDraft.blank', () {
    test('has a generated id and a createdAt', () {
      final AlertDraft d = AlertDraft.blank(type: AlertType.urgent);
      expect(d.id, isNotEmpty);
      expect(d.type, AlertType.urgent);
      expect(d.createdAt, isNotNull);
      expect(d.hasBlockingError, isTrue, reason: 'no title yet');
    });

    test('generates unique ids', () {
      final Set<String> ids = <String>{
        for (int i = 0; i < 50; i++) AlertDraft.blank().id,
      };
      expect(ids, hasLength(50));
    });
  });

  group('validation', () {
    test('requires id and title', () {
      final AlertDraft d = AlertDraft(id: '', title: '');
      expect(d.idError, isNotNull);
      expect(d.titleError, isNotNull);
      expect(d.hasBlockingError, isTrue);
    });

    test('accepts a schemeful url and rejects a schemeless one', () {
      final AlertDraft ok = AlertDraft(id: 'a', title: 't', url: 'https://x.y');
      expect(ok.urlError, isNull);
      final AlertDraft deep =
          AlertDraft(id: 'a', title: 't', url: 'myapp://path');
      expect(deep.urlError, isNull);
      final AlertDraft bad = AlertDraft(id: 'a', title: 't', url: 'not a url');
      expect(bad.urlError, isNotNull);
    });

    test('expiry must be after created', () {
      final AlertDraft d = AlertDraft(
        id: 'a',
        title: 't',
        createdAt: DateTime.utc(2026, 7, 20, 12),
        expiresAt: DateTime.utc(2026, 7, 20, 11),
      );
      expect(d.expiresError, isNotNull);
      d.expiresAt = DateTime.utc(2026, 7, 20, 13);
      expect(d.expiresError, isNull);
    });

    test('warns about goLabel without a url and urgent without a message', () {
      final AlertDraft d = AlertDraft(
        id: 'a',
        title: 't',
        type: AlertType.urgent,
        goLabel: 'Go',
      );
      expect(d.warnings, isNotEmpty);
    });
  });

  group('toAlert', () {
    test('produces an Alert matching the edited fields', () {
      final AlertDraft d = AlertDraft(
        id: '  keep-trimmed  ',
        title: '  Title  ',
        message: ' Body ',
        type: AlertType.urgent,
        priority: 3,
        okLabel: 'Not now',
        url: 'https://status.example.com',
        goLabel: 'View',
        createdAt: DateTime.utc(2026, 7, 20),
        metadata: <MetadataEntry>[
          MetadataEntry(key: 'category', value: 'incident'),
          MetadataEntry(key: '', value: 'dropped'), // blank key dropped
        ],
      );
      final Alert a = d.toAlert();
      expect(a.id, 'keep-trimmed');
      expect(a.title, 'Title');
      expect(a.message, 'Body');
      expect(a.type, AlertType.urgent);
      expect(a.priority, 3);
      expect(a.okLabel, 'Not now');
      expect(a.url, Uri.parse('https://status.example.com'));
      expect(a.goLabel, 'View');
      expect(a.metadata, <String, Object?>{'category': 'incident'});
    });

    test('omits an invalid url rather than throwing', () {
      final AlertDraft d = AlertDraft(id: 'a', title: 't', url: 'nope');
      expect(d.toAlert().url, isNull);
    });

    test('round-trips through the app_alerts JSON contract', () {
      final AlertDraft d = AlertDraft(
        id: 'rt',
        title: 'Round trip',
        type: AlertType.inline,
        priority: 7,
        url: 'https://e.com/x',
        createdAt: DateTime.utc(2026, 7, 20, 8),
        expiresAt: DateTime.utc(2026, 7, 21, 8),
        metadata: <MetadataEntry>[MetadataEntry(key: 'k', value: 'v')],
      );
      final Alert reparsed = Alert.fromJson(d.toAlert().toJson());
      expect(reparsed.id, 'rt');
      expect(reparsed.priority, 7);
      expect(reparsed.url, Uri.parse('https://e.com/x'));
      expect(reparsed.createdAt, DateTime.utc(2026, 7, 20, 8));
      expect(reparsed.expiresAt, DateTime.utc(2026, 7, 21, 8));
      expect(reparsed.metadata['k'], 'v');
    });
  });

  group('fromAlert / duplicate', () {
    test('fromAlert restores all fields', () {
      final Alert a = Alert(
        id: 'x',
        title: 'T',
        message: 'M',
        type: AlertType.urgent,
        priority: 2,
        okLabel: 'OK',
        url: Uri.parse('https://e.com'),
        goLabel: 'Go',
        createdAt: DateTime.utc(2026),
        metadata: const <String, Object?>{'a': 'b'},
      );
      final AlertDraft d = AlertDraft.fromAlert(a);
      expect(d.id, 'x');
      expect(d.url, 'https://e.com');
      expect(d.goLabel, 'Go');
      expect(d.metadata.single.key, 'a');
      expect(d.metadata.single.value, 'b');
    });

    test('duplicate gets a fresh id and a copied, independent metadata list',
        () {
      final AlertDraft d = AlertDraft(
        id: 'orig',
        title: 'Hi',
        metadata: <MetadataEntry>[MetadataEntry(key: 'k', value: 'v')],
      );
      final AlertDraft copy = d.duplicate();
      expect(copy.id, isNot('orig'));
      expect(copy.title, 'Hi (copy)');
      copy.metadata.single.value = 'changed';
      expect(d.metadata.single.value, 'v', reason: 'rows are deep-copied');
    });
  });

  group('storage round-trip', () {
    test('toStorageJson/fromStorageJson preserves in-progress drafts', () {
      final AlertDraft d = AlertDraft(
        id: 'draft',
        title: '', // invalid but must survive persistence
        url: 'half-typed',
        priority: 42,
        metadata: <MetadataEntry>[MetadataEntry(key: 'k', value: 'v')],
        createdAt: DateTime.utc(2026, 7, 20),
      );
      final AlertDraft restored = AlertDraft.fromStorageJson(d.toStorageJson());
      expect(restored.id, 'draft');
      expect(restored.title, '');
      expect(restored.url, 'half-typed');
      expect(restored.priority, 42);
      expect(restored.metadata.single.key, 'k');
      expect(restored.createdAt, DateTime.utc(2026, 7, 20));
    });
  });
}
