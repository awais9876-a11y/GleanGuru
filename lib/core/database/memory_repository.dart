import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// A single unit of the user's knowledge bank: one chat turn, or one
/// directly-taught fact.
class MemoryEntry {
  final String id;
  final String role; // 'user' | 'assistant' | 'fact'
  final String content;
  final DateTime createdAt;

  const MemoryEntry({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'role': role,
        'content': content,
        // serverTimestamp() can't be used for values we also read back
        // immediately in the same optimistic UI update, but we still want
        // Firestore's clock (not the client's, which can be skewed) as the
        // source of truth for ordering once it round-trips.
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory MemoryEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final ts = data['createdAt'];
    return MemoryEntry(
      id: doc.id,
      role: data['role'] as String? ?? 'user',
      content: data['content'] as String? ?? '',
      createdAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
    );
  }

  /// Format expected by QwenService / the Dashscope chat-completions
  /// contract: {"role": ..., "content": ...}.
  Map<String, dynamic> toApiMessage() => {'role': role, 'content': content};
}

/// Persists the user's growing knowledge bank to Cloud Firestore, scoped
/// per-user under `users/{uid}/memories/{entryId}`.
///
/// This is intentionally Firestore-backed rather than SQLite-backed
/// (compare LocalDatabase): Firestore has a real Flutter Web SDK, so this
/// is what actually persists across a page refresh / new browser session
/// on the Vercel and Alibaba OSS deployments - the two targets this
/// project ships to. SQLite (via sqflite) has no browser implementation
/// and is skipped entirely on web.
///
/// Every method fails soft: if Firestore isn't available (Firebase never
/// initialized - see main.dart's firebaseAvailable check) or a call
/// errors for any other reason (offline, permission-denied, etc.), methods
/// log and return an empty/no-op result rather than throwing, so a memory
/// outage degrades the app to "chat works, nothing is saved this session"
/// instead of crashing it.
class MemoryRepository {
  final FirebaseFirestore? _firestore;

  MemoryRepository({FirebaseFirestore? firestore}) : _firestore = firestore;

  bool get isAvailable => _firestore != null;

  /// Generates a new unique entry ID. Uses Firestore's client-side ID
  /// generator (works fully offline, no network round-trip needed) when
  /// available, otherwise falls back to a timestamp-based ID so callers
  /// can still construct a MemoryEntry when Firestore isn't configured.
  String newId() {
    final db = _firestore;
    if (db != null) return db.collection('_').doc().id;
    return 'local-${DateTime.now().microsecondsSinceEpoch}';
  }

  CollectionReference<Map<String, dynamic>>? _collectionFor(String userId) {
    final db = _firestore;
    if (db == null) return null;
    return db.collection('users').doc(userId).collection('memories');
  }

  /// One-shot fetch of the most recent [limit] entries, oldest-first (the
  /// order a chat transcript / LLM context window expects).
  Future<List<MemoryEntry>> loadRecentHistory(
    String userId, {
    int limit = 50,
  }) async {
    final collection = _collectionFor(userId);
    if (collection == null) return [];

    try {
      final snapshot = await collection
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return snapshot.docs.map(MemoryEntry.fromDoc).toList().reversed.toList();
    } catch (e) {
      debugPrint('MemoryRepository.loadRecentHistory failed: $e');
      return [];
    }
  }

  /// Appends one entry (a user message, an assistant reply, or a
  /// directly-taught fact) to this user's permanent knowledge bank.
  Future<void> addEntry(String userId, MemoryEntry entry) async {
    final collection = _collectionFor(userId);
    if (collection == null) return;

    try {
      await collection.doc(entry.id).set(entry.toMap());
    } catch (e) {
      debugPrint('MemoryRepository.addEntry failed: $e');
      // Intentionally swallowed: the caller already has the entry in its
      // in-memory state for this session; a failed write means it just
      // won't survive a refresh, which is a soft degradation, not a crash.
    }
  }

  /// Appends several entries as a single atomic batch (used after a chat
  /// turn, to write the user's message and the assistant's reply together).
  Future<void> addEntries(String userId, List<MemoryEntry> entries) async {
    final collection = _collectionFor(userId);
    if (collection == null || entries.isEmpty) return;

    try {
      final batch = _firestore!.batch();
      for (final entry in entries) {
        batch.set(collection.doc(entry.id), entry.toMap());
      }
      await batch.commit();
    } catch (e) {
      debugPrint('MemoryRepository.addEntries failed: $e');
    }
  }

  /// Permanently deletes this user's entire knowledge bank ("forget
  /// everything"). Deletes in batches of 400 to stay under Firestore's
  /// 500-writes-per-batch limit.
  Future<void> clearHistory(String userId) async {
    final collection = _collectionFor(userId);
    if (collection == null) return;

    try {
      QuerySnapshot<Map<String, dynamic>> snapshot;
      do {
        snapshot = await collection.limit(400).get();
        if (snapshot.docs.isEmpty) break;
        final batch = _firestore!.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      } while (snapshot.docs.length == 400);
    } catch (e) {
      debugPrint('MemoryRepository.clearHistory failed: $e');
    }
  }
}
