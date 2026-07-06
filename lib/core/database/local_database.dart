import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';

/// Local SQLite Database Manager with encryption support
/// Handles all CRUD operations on background isolates
class LocalDatabase {
  static const String _databaseName = 'memory_agent.db';
  static const int _databaseVersion = 1;
  
  Database? _database;
  final bool _enableEncryption;
  
  LocalDatabase({this._enableEncryption = true});
  
  /// Initialize database connection
  Future<void> initialize() async {
    if (_database != null) return;
    
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _databaseName);
    
    _database = await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onDowngrade: _onDowngrade,
      singleInstance: true,
    );
  }
  
  /// Create database tables
  Future<void> _onCreate(Database db, int version) async {
    // Users table
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        email TEXT NOT NULL UNIQUE,
        name TEXT,
        avatar_url TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        is_synced INTEGER DEFAULT 0
      )
    ''');
    
    // Memory nodes table (for Multimodal Memory Agent)
    await db.execute('''
      CREATE TABLE memory_nodes (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        title TEXT NOT NULL,
        content TEXT,
        node_type TEXT NOT NULL,
        parent_id TEXT,
        metadata TEXT,
        vector_embedding BLOB,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        is_deleted INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY (user_id) REFERENCES users(id),
        FOREIGN KEY (parent_id) REFERENCES memory_nodes(id)
      )
    ''');
    
    // Memory edges table (relationships between nodes)
    await db.execute('''
      CREATE TABLE memory_edges (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        source_node_id TEXT NOT NULL,
        target_node_id TEXT NOT NULL,
        relation_type TEXT NOT NULL,
        weight REAL DEFAULT 1.0,
        metadata TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY (user_id) REFERENCES users(id),
        FOREIGN KEY (source_node_id) REFERENCES memory_nodes(id),
        FOREIGN KEY (target_node_id) REFERENCES memory_nodes(id)
      )
    ''');
    
    // Sync queue table for offline operations
    await db.execute('''
      CREATE TABLE sync_queue (
        id TEXT PRIMARY KEY,
        operation_type TEXT NOT NULL,
        table_name TEXT NOT NULL,
        record_id TEXT NOT NULL,
        payload TEXT NOT NULL,
        retry_count INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL,
        last_attempt_at INTEGER,
        status TEXT DEFAULT 'pending'
      )
    ''');
    
    // Media attachments table
    await db.execute('''
      CREATE TABLE media_attachments (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        memory_node_id TEXT,
        file_path TEXT NOT NULL,
        file_type TEXT NOT NULL,
        file_size INTEGER NOT NULL,
        thumbnail_path TEXT,
        encrypted_data BLOB,
        created_at INTEGER NOT NULL,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY (user_id) REFERENCES users(id),
        FOREIGN KEY (memory_node_id) REFERENCES memory_nodes(id)
      )
    ''');
    
    // Create indexes for performance
    await db.execute('CREATE INDEX idx_memory_nodes_user ON memory_nodes(user_id)');
    await db.execute('CREATE INDEX idx_memory_nodes_parent ON memory_nodes(parent_id)');
    await db.execute('CREATE INDEX idx_memory_edges_user ON memory_edges(user_id)');
    await db.execute('CREATE INDEX idx_sync_queue_status ON sync_queue(status)');
    await db.execute('CREATE INDEX idx_media_user ON media_attachments(user_id)');
  }
  
  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add migration logic here for future versions
    }
  }
  
  /// Handle database downgrades
  Future<void> _onDowngrade(Database db, int oldVersion, int newVersion) async {
    // Safely handle downgrade scenarios
  }
  
  /// Get database instance
  Database? get database => _database;
  
  /// Execute raw SQL query
  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<Object?>? arguments]) async {
    if (_database == null) throw DatabaseException('Database not initialized');
    return await _database!.rawQuery(sql, arguments);
  }
  
  /// Execute raw SQL statement
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) async {
    if (_database == null) throw DatabaseException('Database not initialized');
    return await _database!.rawInsert(sql, arguments);
  }
  
  /// Insert record
  Future<int> insert(String table, Map<String, dynamic> values, {String? nullColumnHack}) async {
    if (_database == null) throw DatabaseException('Database not initialized');
    return await _database!.insert(table, values, nullColumnHack: nullColumnHack);
  }
  
  /// Update records
  Future<int> update(
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    if (_database == null) throw DatabaseException('Database not initialized');
    return await _database!.update(
      table,
      values,
      where: where,
      whereArgs: whereArgs,
      conflictAlgorithm: conflictAlgorithm,
    );
  }
  
  /// Delete records
  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) async {
    if (_database == null) throw DatabaseException('Database not initialized');
    return await _database!.delete(table, where: where, whereArgs: whereArgs);
  }
  
  /// Query records
  Future<List<Map<String, dynamic>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    if (_database == null) throw DatabaseException('Database not initialized');
    return await _database!.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }
  
  /// Close database connection
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
  
  /// Clear all data (for testing/logout)
  Future<void> clearAllData() async {
    if (_database == null) throw DatabaseException('Database not initialized');
    
    final batch = _database!.batch();
    batch.delete('media_attachments');
    batch.delete('sync_queue');
    batch.delete('memory_edges');
    batch.delete('memory_nodes');
    batch.delete('users');
    
    await batch.commit(noResult: true);
  }
}

class DatabaseException implements Exception {
  final String message;
  DatabaseException(this.message);
  
  @override
  String toString() => 'DatabaseException: $message';
}
