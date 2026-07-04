import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'local_database.dart';
import '../network/sync_api_contract.dart';

/// Offline-First Sync Engine
/// Manages bidirectional synchronization between local SQLite and remote PostgreSQL
class SyncEngine {
  final LocalDatabase _localDatabase;
  final SyncApiContract _apiClient;
  final StreamController<SyncStatus> _statusController = StreamController.broadcast();
  
  bool _isSyncing = false;
  bool _isOnline = true;
  Timer? _retryTimer;
  
  static const int _maxRetryCount = 5;
  static const Duration _retryDelay = Duration(seconds: 30);
  
  SyncEngine({
    required LocalDatabase localDatabase,
    required SyncApiContract apiClient,
  })  : _localDatabase = localDatabase,
        _apiClient = apiClient;
  
  /// Stream of sync status updates
  Stream<SyncStatus> get syncStatusStream => _statusController.stream;
  
  /// Initialize sync engine and start monitoring
  Future<void> initialize() async {
    _emitStatus(SyncStatus.initializing);
  }
  
  /// Set online/offline status
  void setConnectionStatus(bool isOnline) {
    _isOnline = isOnline;
    if (isOnline && !_isSyncing) {
      _processSyncQueue();
    }
  }
  
  /// Add operation to sync queue
  Future<void> enqueueOperation({
    required String operationType,
    required String tableName,
    required String recordId,
    required Map<String, dynamic> payload,
  }) async {
    final id = _generateId();
    final now = DateTime.now().millisecondsSinceEpoch;
    
    await _localDatabase.insert('sync_queue', {
      'id': id,
      'operation_type': operationType,
      'table_name': tableName,
      'record_id': recordId,
      'payload': jsonEncode(payload),
      'retry_count': 0,
      'created_at': now,
      'last_attempt_at': null,
      'status': 'pending',
    });
    
    _emitStatus(SyncStatus.pendingChanges);
    
    // If online and not currently syncing, process immediately
    if (_isOnline && !_isSyncing) {
      unawaited(_processSyncQueue());
    }
  }
  
  /// Process pending sync operations
  Future<void> _processSyncQueue() async {
    if (_isSyncing) return;
    
    _isSyncing = true;
    _emitStatus(SyncStatus.syncing);
    
    try {
      while (_isOnline) {
        final pendingOperations = await _getPendingOperations();
        
        if (pendingOperations.isEmpty) {
          _emitStatus(SyncStatus.synced);
          break;
        }
        
        for (final operation in pendingOperations) {
          if (!_isOnline) break;
          
          final success = await _executeOperation(operation);
          
          if (success) {
            await _removeFromQueue(operation['id'] as String);
          } else {
            await _incrementRetryCount(operation['id'] as String);
          }
        }
        
        // Small delay between batches
        await Future.delayed(const Duration(milliseconds: 100));
      }
    } catch (e) {
      _emitStatus(SyncStatus.error('Sync failed: $e'));
      _scheduleRetry();
    } finally {
      _isSyncing = false;
    }
  }
  
  /// Get pending operations from queue
  Future<List<Map<String, dynamic>>> _getPendingOperations() async {
    return await _localDatabase.query(
      'sync_queue',
      where: 'status = ? AND retry_count < ?',
      whereArgs: ['pending', _maxRetryCount],
      orderBy: 'created_at ASC',
      limit: 50,
    );
  }
  
