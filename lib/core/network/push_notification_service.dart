import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Push Notification Service for FCM/APNs
/// Handles background messages, notification display, and custom actions
class PushNotificationService {
  final FirebaseMessaging _messaging;
  final StreamController<RemoteMessage> _messageController = StreamController.broadcast();
  
  String? _fcmToken;
  Function(RemoteMessage)? _onForegroundMessageHandler;
  
  PushNotificationService({FirebaseMessaging? messaging})
      : _messaging = messaging ?? FirebaseMessaging.instance;
  
  /// Initialize push notification service
  Future<void> initialize() async {
    // Request permission
    await _requestPermission();
    
    // Get FCM token
    await _refreshFcmToken();
    
    // Setup foreground message handler
    _setupForegroundHandler();
    
    // Handle initial message (if app was opened from notification)
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessage(initialMessage);
    }
    
    // Listen for token refresh
    _messaging.onTokenRefresh.listen((newToken) {
      _fcmToken = newToken;
      debugPrint('FCM token refreshed: $newToken');
    });
  }
  
  /// Request notification permissions
  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
    );
    
    debugPrint('Notification permission status: ${settings.authorizationStatus}');
  }
  
  /// Refresh FCM token
  Future<void> _refreshFcmToken() async {
    try {
      _fcmToken = await _messaging.getToken();
      debugPrint('FCM Token: $_fcmToken');
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }
  }
  
  /// Setup foreground message handler
  void _setupForegroundHandler() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Received foreground message: ${message.messageId}');
      _handleMessage(message);
    });
  }
  
  /// Setup background message handler
  static void setupBackgroundHandler(Function(RemoteMessage) handler) {
    FirebaseMessaging.onBackgroundMessage((message) async {
      debugPrint('Received background message: ${message.messageId}');
      handler(message);
    });
  }
  
  /// Handle incoming message
  void _handleMessage(RemoteMessage message) {
    // Emit to stream for UI consumption
    if (!_messageController.isClosed) {
      _messageController.add(message);
    }
    
    // Call custom handler if set
    _onForegroundMessageHandler?.call(message);
    
    // Parse custom action from data payload
    final action = message.data['action'];
    if (action != null) {
      _handleCustomAction(action, message.data);
    }
  }
  
  /// Handle custom notification actions
  void _handleCustomAction(String action, Map<String, dynamic> data) {
    switch (action) {
      case 'open_memory':
        // Navigate to specific memory node
        break;
      case 'sync_complete':
        // Handle sync completion
        break;
      case 'security_alert':
        // Handle security notification
        break;
      default:
        debugPrint('Unknown action: $action');
    }
  }
  
  /// Stream of received messages
  Stream<RemoteMessage> get messageStream => _messageController.stream;
  
  /// Get current FCM token
  String? get fcmToken => _fcmToken;
  
  /// Set foreground message handler
  void setForegroundHandler(Function(RemoteMessage) handler) {
    _onForegroundMessageHandler = handler;
  }
  
  /// Subscribe to topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      debugPrint('Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('Error subscribing to topic: $e');
    }
  }
  
  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      debugPrint('Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('Error unsubscribing from topic: $e');
    }
  }
  
  /// Delete FCM token (for logout)
  Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();
      _fcmToken = null;
      debugPrint('FCM token deleted');
    } catch (e) {
      debugPrint('Error deleting token: $e');
    }
  }
  
  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }
  
  /// Dispose resources
  void dispose() {
    _messageController.close();
  }
}

/// Background message handler wrapper for Flutter
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling background message: ${message.messageId}');
  // Add custom background handling logic here
}
