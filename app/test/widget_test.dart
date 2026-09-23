import 'package:appcon_starter/main.dart';
import 'package:appcon_starter/core/app_state.dart';
import 'package:appcon_starter/core/session.dart';
import 'package:appcon_starter/services/ai_service.dart';
import 'package:appcon_starter/services/draft_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryStore implements DraftStore {
  List<StudioSession> data = [];
  bool fail = false;
  @override
  Future<List<StudioSession>> read() async => List.of(data);
  @override
  Future<void> write(List<StudioSession> sessions) async {
    if (fail) throw StateError('storage unavailable');
    data = List.of(sessions);
  }
}

class DisconnectedAi implements AiService {
  int calls = 0;
  @override
  bool get ready => false;
  @override
  String get status => 'Firebase project needed';
  @override
  Future<void> connect() async {}
  @override
  Future<AiAnswer> generate(String task, String input) async {
    calls++;
    throw StateError('not configured');
  }
}

class ConnectableAi extends DisconnectedAi {
  bool connected = false;
  @override
  bool get ready => connected;
  @override
  Future<void> connect() async {
    connected = true;
  }
}

void main() {
  testWidgets('An open session updates when AI configuration finishes',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final state = AppState(store: MemoryStore(), ai: ConnectableAi());
    await tester.pumpWidget(MatsuriApp(state: state));
    await tester.ensureVisible(find.text('Start a session'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start a session'));
    await tester.pumpAndSettle();
    expect(find.text('Connect AI to generate'), findsOneWidget);
    await state.connectAi();
    await tester.pumpAndSettle();
    expect(find.text('Generate with AI'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Generate with AI'))
            .onPressed,
        isNotNull);
  });
  testWidgets(
      'Phone workflow saves, reopens and deletes a local draft without AI',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = MemoryStore();
    final ai = DisconnectedAi();
    final state = AppState(store: store, ai: ai);
    await state.load();
    await tester.pumpWidget(MatsuriApp(state: state));
    await tester.ensureVisible(find.text('Start a session'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start a session'));
    await tester.pumpAndSettle();
    expect(find.text('Connect AI to generate'), findsOneWidget);
    final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Connect AI to generate'));
    expect(button.onPressed, isNull);
    await tester.enterText(find.byType(TextField),
        'Help make a confusing public notice easier to understand.');
    await tester.ensureVisible(find.text('Save draft'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save draft'));
    await tester.pumpAndSettle();
    expect(state.sessions, hasLength(1));
    expect(store.data.single.input, contains('public notice'));
    expect(ai.calls, 0);
    await tester.tap(find.text('Sessions'));
    await tester.pumpAndSettle();
    await tester.tap(
        find.text('Help make a confusing public notice easier to understand.'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        contains('public notice'));
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete session'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(state.sessions, isEmpty);
    expect(store.data, isEmpty);
    expect(find.text('A clean slate.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('Updating a session preserves one record and survives reload', () async {
    final store = MemoryStore();
    final state = AppState(store: store, ai: DisconnectedAi());
    final date = DateTime(2026, 9, 18);
    await state.save(StudioSession(
        id: 'a', task: 'Explore an idea', input: 'original', createdAt: date));
    await state.save(StudioSession(
        id: 'a', task: 'Explore an idea', input: 'updated', createdAt: date));
    final restored = AppState(store: store, ai: DisconnectedAi());
    await restored.load();
    expect(restored.sessions, hasLength(1));
    expect(restored.sessions.single.input, 'updated');
  });

  test('A failed save keeps existing sessions and later writes still work',
      () async {
    final store = MemoryStore();
    final state = AppState(store: store, ai: DisconnectedAi());
    final date = DateTime(2026, 9, 18);
    await state.save(StudioSession(
        id: 'a', task: 'Explore an idea', input: 'keep me', createdAt: date));
    store.fail = true;
    await expectLater(
        state.save(StudioSession(
            id: 'b', task: 'Simplify text', input: 'new', createdAt: date)),
        throwsStateError);
    expect(state.sessions.single.id, 'a');
    store.fail = false;
    await state.save(StudioSession(
        id: 'c', task: 'Simplify text', input: 'retry', createdAt: date));
    expect(state.sessions.map((s) => s.id), ['c', 'a']);
  });
}
