// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'search_pane.dart';

/// Full-screen phone search screen route.
class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.searchTabTitle), elevation: 0),
      body: SafeArea(
        child: SearchPane(autofocus: true, initialQuery: initialQuery),
      ),
    );
  }
}
