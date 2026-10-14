// © 2026 Tephra. All rights reserved.

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tephra_index/tephra_index.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../settings/providers.dart';
import 'providers.dart';

/// Async notifier managing the lifecycle of the active [NoteIndex] for the open vault.
class NoteIndexNotifier extends AsyncNotifier<NoteIndex> {
  final _log = Logger('index');

  @override
  Future<NoteIndex> build() async {
    final session = ref.watch(vaultSessionProvider);
    if (session == null) {
      throw StateError('No vault is open');
    }

    final rawFs = session.fs;
    final vaultId = session.vaultId;
    final settings = ref.watch(vaultSettingsProvider);

    final String dbFile;
    if (rawFs is MemoryVaultFileSystem) {
      dbFile = ':memory:';
    } else {
      final dir = await getApplicationSupportDirectory();
      dbFile = p.join(dir.path, 'index', '$vaultId.sqlite');
      final parentDir = Directory(p.dirname(dbFile));
      if (!parentDir.existsSync()) {
        parentDir.createSync(recursive: true);
      }
    }

    _log.info('Opening index at $dbFile for vault $vaultId');

    final index = await NoteIndex.open(
      dbFile,
      rawFs,
      options: IndexOptions(excludedFolders: settings.excludedFolders),
    );

    final wrapper = ref.watch(indexingVaultFsProvider);
    wrapper.attachIndex((change) {
      unawaited(
        index.onChange(change).catchError((Object err, StackTrace st) {
          _log.warning('Failed to handle change in index: $change', err, st);
        }),
      );
    });

    final watcherSub = rawFs.watch().listen((change) {
      unawaited(
        index.onChange(change).catchError((Object err, StackTrace st) {
          _log.warning(
            'Failed to handle watcher change in index: $change',
            err,
            st,
          );
        }),
      );
    });

    ref.onDispose(() {
      watcherSub.cancel();
      unawaited(index.close());
    });

    unawaited(
      index.reconcile().catchError((Object err, StackTrace st) {
        _log.warning('Failed to reconcile index', err, st);
      }),
    );

    return index;
  }
}
