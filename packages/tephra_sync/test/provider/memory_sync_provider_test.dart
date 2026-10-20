// © 2026 Tephra. All rights reserved.

import 'package:tephra_sync/tephra_sync.dart';
import 'package:test/test.dart';

import '../support/sync_provider_contract.dart';

void main() {
  runSyncProviderContract('MemorySyncProvider Contract', () async {
    return MemorySyncProvider();
  });

  group('MemorySyncProvider specific behaviors', () {
    test('unknown or garbage cursor triggers cursorWasReset', () async {
      final provider = MemorySyncProvider();
      await provider.connect();

      await provider.put('file1.txt', [1, 2]);

      final reset1 = await provider.changesSince('non-numeric');
      expect(reset1.cursorWasReset, isTrue);

      final reset2 = await provider.changesSince('-5');
      expect(reset2.cursorWasReset, isTrue);

      final reset3 = await provider.changesSince('999999');
      expect(reset3.cursorWasReset, isTrue);
    });

    test('beforeOp hook throwing propagates to caller', () async {
      final provider = MemorySyncProvider(
        beforeOp: (op, key) async {
          if (op == 'get' && key == 'throw_on_get.txt') {
            throw const NetworkUnavailableException('Simulated get failure');
          }
        },
      );
      await provider.connect();
      await provider.put('throw_on_get.txt', [10]);

      expect(
        () => provider.get('throw_on_get.txt'),
        throwsA(isA<NetworkUnavailableException>()),
      );
    });

    test(
      'quota limit enforcement throws RemoteQuotaExceededException',
      () async {
        final provider = MemorySyncProvider(quotaLimitBytes: 100);
        await provider.connect();

        // Put 80 bytes succeeds
        await provider.put('file80.bin', List.filled(80, 1));
        final q1 = await provider.quota();
        expect(q1?.usedBytes, equals(80));
        expect(q1?.limitBytes, equals(100));
        expect(q1?.freeBytes, equals(20));

        // Put another 30 bytes exceeds 100 limit -> throws
        expect(
          () => provider.put('file30.bin', List.filled(30, 2)),
          throwsA(isA<RemoteQuotaExceededException>()),
        );

        // Overwriting file80 with 60 bytes succeeds
        await provider.put('file80.bin', List.filled(60, 3));
        final q2 = await provider.quota();
        expect(q2?.usedBytes, equals(60));

        // Now 30 bytes fits
        await provider.put('file30.bin', List.filled(30, 2));
        final q3 = await provider.quota();
        expect(q3?.usedBytes, equals(90));
      },
    );
  });
}
