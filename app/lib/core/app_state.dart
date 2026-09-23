import 'package:flutter/foundation.dart';
import '../services/ai_service.dart';
import '../services/draft_store.dart';
import 'session.dart';

class AppState extends ChangeNotifier {
  AppState({required this.store, required this.ai});
  final DraftStore store;
  final AiService ai;
  List<StudioSession> _sessions = [];
  List<StudioSession> get sessions => List.unmodifiable(_sessions);
  String? storageWarning;
  bool _writesBlocked = false;
  Future<void> _writeQueue = Future.value();

  Future<void> load() async {
    try {
      _sessions = await store.read();
    } catch (_) {
      storageWarning =
          'Saved drafts could not be loaded. Restart before saving to avoid overwriting them.';
      _writesBlocked = true;
    }
    notifyListeners();
  }

  Future<void> connectAi() async {
    await ai.connect();
    notifyListeners();
  }

  Future<void> save(StudioSession session) {
    final operation = _writeQueue.then((_) async {
      if (_writesBlocked) throw StateError(storageWarning!);
      final next = [session, ..._sessions.where((s) => s.id != session.id)];
      await store.write(next);
      _sessions = next;
      notifyListeners();
    });
    _writeQueue = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> delete(String id) {
    final operation = _writeQueue.then((_) async {
      if (_writesBlocked) throw StateError(storageWarning!);
      final next = _sessions.where((s) => s.id != id).toList();
      await store.write(next);
      _sessions = next;
      notifyListeners();
    });
    _writeQueue = operation.catchError((Object _) {});
    return operation;
  }
}
