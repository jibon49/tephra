// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/core/platform/storage_permission_service.dart';
import 'package:tephra/vault/storage_access_screen.dart';

import '../helpers/test_app.dart';

final class FakeStoragePermissionService implements StoragePermissionService {
  StorageAccess currentStatus = StorageAccess.denied;
  int requestCalls = 0;
  int openSettingsCalls = 0;

  @override
  Future<StorageAccess> status() async => currentStatus;

  @override
  Future<StorageAccess> request() async {
    requestCalls++;
    return currentStatus;
  }

  @override
  Future<void> openSystemSettings() async {
    openSettingsCalls++;
  }
}

void main() {
  testWidgets('shows three buttons and Allow access triggers request()', (
    tester,
  ) async {
    final fake = FakeStoragePermissionService();
    dynamic popResult;

    await tester.pumpWidget(
      testApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              popResult = await Navigator.of(context).push(
                MaterialPageRoute<dynamic>(
                  builder: (_) => StorageAccessScreen(service: fake),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('storageAccess.allow')), findsOneWidget);
    expect(find.byKey(const Key('storageAccess.private')), findsOneWidget);
    expect(find.byKey(const Key('storageAccess.notNow')), findsOneWidget);

    // Tap allow access
    await tester.tap(find.byKey(const Key('storageAccess.allow')));
    await tester.pumpAndSettle();
    expect(fake.requestCalls, equals(1));
    expect(popResult, isNull); // Still open since status was denied

    // On resume with granted pops true
    fake.currentStatus = StorageAccess.granted;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(popResult, isTrue);
  });

  testWidgets('Use app storage button pops private', (tester) async {
    final fake = FakeStoragePermissionService();
    dynamic popResult;

    await tester.pumpWidget(
      testApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              popResult = await Navigator.of(context).push(
                MaterialPageRoute<dynamic>(
                  builder: (_) => StorageAccessScreen(service: fake),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('storageAccess.private')));
    await tester.pumpAndSettle();
    expect(popResult, equals('private'));
  });

  testWidgets('Not now button pops false', (tester) async {
    final fake = FakeStoragePermissionService();
    dynamic popResult;

    await tester.pumpWidget(
      testApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              popResult = await Navigator.of(context).push(
                MaterialPageRoute<dynamic>(
                  builder: (_) => StorageAccessScreen(service: fake),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('storageAccess.notNow')));
    await tester.pumpAndSettle();
    expect(popResult, isFalse);
  });
}
