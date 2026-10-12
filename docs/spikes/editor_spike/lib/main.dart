// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';

import 'auto_bench.dart';
import 'proto_a.dart';
import 'proto_b.dart';

void main(List<String> args) {
  final autoBench = args.contains('--auto-bench');
  runApp(EditorSpikeApp(autoBench: autoBench));
}

class EditorSpikeApp extends StatelessWidget {
  const EditorSpikeApp({super.key, this.autoBench = false});

  final bool autoBench;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Editor Spike',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFC2410C)),
        useMaterial3: true,
      ),
      home: autoBench ? const AutoBenchScreen(autoExit: true) : const SpikeHomeScreen(),
    );
  }
}

class SpikeHomeScreen extends StatelessWidget {
  const SpikeHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editor Engine Spike (00.16)'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const ProtoAScreen()),
                    );
                  },
                  icon: const Icon(Icons.code),
                  label: const Text('A: re_editor'),
                ),
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const ProtoBScreen()),
                    );
                  },
                  icon: const Icon(Icons.text_fields),
                  label: const Text('B: TextField'),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const AutoBenchScreen()),
                    );
                  },
                  icon: const Icon(Icons.auto_graph),
                  label: const Text('Run 3x Benchmarks (A & B)'),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('C: custom engine is not built (fallback only if A and B fail)'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.build_outlined),
                  label: const Text('C: custom (not built)'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
