import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'fcm_service.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Android invokes this in a separate isolate. Never touch widget state here.
  debugPrint('onBackgroundMessage: ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  runApp(const CloudCourierApp());
}

class CloudCourierApp extends StatelessWidget {
  const CloudCourierApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cloud Courier',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff087e8b)),
        scaffoldBackgroundColor: const Color(0xfff3f7f8),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.service});

  final FCMService? service;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final FCMService _service = widget.service ?? FCMService();
  static const _assets = {
    'default': 'assets/images/default.png',
    'promo': 'assets/images/promo.png',
  };
  String _title = 'Your campus, connected';
  String _image = _assets['default']!;
  String _feedback = 'Waiting for a cloud message.';
  String _permission = 'Checking…';
  String _connection = 'Initializing messaging…';
  String _handler = 'None yet';
  String _messageId = 'None yet';
  String? _token;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      await _service.initialize(
        onData: _receive,
        onStatus: (value) {
          if (mounted) setState(() => _connection = value);
        },
        onPermission: (value) {
          if (mounted) setState(() => _permission = value);
        },
        onToken: (value) {
          if (mounted) setState(() => _token = value);
        },
      );
    } catch (error, stack) {
      debugPrint('Messaging initialization failed: $error\n$stack');
      if (mounted) {
        setState(() => _connection = 'Messaging setup failed: $error');
      }
    }
  }

  void _receive(RemoteMessage message, String handler) {
    if (!mounted) return;
    final asset = message.data['asset'];
    final path = asset is String ? _assets[asset] : null;
    final valid = message.data['action'] == 'update_ui' && path != null;
    setState(() {
      _handler = handler;
      _messageId = message.messageId ?? '(no ID)';
      _count++;
      if (valid) {
        _title = message.notification?.title ?? 'Campus update received';
        _image = path;
        _feedback = 'Applied payload: asset=$asset.';
      } else {
        _feedback =
            'Rejected payload: use action=update_ui and '
            'asset=default or asset=promo. Previous title/image preserved.';
      }
    });
    debugPrint(
      '$handler: ${message.messageId}; ${valid ? "applied" : "rejected"}',
    );
  }

  Future<void> _copyToken() async {
    final token = _token;
    if (token == null) return;
    await Clipboard.setData(ClipboardData(text: token));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Current token copied for the test sender.'),
      ),
    );
  }

  @override
  void dispose() {
    unawaited(
      _service.dispose().catchError((Object error, StackTrace stack) {
        debugPrint('Messaging cleanup failed: $error\n$stack');
      }),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cloud Courier'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(
            'CAMPUS UPDATES · ACTIVITY 14',
            style: theme.textTheme.labelMedium,
          ),
          const SizedBox(height: 8),
          Text(
            _title,
            key: const Key('content-title'),
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              _image,
              key: const Key('content-image'),
              height: 150,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) =>
                  Text('Cannot load $_image. Check the bundled assets.'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Delivery receipt', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text('Last handler: $_handler'),
                  Text('Messages handled this launch: $_count'),
                  Text('Last message ID: $_messageId'),
                  const Divider(),
                  Text(_feedback, key: const Key('payload-feedback')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('Permission: $_permission'),
          Text(_connection),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _token == null ? null : _copyToken,
              icon: const Icon(Icons.copy, size: 18),
              label: Text(
                _token == null ? 'Waiting for token' : 'Copy current FCM token',
              ),
            ),
          ),
          const Text(
            'The token stays hidden in screenshots. Tap a delivered '
            'notification to apply an update from the background.',
          ),
        ],
      ),
    );
  }
}
