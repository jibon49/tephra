// © 2026 Tephra. All rights reserved.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:watcher/watcher.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  final windowController = await WindowController.fromCurrentEngine();
  final windowArgs = windowController.arguments;

  if (windowArgs.isNotEmpty) {
    // Sub-window (Sticky spike)
    runApp(StickySpikeApp(rawArguments: windowArgs));
    return;
  }

  runApp(const MainSpikeApp());
}

// -----------------------------------------------------------------------------
// Sub-Window (Sticky Spike)
// -----------------------------------------------------------------------------

class StickySpikeApp extends StatelessWidget {
  const StickySpikeApp({super.key, required this.rawArguments});

  final String rawArguments;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sticky spike',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.amber,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: StickySpikeScreen(rawArguments: rawArguments),
    );
  }
}

class StickySpikeScreen extends StatelessWidget {
  const StickySpikeScreen({super.key, required this.rawArguments});

  final String rawArguments;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sticky spike'),
        backgroundColor: Colors.amber.shade200,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sticky spike',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Window Arguments (JSON):',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: SelectableText(
                rawArguments,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Main Window (Tray, Second Window, Watcher)
// -----------------------------------------------------------------------------

class MainSpikeApp extends StatelessWidget {
  const MainSpikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Windows Desktop Spike',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const MainSpikeScreen(),
    );
  }
}

class MainSpikeScreen extends StatefulWidget {
  const MainSpikeScreen({super.key});

  @override
  State<MainSpikeScreen> createState() => _MainSpikeScreenState();
}

class _MainSpikeScreenState extends State<MainSpikeScreen> {
  final TextEditingController _pathController = TextEditingController(
    text: r'D:\script\tephra-gemini\test_vaults\real',
  );
  final List<String> _logs = [];
  final ScrollController _scrollController = ScrollController();

  StreamSubscription<WatchEvent>? _watcherSub;
  String _trayStatus = 'Initializing...';
  int _newWindowCounter = 0;
  TrayIcon? _trayIcon;

  @override
  void initState() {
    super.initState();
    _initTray();
    _startWatcher();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _openSecondWindow();
      }
    });
  }

  @override
  void dispose() {
    _trayIcon?.dispose();
    _watcherSub?.cancel();
    _pathController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _log(String message) {
    final entry =
        '${DateTime.now().toIso8601String().substring(11, 23)} $message';
    // ignore: avoid_print
    print('WIN_SPIKE: $entry');
    try {
      File('windows_spike.log')
          .writeAsStringSync('$entry\n', mode: FileMode.append, flush: true);
    } catch (_) {}
    setState(() {
      _logs.add(entry);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _initTray() async {
    try {
      final trayIcon = TrayIcon.create();
      if (trayIcon == null) {
        setState(() => _trayStatus = 'TrayIcon.create() returned null');
        _log('TrayIcon.create() returned null');
        return;
      }

      trayIcon.icon = ImageAsset.fromAsset('assets/tray.ico');
      trayIcon.setTooltip('Tephra Windows Spike');

      final menu = Menu.create();
      if (menu == null) {
        setState(() => _trayStatus = 'Menu.create() returned null');
        return;
      }

      final showWindowItem = MenuItem.createWithLabelAndType(
        'Show window',
        MenuItemType.normal,
      );
      showWindowItem?.addListener((event) {
        if (event is MenuItemClickedEvent) {
          _log('Tray menu clicked: Show window');
        }
      });
      if (showWindowItem != null) menu.addItem(showWindowItem);

      final newWindowItem = MenuItem.createWithLabelAndType(
        'New window',
        MenuItemType.normal,
      );
      newWindowItem?.addListener((event) {
        if (event is MenuItemClickedEvent) {
          _log('Tray menu clicked: New window');
          _openSecondWindow();
        }
      });
      if (newWindowItem != null) menu.addItem(newWindowItem);

      menu.addSeparator();

      final quitItem = MenuItem.createWithLabelAndType(
        'Quit',
        MenuItemType.normal,
      );
      quitItem?.addListener((event) {
        if (event is MenuItemClickedEvent) {
          _log('Tray menu clicked: Quit -> exiting process');
          exit(0);
        }
      });
      if (quitItem != null) menu.addItem(quitItem);

      trayIcon.setContextMenu(menu);
      trayIcon.setVisible(true);

      _trayIcon = trayIcon;

      setState(() => _trayStatus = 'Tray icon active with 3 menu items');
      _log('Tray icon initialized successfully');
    } catch (e, st) {
      setState(() => _trayStatus = 'Tray error: $e');
      _log('Tray init error: $e\n$st');
    }
  }

  Future<void> _openSecondWindow() async {
    try {
      _newWindowCounter++;
      final argsMap = {
        'type': 'sticky',
        'title': 'Sticky Note #$_newWindowCounter',
        'content': 'Hello from second window #$_newWindowCounter',
        'timestamp': DateTime.now().toIso8601String(),
      };
      final argsJson = jsonEncode(argsMap);

      _log('Opening second window with args: $argsJson');
      final controller = await WindowController.create(
        WindowConfiguration(hiddenAtLaunch: false, arguments: argsJson),
      );
      await controller.show();
      _log('Second window created and shown (ID: ${controller.windowId})');
    } catch (e, st) {
      _log('Error creating second window: $e\n$st');
    }
  }

  void _startWatcher() {
    _watcherSub?.cancel();
    final targetPath = _pathController.text.trim();
    if (!Directory(targetPath).existsSync()) {
      _log('Target directory does not exist: $targetPath');
      return;
    }

    _log('Starting DirectoryWatcher on $targetPath');
    final watcher = DirectoryWatcher(targetPath);
    _watcherSub = watcher.events.listen(
      (event) {
        final nowEpochMs = DateTime.now().millisecondsSinceEpoch;
        _log('WATCHER_EVENT: $nowEpochMs ${event.type} ${event.path}');
      },
      onError: (Object e) {
        _log('WATCHER_ERROR: $e');
      },
    );
  }

  void _stopWatcher() {
    _watcherSub?.cancel();
    _watcherSub = null;
    _log('Stopped watcher');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Windows Desktop Spike'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear logs',
            onPressed: () => setState(() => _logs.clear()),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Tray Status: $_trayStatus')),
                ElevatedButton.icon(
                  onPressed: _openSecondWindow,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('New Window (Sticky)'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pathController,
                    decoration: const InputDecoration(
                      labelText: 'Watch Folder Path',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _startWatcher,
                  child: const Text('Watch'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _stopWatcher,
                  child: const Text('Stop'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8),
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                return Text(
                  _logs[index],
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
