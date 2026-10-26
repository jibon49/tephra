// © 2026 Tephra. All rights reserved.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/platform/share_intent_service.dart';
import '../core/providers.dart';
import '../editor/attachment_service.dart';
import '../vault/note_tools/providers.dart';
import '../vault/providers.dart';
import 'capture_service.dart';
import 'share_intake_coordinator.dart';

/// In-memory storage notifier for shares received before a vault was opened.
class PendingSharedItemsNotifier extends Notifier<List<SharedItem>> {
  @override
  List<SharedItem> build() => const [];

  void set(List<SharedItem> items) => state = items;
  void add(List<SharedItem> items) => state = [...state, ...items];
  void clear() => state = const [];
}

/// In-memory storage for shares received before a vault was opened.
final pendingSharedItemsProvider =
    NotifierProvider<PendingSharedItemsNotifier, List<SharedItem>>(
      PendingSharedItemsNotifier.new,
    );

/// Provider for the [ShareIntakeCoordinator] managing incoming shares and deep captures.
final shareIntakeCoordinatorProvider = Provider<ShareIntakeCoordinator>((ref) {
  final coordinator = ShareIntakeCoordinator(ref);
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

/// Attachment service provider used by editor and capture services.
final attachmentServiceProvider = Provider<AttachmentService>((ref) {
  return AttachmentService(ref);
});

/// Provider supplying the [CaptureService] instance for the currently open vault session.
final captureServiceProvider = Provider<CaptureService?>((ref) {
  final session = ref.watch(vaultSessionProvider);
  if (session == null) return null;

  final daily = ref.watch(dailyNotesServiceProvider);
  final attachmentService = ref.watch(attachmentServiceProvider);
  final clock = ref.watch(clockProvider);

  return CaptureService(
    fs: session.fs,
    dailyNotesService: daily,
    attachmentService: attachmentService,
    getVaultSettings: () => ref.read(vaultSettingsProvider),
    clock: clock,
  );
});
