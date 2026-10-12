// © 2026 Tephra. All rights reserved.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:watcher/watcher.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StorageSpikeApp());
}

class StorageSpikeApp extends StatelessWidget {
  const StorageSpikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Android Storage Spike',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const StorageSpikeScreen(),
    );
  }
}

class StorageSpikeScreen extends StatefulWidget {
  const StorageSpikeScreen({super.key});

  @override
  State<StorageSpikeScreen> createState() => _StorageSpikeScreenState();
}

class _StorageSpikeScreenState extends State<StorageSpikeScreen> {
  static const String vaultPath = '/storage/emulated/0/Documents/TestVault';

  final List<String> _logs = [];
  final ScrollController _scrollController = ScrollController();

  StreamSubscription<WatchEvent>? _watcherSub;
  StreamSubscription<FileSystemEvent>? _dartIoSub;
  StreamSubscription<WatchEvent>? _pollingSub;

  String _currentWatcher = 'None';

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  @override
  void dispose() {
    _stopAllWatchers();
    _scrollController.dispose();
    super.dispose();
  }

  void _log(String message) {
    final entry =
        '${DateTime.now().toIso8601String().substring(11, 23)} $message';
    // Print to stdout so ADB logcat captures events with precise timestamps
    // ignore: avoid_print
    print('STORAGE_SPIKE: $entry');
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

  Future<void> _checkStatus() async {
    final status = await Permission.manageExternalStorage.status;
    _log('Permission status: $status');
  }

  Future<void> _requestPermission() async {
    _log('Requesting MANAGE_EXTERNAL_STORAGE...');
    final status = await Permission.manageExternalStorage.request();
    _log('New permission status: $status');
  }

  Future<void> _writeAndRead() async {
    try {
      final dir = Directory(vaultPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
        _log('Created vault directory: $vaultPath');
      }

      final nowStr = DateTime.now().toIso8601String();
      final content = '# Hello from Tephra\nWritten at: $nowStr\n';

      final file = File(p.join(vaultPath, 'hello.md'));
      final tempFile = File(p.join(vaultPath, 'hello.md.tmp'));

      // Atomic write: write to temp -> flush -> rename
      await tempFile.writeAsString(content, flush: true);
      await tempFile.rename(file.path);
      _log('Wrote ${file.path} atomically');

      // Read back
      final readBack = await file.readAsString();
      final matches = readBack == content;
      _log('Read back (${readBack.length} bytes). Matches: $matches');
    } catch (e, st) {
      _log('ERROR in writeAndRead: $e\n$st');
    }
  }

  void _stopAllWatchers() {
    _watcherSub?.cancel();
    _watcherSub = null;
    _dartIoSub?.cancel();
    _dartIoSub = null;
    _pollingSub?.cancel();
    _pollingSub = null;
  }

  Future<void> _startWatcher() async {
    _stopAllWatchers();
    final dir = Directory(vaultPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    _log('Starting DirectoryWatcher (watcher package) on $vaultPath');
    final watcher = DirectoryWatcher(vaultPath);
    _watcherSub = watcher.events.listen(
      (event) {
        final nowEpochMs = DateTime.now().millisecondsSinceEpoch;
        _log('WATCHER_EVENT: $nowEpochMs ${event.type} ${event.path}');
      },
      onError: (Object e) {
        _log('WATCHER_ERROR: $e');
      },
    );
    setState(() {
      _currentWatcher = 'DirectoryWatcher';
    });
  }

  Future<void> _startDartIoWatcher() async {
    _stopAllWatchers();
    final dir = Directory(vaultPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    _log('Starting Directory.watch (dart:io) on $vaultPath');
    _dartIoSub = dir
        .watch(recursive: true)
        .listen(
          (event) {
            final nowEpochMs = DateTime.now().millisecondsSinceEpoch;
            final typeStr = _dartIoEventTypeToString(event.type);
            _log('DART_IO_EVENT: $nowEpochMs $typeStr ${event.path}');
          },
          onError: (Object e) {
            _log('DART_IO_ERROR: $e');
          },
        );
    setState(() {
      _currentWatcher = 'Directory.watch (dart:io)';
    });
  }

  Future<void> _startPollingWatcher() async {
    _stopAllWatchers();
    final dir = Directory(vaultPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    _log('Starting PollingDirectoryWatcher (1s delay) on $vaultPath');
    final watcher = PollingDirectoryWatcher(
      vaultPath,
      pollingDelay: const Duration(seconds: 1),
    );
    _pollingSub = watcher.events.listen(
      (event) {
        final nowEpochMs = DateTime.now().millisecondsSinceEpoch;
        _log('POLLING_EVENT: $nowEpochMs ${event.type} ${event.path}');
      },
      onError: (Object e) {
        _log('POLLING_ERROR: $e');
      },
    );
    setState(() {
      _currentWatcher = 'PollingDirectoryWatcher (1s)';
    });
  }

  String _dartIoEventTypeToString(int type) {
    switch (type) {
      case FileSystemEvent.create:
        return 'create';
      case FileSystemEvent.modify:
        return 'modify';
      case FileSystemEvent.delete:
        return 'delete';
      case FileSystemEvent.move:
        return 'move';
      case FileSystemEvent.all:
        return 'all';
      default:
        return 'unknown($type)';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Android Storage Spike'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear logs',
            onPressed: () {
              setState(() {
                _logs.clear();
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _checkStatus,
                  child: const Text('Status'),
                ),
                ElevatedButton(
                  onPressed: _requestPermission,
                  child: const Text('Request All files access'),
                ),
                ElevatedButton(
                  onPressed: _writeAndRead,
                  child: const Text('Write + read'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _currentWatcher == 'DirectoryWatcher'
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                  ),
                  onPressed: _startWatcher,
                  child: const Text('Watch (watcher)'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _currentWatcher == 'Directory.watch (dart:io)'
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                  ),
                  onPressed: _startDartIoWatcher,
                  child: const Text('Watch (dart:io)'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _currentWatcher == 'PollingDirectoryWatcher (1s)'
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                  ),
                  onPressed: _startPollingWatcher,
                  child: const Text('Watch (polling 1 s)'),
                ),
                OutlinedButton(
                  onPressed: () {
                    _stopAllWatchers();
                    setState(() {
                      _currentWatcher = 'None';
                    });
                    _log('Stopped all watchers');
                  },
                  child: const Text('Stop Watchers'),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            width: double.infinity,
            child: Text(
              'Active Watcher: $_currentWatcher',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8),
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                final log = _logs[index];
                return Text(
                  log,
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
