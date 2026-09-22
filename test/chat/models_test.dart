import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/chat/model_access.dart';
import 'package:ghostkey/chat/models.dart';
import 'package:ghostkey/server/dto/billing.dart';
import 'package:ghostkey/server/dto/models.dart';

// A trimmed GET /api/models body, the shape openapi.yaml's example has.
final Map<String, dynamic> body = {
  'surfaces': [
    {
      'id': 'chat',
      'default': 'auto',
      'models': [
        {'id': 'auto', 'name': 'Auto', 'capability': null, 'quota': null},
        {'id': 'opus-5-5', 'name': 'Claude Opus 5.5', 'capability': 'models.advanced', 'quota': null},
        {'id': 'fable-5', 'name': 'Claude Fable 5', 'capability': 'models.premium', 'quota': 'fable_chat'},
        {'id': '', 'name': 'Broken', 'capability': null, 'quota': null},
      ],
    },
    {
      'id': 'edit_pass',
      'default': 'gemini-flash',
      'models': [
        {'id': 'gemini-flash', 'name': 'Gemini Flash', 'capability': null, 'quota': null},
      ],
    },
  ],
};

void main() {
  final catalog = ModelCatalog.fromJson(body);
  final chat = catalog.surface(chatSurfaceId)!;

  group('ModelCatalog.fromJson', () {
    test('reads surfaces and rows in order, dropping a row with no id', () {
      expect(catalog.surfaces.map((s) => s.id), ['chat', 'edit_pass']);
      expect(chat.models.map((m) => m.id), ['auto', 'opus-5-5', 'fable-5']);
      expect(chat.defaultModel?.name, 'Auto');
      final fable = chat.model('fable-5')!;
      expect(fable.capability, 'models.premium');
      expect(fable.quota, 'fable_chat');
      expect(chat.model('auto')!.capability, isNull);
    });
    test('an unknown surface is null', () {
      expect(catalog.surface('glamour'), isNull);
    });
  });

  group('chatModelRow / chatModelLabel', () {
    test('unpicked stands in the default row', () {
      expect(chatModelRow(chat, null)?.id, 'auto');
      expect(chatModelLabel(chat, null), 'Auto');
    });
    test('a picked row is named by the catalog', () {
      expect(chatModelLabel(chat, 'opus-5-5'), 'Claude Opus 5.5');
    });
    test('an id the catalog does not list shows raw and has no row', () {
      expect(chatModelRow(chat, 'opus-4-8'), isNull);
      expect(chatModelLabel(chat, 'opus-4-8'), 'opus-4-8');
    });
    test('no catalog yet: nothing to say when unpicked', () {
      expect(chatModelLabel(null, null), isNull);
      expect(chatModelLabel(null, 'fable-5'), 'fable-5');
    });
  });

  group('modelAccess', () {
    AccessSnapshot access(bool premium) => AccessSnapshot(plan: Plan.basic, capabilities: [
          Capability.fromJson({'id': 'models.advanced', 'label': 'Advanced models', 'granted': true}),
          Capability.fromJson({'id': 'models.premium', 'label': 'Premium models', 'granted': premium, 'required_plan': 'pro'}),
        ]);
    test("reads the row's capability from the snapshot", () {
      expect(modelAccess(access(false), chat.model('fable-5')!).granted, isFalse);
      expect(modelAccess(access(true), chat.model('fable-5')!).granted, isTrue);
      expect(modelAccess(access(false), chat.model('opus-5-5')!).granted, isTrue);
    });
    test('a row with no capability, or no snapshot, is open', () {
      expect(modelAccess(access(false), chat.model('auto')!).granted, isTrue);
      expect(modelAccess(null, chat.model('fable-5')!).granted, isTrue);
    });
  });
}
