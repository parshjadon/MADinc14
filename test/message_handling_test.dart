import 'package:cloud_courier/fcm_service.dart';
import 'package:cloud_courier/main.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// These exercise widget behavior through service callbacks, not FCM delivery.
class FakeMessaging implements FCMService {
  void Function(RemoteMessage, String)? receive;
  RemoteMessage? initial;
  bool disposed = false;

  @override
  Future<void> initialize({
    required void Function(RemoteMessage, String) onData,
    required void Function(String) onStatus,
    required void Function(String) onPermission,
    required void Function(String) onToken,
  }) async {
    receive = onData;
    if (initial != null) onData(initial!, 'getInitialMessage');
    onPermission('authorized');
    onToken('test-token-never-shown');
    onStatus('Messaging ready');
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

RemoteMessage message({
  String id = 'valid-1',
  Map<String, dynamic> data = const {'action': 'update_ui', 'asset': 'promo'},
  String title = 'Campus event update',
}) => RemoteMessage(
  messageId: id,
  notification: RemoteNotification(title: title),
  data: data,
);

String displayedAsset(WidgetTester tester) =>
    (tester.widget<Image>(find.byKey(const Key('content-image'))).image
            as AssetImage)
        .assetName;

void main() {
  testWidgets(
    'valid receipt applies content and repeated payload increments receipt',
    (tester) async {
      final service = FakeMessaging();
      await tester.pumpWidget(MaterialApp(home: HomePage(service: service)));
      await tester.pumpAndSettle();
      expect(displayedAsset(tester), 'assets/images/default.png');
      service.receive!(message(), 'onMessage');
      await tester.pumpAndSettle();
      expect(find.text('Campus event update'), findsOneWidget);
      expect(displayedAsset(tester), 'assets/images/promo.png');
      expect(find.text('Last handler: onMessage'), findsOneWidget);
      expect(find.text('Messages handled this launch: 1'), findsOneWidget);
      service.receive!(message(id: 'valid-2'), 'onMessageOpenedApp');
      await tester.pumpAndSettle();
      expect(find.text('Last handler: onMessageOpenedApp'), findsOneWidget);
      expect(find.text('Messages handled this launch: 2'), findsOneWidget);
      expect(find.text('Last message ID: valid-2'), findsOneWidget);
      expect(find.text('test-token-never-shown'), findsNothing);
    },
  );

  testWidgets('invalid values preserve the previous title and image', (
    tester,
  ) async {
    final service = FakeMessaging();
    await tester.pumpWidget(MaterialApp(home: HomePage(service: service)));
    service.receive!(message(), 'onMessage');
    await tester.pumpAndSettle();
    final invalidCases = <Map<String, dynamic>>[
      {'action': 'update_ui', 'asset': 'unknown'},
      {'action': 'update_ui'},
      {'action': 'delete_all', 'asset': 'default'},
      {'action': 'update_ui', 'asset': 123},
    ];
    for (final data in invalidCases) {
      service.receive!(
        message(data: data, title: 'Must not replace title'),
        'onMessage',
      );
      await tester.pumpAndSettle();
      expect(find.text('Campus event update'), findsOneWidget);
      expect(find.text('Must not replace title'), findsNothing);
      expect(displayedAsset(tester), 'assets/images/promo.png');
      expect(find.textContaining('Rejected payload:'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    expect(find.text('Messages handled this launch: 5'), findsOneWidget);
  });

  testWidgets(
    'cold-start callback is retained and late callbacks are safe after disposal',
    (tester) async {
      final service = FakeMessaging()..initial = message(id: 'cold-start');
      await tester.pumpWidget(MaterialApp(home: HomePage(service: service)));
      await tester.pumpAndSettle();
      expect(find.text('Last handler: getInitialMessage'), findsOneWidget);
      expect(find.text('Messages handled this launch: 1'), findsOneWidget);
      expect(displayedAsset(tester), 'assets/images/promo.png');
      await tester.pumpWidget(const SizedBox.shrink());
      service.receive!(message(), 'onMessage');
      await tester.pumpAndSettle();
      expect(service.disposed, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
