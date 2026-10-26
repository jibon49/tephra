// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/core/platform/overlay_service.dart';
import 'package:tephra/stickies/android/overlay_bridge.dart';
import 'package:tephra/stickies/android/overlay_protocol.dart';
import 'package:tephra/stickies/data/sticky_edit_applier.dart';
import 'package:tephra/stickies/data/sticky_repository.dart';
import 'package:tephra/stickies/model/sticky_color.dart';
import 'package:tephra/stickies/windows/text_merger.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../fakes.dart';

class FakeOverlayService implements OverlayService {
  final StreamController<Map<String, Object?>> _controller =
      StreamController<Map<String, Object?>>.broadcast();
  final List<Map<String, Object?>> sentMessages = [];
  bool active = false;
  String? currentBubblePath;

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> showBubble(String stickyPath) async {
    active = true;
    currentBubblePath = stickyPath;
  }

  @override
  Future<void> closeBubble() async {
    active = false;
    currentBubblePath = null;
  }

  @override
  Future<bool> isActive() async => active;

  @override
  Future<void> send(Map<String, Object?> message) async {
    sentMessages.add(message);
  }

  @override
  Stream<Map<String, Object?>> get messages => _controller.stream;

  void emitMessage(OverlayMessage msg) {
    _controller.add(msg.toJson());
  }

  void dispose() {
    _controller.close();
  }
}

void main() {
  group('OverlayBridge', () {
    late MemoryVaultFileSystem fs;
    late FakeSearchEngine search;
    late FakeOpenNoteBridge openNotes;
    late Clock clock;
    late StickyRepository repo;
    late StickyEditApplier applier;
    late FakeOverlayService overlayService;
    late OverlayBridge bridge;

    setUp(() async {
      fs = MemoryVaultFileSystem();
      search = FakeSearchEngine(fs);
      openNotes = FakeOpenNoteBridge();
      clock = ManualClock(DateTime(2026, 10, 11, 10, 0, 0));
      repo = StickyRepository(
        fs: fs,
        search: search,
        settings: const StickySettingsView(
          stickyFolder: 'Stickies',
          defaultColor: NamedStickyColor.yellow,
        ),
        openNotes: openNotes,
        clock: clock,
      );
      await repo.start();

      applier = StickyEditApplier(
        repo: repo,
        openNotes: openNotes,
        merger: const SyncTextMerger(),
        conflictNamer: (path) => VaultPath(
          '${path.parent != null ? '${path.parent!.value}/' : ''}${path.stem} (conflict).md',
        ),
      );

      overlayService = FakeOverlayService();
      bridge = OverlayBridge(
        overlayService: overlayService,
        repo: repo,
        openNotes: openNotes,
        applier: applier,
      );
      bridge.start();
    });

    tearDown(() {
      bridge.dispose();
      overlayService.dispose();
    });

    test('contentChanged is applied and acked', () async {
      final sticky = await repo.create(body: 'Initial content\n');

      await bridge.openBubble(sticky.path);
      expect(overlayService.active, isTrue);
      expect(bridge.currentPath, equals(sticky.path));

      final baseHash = bridge.currentHash!;
      overlayService.sentMessages.clear();

      overlayService.emitMessage(
        OverlayContentChangedMessage(
          path: sticky.path.value,
          text: '---\ntephra-sticky: true\n---\nEdited in bubble\n',
          baseHash: baseHash,
        ),
      );

      await pumpEventQueue();

      final updated = repo.byPath(sticky.path);
      expect(updated?.text, contains('Edited in bubble'));

      final acks = overlayService.sentMessages
          .map(OverlayMessage.fromJson)
          .whereType<OverlayAckMessage>()
          .toList();
      expect(acks, hasLength(1));
      expect(acks.first.path, equals(sticky.path.value));
      expect(acks.first.hash, equals(bridge.currentHash));
    });

    test('stale base merges via StickyEditApplier', () async {
      final sticky = await repo.create(body: 'Line 1\nLine 2\nLine 3\n');

      await bridge.openBubble(sticky.path);
      final baseHash = bridge.currentHash!;
      overlayService.sentMessages.clear();

      // Main app changes line 1
      await repo.setText(
        sticky.path,
        '---\ntephra-sticky: true\n---\nLine 1 edited in main\nLine 2\nLine 3\n',
      );

      // Overlay edits line 3 using the stale baseHash
      overlayService.emitMessage(
        OverlayContentChangedMessage(
          path: sticky.path.value,
          text: '---\ntephra-sticky: true\n---\nLine 1\nLine 2\nLine 3 edited in bubble\n',
          baseHash: baseHash,
        ),
      );

      await pumpEventQueue();

      final current = repo.byPath(sticky.path);
      expect(current?.text, contains('Line 1 edited in main'));
      expect(current?.text, contains('Line 3 edited in bubble'));

      final updates = overlayService.sentMessages
          .map(OverlayMessage.fromJson)
          .whereType<OverlayUpdateMessage>()
          .toList();
      expect(updates, isNotEmpty);
      expect(updates.last.text, equals(current?.text));
    });

    test('close forgets bubble', () async {
      final sticky = await repo.create(body: 'Hello\n');
      await bridge.openBubble(sticky.path);
      expect(bridge.currentPath, equals(sticky.path));
      expect(overlayService.active, isTrue);

      overlayService.emitMessage(OverlayCloseMessage(path: sticky.path.value));
      await pumpEventQueue();

      expect(bridge.currentPath, isNull);
      expect(overlayService.active, isFalse);
    });
  });
}