  /// Execute a single sync operation
  Future<bool> _executeOperation(Map<String, dynamic> operation) async {
    final operationType = operation['operation_type'] as String;
    final tableName = operation['table_name'] as String;
    final recordId = operation['record_id'] as String;
    final payload = jsonDecode(operation['payload'] as String) as Map<String, dynamic>;
    
    try {
      // Update last attempt timestamp
      await _localDatabase.update(
        'sync_queue',
        {'last_attempt_at': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [operation['id']],
      );
      
      bool success;
      switch (operationType) {
        case 'INSERT':
          success = await _apiClient.createRecord(
            tableName,
            payload,
          );
          break;
        case 'UPDATE':
          success = await _apiClient.updateRecord(
            tableName,
            recordId,
            payload,
          );
          break;
        case 'DELETE':
          success = await _apiClient.deleteRecord(
            tableName,
            recordId,
          );
          break;
        default:
          success = false;
      }
      
      if (success) {
        // Mark local record as synced
        await _localDatabase.update(
          tableName,
          {'is_synced': 1},
          where: 'id = ?',
          whereArgs: [recordId],
        );
      }
      
      return success;
    } catch (e) {
      return false;
    }
  }
  
  /// Remove operation from queue after successful sync
  Future<void> _removeFromQueue(String id) async {
    await _localDatabase.delete(
      'sync_queue',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  /// Increment retry count for failed operation
  Future<void> _incrementRetryCount(String id) async {
    final existing = await _localDatabase.query(
      'sync_queue',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (existing.isNotEmpty) {
      final currentRetry = existing.first['retry_count'] as int? ?? 0;
      
      if (currentRetry >= _maxRetryCount) {
        // Mark as failed permanently
        await _localDatabase.update(
          'sync_queue',
          {'status': 'failed'},
          where: 'id = ?',
          whereArgs: [id],
        );
        _emitStatus(SyncStatus.error('Operation failed after max retries'));
      } else {
        await _localDatabase.update(
          'sync_queue',
          {'retry_count': currentRetry + 1},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    }
  }
  
  /// Schedule retry after delay
  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(_retryDelay, () {
      if (_isOnline && !_isSyncing) {
        unawaited(_processSyncQueue());
      }
    });
  }
  /// Pull latest data from server
  Future<void> pullLatestData(String userId) async {
    if (!_isOnline) return;
    
    try {
      _emitStatus(SyncStatus.downloading);
      
      // Fetch latest memory nodes
      final nodes = await _apiClient.getMemoryNodes(userId);
      for (final node in nodes) {
        await _upsertLocalRecord('memory_nodes', node);
      }
      
      // Fetch latest edges
      final edges = await _apiClient.getMemoryEdges(userId);
      for (final edge in edges) {
        await _upsertLocalRecord('memory_edges', edge);
      }
      
      _emitStatus(SyncStatus.synced);
    } catch (e) {
      _emitStatus(SyncStatus.error('Pull failed: $e'));
    }
  }
  
  /// Upsert record locally (insert or update)
  Future<void> _upsertLocalRecord(String table, Map<String, dynamic> record) async {
    final existing = await _localDatabase.query(
      table,
      where: 'id = ?',
      whereArgs: [record['id']],
    );
    
    if (existing.isEmpty) {
      await _localDatabase.insert(table, record);
    } else {
      await _localDatabase.update(
        table,
        record,
        where: 'id = ?',
        whereArgs: [record['id']],
      );
    }
  }
  
  /// Generate unique ID
  String _generateId() {
    final random = math.Random.secure();
    final timestamp = DateTime.now().millisecondsSinceEpoch.toRadixString(16);
    final randomPart = List.generate(8, (_) => random.nextInt(16).toRadixString(16)).join();
    return '$timestamp-$randomPart';
  }
  
  /// Emit status update
  void _emitStatus(SyncStatus status) {
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }
  
  /// Dispose resources
  void dispose() {
    _retryTimer?.cancel();
    _statusController.close();
  }
}

/// Sync status states
class SyncStatus {
  final String state;
  final String? message;
  
  const SyncStatus._(this.state, this.message);
  
  static const initializing = SyncStatus._('initializing', null);
  static const synced = SyncStatus._('synced', null);
  static const syncing = SyncStatus._('syncing', 'Synchronizing...');
  static const pendingChanges = SyncStatus._('pending', 'Pending changes');
  static const downloading = SyncStatus._('downloading', 'Downloading updates...');
  static SyncStatus error(String msg) => SyncStatus._('error', msg);
  
  @override
  String toString() => message ?? state;
}

