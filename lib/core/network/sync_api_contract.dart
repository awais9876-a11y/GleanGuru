/// Contract implemented by any network client that the [SyncEngine] can use
/// to push/pull data to the remote backend.
///
/// This lives in its own file (rather than being declared inline inside
/// `sync_engine.dart` or `api_client.dart`) so both files can import a single
/// shared definition without creating a duplicate-class-name collision.
abstract class SyncApiContract {
  Future<bool> createRecord(String table, Map<String, dynamic> data);
  Future<bool> updateRecord(String table, String id, Map<String, dynamic> data);
  Future<bool> deleteRecord(String table, String id);
  Future<List<Map<String, dynamic>>> getMemoryNodes(String userId);
  Future<List<Map<String, dynamic>>> getMemoryEdges(String userId);
}
