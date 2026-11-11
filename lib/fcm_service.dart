import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Owns one set of messaging listeners for the lifetime of the home page.
class FCMService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  StreamSubscription<RemoteMessage>? _foreground;
  StreamSubscription<RemoteMessage>? _opened;
  StreamSubscription<String>? _tokenRefresh;
  bool _started = false;
  bool _disposed = false;

  Future<void> initialize({
    required void Function(RemoteMessage, String) onData,
    required void Function(String) onStatus,
    required void Function(String) onPermission,
    required void Function(String) onToken,
  }) async {
    if (_started || _disposed) {
      throw StateError('Initialize a fresh FCMService exactly once.');
    }
    _started = true;

    void receive(RemoteMessage message, String source) {
      if (!_disposed) onData(message, source);
    }

    void streamError(Object error, StackTrace stack) {
      debugPrint('FCM stream error: $error\n$stack');
      if (!_disposed) onStatus('Messaging stream error: $error');
    }

    _foreground = FirebaseMessaging.onMessage.listen(
      (message) => receive(message, 'onMessage'),
      onError: streamError,
    );
    _opened = FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => receive(message, 'onMessageOpenedApp'),
      onError: streamError,
    );

    // Consume a notification-triggered cold start after the widget owns callbacks.
    final initial = await _messaging.getInitialMessage();
    if (_disposed) return;
    if (initial != null) receive(initial, 'getInitialMessage');

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (_disposed) return;
    onPermission(settings.authorizationStatus.name);

    _tokenRefresh = _messaging.onTokenRefresh.listen((token) {
      if (_disposed) return;
      onToken(token);
      onStatus('Token refreshed. Use the current token for the next send.');
    }, onError: streamError);

    final token = await _messaging.getToken();
    if (_disposed) return;
    if (token == null) {
      throw StateError(
        'No registration token. Check Google Play services and network.',
      );
    }
    // Keep the full token out of logs and submitted evidence.
    onToken(token);
    onStatus('Messaging ready · token available');
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await Future.wait([
      if (_foreground != null) _foreground!.cancel(),
      if (_opened != null) _opened!.cancel(),
      if (_tokenRefresh != null) _tokenRefresh!.cancel(),
    ]);
  }
}
