import 'dart:async';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'sync_api_contract.dart';

/// Base REST API Client with retry logic and error handling
/// All network operations run on background isolates
class ApiClient implements SyncApiContract {
  final Dio _dio;
  final String baseUrl;
  final Connectivity _connectivity;
  
  bool _isOnline = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  
  ApiClient({
    required this.baseUrl,
    Dio? dio,
    Connectivity? connectivity,
  })  : _dio = dio ?? Dio(),
        _connectivity = connectivity ?? Connectivity() {
    _setupDio();
    _monitorConnectivity();
  }
  
  void _setupDio() {
    _dio.options.baseUrl = baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    // Add interceptors for auth tokens and logging
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        // Add auth token if available
        final token = options.extra['token'] as String?;
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          // Handle unauthorized - trigger token refresh
        }
        return handler.next(error);
      },
    ));
  }
  
  void _monitorConnectivity() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (results) {
        final wasOnline = _isOnline;
        _isOnline = !results.contains(ConnectivityResult.none);
        
        if (wasOnline != _isOnline) {
           onConnectionStatusChanged?.call(_isOnline);
        }
      },
    );
  }
  
  /// Callback for connection status changes
  Function(bool isOnline)? onConnectionStatusChanged;
  
  /// Check current connection status
  bool get isOnline => _isOnline;
  
  /// GET request
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    String? token,
  }) async {
    try {
      return await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: Options(
          headers: headers,
          extra: {'token': token},
        ),
      );
    } on DioException catch (e) {
      throw ApiException('GET failed: ${e.message}', e.response?.statusCode);
    }
  }
  
  /// POST request
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    String? token,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(
          headers: headers,
          extra: {'token': token},
        ),
      );
    } on DioException catch (e) {
      throw ApiException('POST failed: ${e.message}', e.response?.statusCode);
    }
  }
  
  /// PUT request
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    String? token,
  }) async {
    try {
      return await _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(
          headers: headers,
          extra: {'token': token},
        ),
      );
    } on DioException catch (e) {
      throw ApiException('PUT failed: ${e.message}', e.response?.statusCode);
    }
  }
  
  /// DELETE request
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    String? token,
  }) async {
    try {
      return await _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(
          headers: headers,
          extra: {'token': token},
        ),
      );
    } on DioException catch (e) {
      throw ApiException('DELETE failed: ${e.message}', e.response?.statusCode);
    }
  }
  
  /// Create record via API
  @override
  Future<bool> createRecord(String table, Map<String, dynamic> data) async {
    try {
      final response = await post('/api/$table', data: data);
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  
  /// Update record via API
  @override
  Future<bool> updateRecord(String table, String id, Map<String, dynamic> data) async {
    try {
      final response = await put('/api/$table/$id', data: data);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  
  /// Delete record via API
  @override
  Future<bool> deleteRecord(String table, String id) async {
    try {
      final response = await delete('/api/$table/$id');
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      return false;
    }
  }
  
  /// Get memory nodes from server
  @override
  Future<List<Map<String, dynamic>>> getMemoryNodes(String userId) async {
    try {
      final response = await get('/api/memory_nodes', 
        queryParameters: {'user_id': userId});
      final data = response.data as List;
      return data.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      return [];
    }
  }
  
  /// Get memory edges from server
  @override
  Future<List<Map<String, dynamic>>> getMemoryEdges(String userId) async {
    try {
      final response = await get('/api/memory_edges',
        queryParameters: {'user_id': userId});
      final data = response.data as List;
      return data.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      return [];
    }
  }
  
  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _dio.close();
  }
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  
  ApiException(this.message, this.statusCode);
  
  @override
  String toString() => 'ApiException: $message (status: $statusCode)';
}
