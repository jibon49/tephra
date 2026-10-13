// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:tephra_core/tephra_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../vault/providers.dart';
import '../workspace/providers.dart';
import 'reading_controller.dart';
import 'reading_scope.dart';
import 'simple_link_resolver.dart';

final class PendingJump {
  const PendingJump({required this.path, this.heading, this.blockRef});

  final VaultPath path;
  final String? heading;
  final String? blockRef;
}

final class PendingJumpNotifier extends Notifier<PendingJump?> {
  @override
  PendingJump? build() => null;

  void set(PendingJump? jump) {
    state = jump;
  }

  PendingJump? consume(VaultPath path) {
    if (state != null && state!.path == path) {
      final jump = state;
      state = null;
      return jump;
    }
    return null;
  }
}

final pendingJumpProvider = NotifierProvider<PendingJumpNotifier, PendingJump?>(
  PendingJumpNotifier.new,
);

/// Handlers for opening internal wiki links, external links, and files.
class LinkActions {
  const LinkActions({
    required this.ref,
    required this.context,
    required this.from,
    this.controller,
  });

  final WidgetRef ref;
  final BuildContext context;
  final VaultPath from;
  final ReadingViewController? controller;

  static String decodeMarkdownPathLenient(String path) {
    try {
      return Uri.decodeComponent(path);
    } catch (_) {
      return path;
    }
  }

  /// Opens an internal wiki link.
  Future<void> openWikiLink(WikiLinkTap tap) async {
    final l10n = AppLocalizations.of(context);

    // 1. Same-note link
    if (tap.target.isEmpty) {
      if (tap.heading != null) {
        controller?.scrollToHeading(tap.heading!);
      } else if (tap.blockRef != null) {
        controller?.scrollToBlockRef(tap.blockRef!);
      }
      return;
    }

    // 2. Resolve link
    final files = await ref.read(vaultFilesProvider.future);
    if (!context.mounted) return;

    final resolved = const SimpleLinkResolver().resolve(
      tap.target,
      from: from,
      files: files,
    );

    if (resolved != null) {
      if (tap.heading != null || tap.blockRef != null) {
        ref
            .read(pendingJumpProvider.notifier)
            .set(
              PendingJump(
                path: resolved,
                heading: tap.heading,
                blockRef: tap.blockRef,
              ),
            );
      }
      ref
          .read(workspaceProvider.notifier)
          .openPath(resolved, newTab: tap.newTab);
    } else {
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        SnackBar(
          content: Text(l10n.linkNotFound(tap.target)),
          action: SnackBarAction(
            label: l10n.linkCreate,
            onPressed: () async {
              final creator = ref.read(noteCreatorProvider);
              final created = await creator.createFromName(
                tap.target,
                contextNote: from,
              );
              ref
                  .read(workspaceProvider.notifier)
                  .openPath(created, newTab: tap.newTab);
            },
          ),
        ),
      );
    }
  }

  /// Opens an external URL or markdown link.
  Future<void> openMarkdownLink(String url, {bool newTab = false}) async {
    final l10n = AppLocalizations.of(context);
    final uri = Uri.tryParse(url);

    if (uri != null && uri.hasScheme) {
      final scheme = uri.scheme.toLowerCase();
      const allowedSchemes = {'http', 'https', 'mailto', 'tel'};
      if (allowedSchemes.contains(scheme)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.maybeOf(context)
            ?.showSnackBar(SnackBar(content: Text(l10n.linkSchemeBlocked)));
      }
      return;
    }

    // Internal vault link: path#anchor
    final decoded = decodeMarkdownPathLenient(url);
    final hashIndex = decoded.indexOf('#');
    final String pathPart;
    final String? anchorPart;
    if (hashIndex != -1) {
      pathPart = decoded.substring(0, hashIndex);
      anchorPart = decoded.substring(hashIndex + 1);
    } else {
      pathPart = decoded;
      anchorPart = null;
    }

    String? blockRef;
    String? heading;
    if (anchorPart != null) {
      if (anchorPart.startsWith('^')) {
        blockRef = anchorPart.substring(1);
      } else {
        heading = anchorPart;
      }
    }

    if (pathPart.isEmpty) {
      await openWikiLink(
        WikiLinkTap(
          target: '',
          heading: heading,
          blockRef: blockRef,
          newTab: newTab,
        ),
      );
      return;
    }

    final files = await ref.read(vaultFilesProvider.future);
    VaultPath? exactMatch;
    if (from.parent != null) {
      final candidate = from.parent!.join(pathPart);
      if (files.contains(candidate)) {
        exactMatch = candidate;
      }
    }

    final targetName = exactMatch != null ? exactMatch.value : pathPart;
    await openWikiLink(
      WikiLinkTap(
        target: targetName,
        heading: heading,
        blockRef: blockRef,
        newTab: newTab,
      ),
    );
  }

  /// Opens a resolved non-markdown file with the system application.
  Future<void> openResolvedFile(VaultPath resolved) async {
    final l10n = AppLocalizations.of(context);

    if (Platform.isWindows) {
      final session = ref.read(vaultSessionProvider);
      if (session != null) {
        final absPath = p.join(session.rootDir, resolved.value);
        await launchUrl(Uri.file(absPath));
        return;
      }
    }

    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(l10n.embedOpenLater)));
  }
}
