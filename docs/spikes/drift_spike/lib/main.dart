// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'bench_fts.dart';
import 'spike_db.dart';

void main(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();
  final autoRun = args.contains('--auto-run');
  runApp(DriftSpikeApp(autoRun: autoRun));
}

class DriftSpikeApp extends StatelessWidget {
  const DriftSpikeApp({super.key, this.autoRun = false});

  final bool autoRun;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Drift SQLite FTS5 Spike',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: DriftBenchmarkScreen(autoRun: autoRun),
    );
  }
}

class DriftBenchmarkScreen extends StatefulWidget {
  const DriftBenchmarkScreen({super.key, this.autoRun = false});

  final bool autoRun;

  @override
  State<DriftBenchmarkScreen> createState() => _DriftBenchmarkScreenState();
}

class _DriftBenchmarkScreenState extends State<DriftBenchmarkScreen> {
  late final SpikeDb _db;
  bool _running = false;
  String _status = 'Ready to run benchmark.';
  BenchmarkResults? _results;
  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _db = openSpikeDb();
    if (widget.autoRun) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _runBenchmark();
      });
    }
  }

  @override
  void dispose() {
    _db.close();
    super.dispose();
  }

  void _addLog(String msg) {
    setState(() {
      _logs.add(msg);
      _status = msg;
    });
  }

  Future<void> _runBenchmark() async {
    if (_running) return;
    setState(() {
      _running = true;
      _results = null;
      _logs.clear();
      _status = 'Running FTS5 benchmark...';
    });

    try {
      final results = await FtsBenchmark.run(
        _db,
        onProgress: (msg) {
          _addLog(msg);
        },
      );

      final platformName = defaultTargetPlatform.name;
      final summary = results.formatSummary(platformName);

      try {
        final resultsFile = File(
          r'D:\script\tephra-gemini\docs\spikes\drift_spike\drift_results.txt',
        );
        resultsFile.writeAsStringSync(summary);
      } catch (_) {}

      setState(() {
        _results = results;
        _running = false;
        _status = 'Benchmark completed successfully!';
      });
    } catch (e, st) {
      _addLog('ERROR: $e\n$st');
      setState(() {
        _running = false;
        _status = 'Benchmark error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Drift SQLite FTS5 Spike (00.17)')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: _running ? null : _runBenchmark,
                  icon: _running
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.play_arrow),
                  label: Text(_running ? 'Running...' : 'Run FTS5 Benchmark'),
                ),
                Text(
                  _status,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const Divider(height: 24),
            Expanded(
              child: _results == null
                  ? _buildLogView()
                  : DefaultTabController(
                      length: 2,
                      child: Column(
                        children: [
                          const TabBar(
                            tabs: [
                              Tab(text: 'Results'),
                              Tab(text: 'Logs'),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                _buildResultsView(_results!),
                                _buildLogView(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogView() {
    return ListView.builder(
      itemCount: _logs.length,
      itemBuilder: (context, i) {
        return Text(
          _logs[i],
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
        );
      },
    );
  }

  Widget _buildResultsView(BenchmarkResults r) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SQLite Version: ${r.sqliteVersion}'),
                  Text('FTS5 Enabled: ${r.hasFts5 ? "YES" : "NO"}'),
                  Text(
                    'Unicode61 10k Insert: ${r.unicode61InsertMs.toStringAsFixed(1)} ms',
                  ),
                  Text(
                    'Trigram 10k Insert: ${r.trigramInsertMs.toStringAsFixed(1)} ms',
                  ),
                  Text(
                    'Bangla Substring ("ংলা*") matches: ${r.banglaSubstringUnicode61Count}',
                  ),
                  Text(
                    'Bangla Trigram ("ংলা") matches: ${r.banglaSubstringTrigramCount}',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Unicode61 Query Latencies',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          DataTable(
            columns: const [
              DataColumn(label: Text('Query')),
              DataColumn(label: Text('Matches')),
              DataColumn(label: Text('Median (ms)')),
              DataColumn(label: Text('Max (ms)')),
            ],
            rows: r.unicode61Queries.map((q) {
              return DataRow(
                cells: [
                  DataCell(Text(q.query)),
                  DataCell(Text(q.resultCount.toString())),
                  DataCell(Text(q.medianMs.toStringAsFixed(2))),
                  DataCell(Text(q.maxMs.toStringAsFixed(2))),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          const Text(
            'Trigram Query Latencies',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          DataTable(
            columns: const [
              DataColumn(label: Text('Query')),
              DataColumn(label: Text('Matches')),
              DataColumn(label: Text('Median (ms)')),
              DataColumn(label: Text('Max (ms)')),
            ],
            rows: r.trigramQueries.map((q) {
              return DataRow(
                cells: [
                  DataCell(Text(q.query)),
                  DataCell(Text(q.resultCount.toString())),
                  DataCell(Text(q.medianMs.toStringAsFixed(2))),
                  DataCell(Text(q.maxMs.toStringAsFixed(2))),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
