// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/core/sync/sync_triggers.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_sync/tephra_sync.dart';

class _FakeTimer implements Timer {
  _FakeTimer(this.duration, this.callback, this.scheduler);

  final Duration duration;
  final void Function() callback;
  final _FakeTimerScheduler scheduler;
  bool _active = true;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;

  @override
  void cancel() {
    _active = false;
    scheduler.timers.remove(this);
  }

  void fire() {
    if (_active) {
      _active = false;
      callback();
    }
  }
}

class _FakeTimerScheduler {
  final List<_FakeTimer> timers = [];

  Timer create(Duration duration, void Function() callback) {
    final t = _FakeTimer(duration, callback, this);
    timers.add(t);
    return t;
  }

  void fireAll() {
    final list = List<_FakeTimer>.from(timers);
    for (final t in list) {
      t.fire();
    }
  }

  void fireFirstMatching(Duration duration) {
    final match = timers.firstWhere(
      (t) => t.duration == duration && t.isActive,
    );
    match.fire();
  }
}

void main() {
  group('SyncTriggers', () {
    late _FakeTimerScheduler scheduler;
    late List<SyncTrigger> triggered;
    late List<List<VaultPath>> localChanges;
    late SyncTriggers triggers;

    setUp(() {
      scheduler = _FakeTimerScheduler();
      triggered = [];
      localChanges = [];

      triggers = SyncTriggers(
        onTrigger: (t) => triggered.add(t),
        onLocalChange: (paths) => localChanges.add(paths),
        timerFactory: scheduler.create,
      );
    });

    tearDown(() {
      triggers.dispose();
    });

    test('debounces save trigger by 5 seconds after last change', () {
      triggers.notifyLocalChange(VaultPath('note1.md'));
      expect(localChanges.length, equals(1));
      expect(triggered, isEmpty);

      // Subsequent change within debounce window resets timer
      triggers.notifyLocalChange(VaultPath('note2.md'));
      expect(localChanges.length, equals(2));
      expect(triggered, isEmpty);

      // Fire the debounce timer
      scheduler.fireFirstMatching(const Duration(seconds: 5));

      expect(triggered, equals([SyncTrigger.save]));
    });

    test('appStart and appResume trigger immediate sync and start polling', () {
      triggers.onAppStart();
      expect(triggered, equals([SyncTrigger.appStart]));
      triggers.onCycleCompleted();

      // Polling fires every 30s
      scheduler.fireFirstMatching(const Duration(seconds: 30));
      expect(triggered, equals([SyncTrigger.appStart, SyncTrigger.remotePoll]));
      triggers.onCycleCompleted();

      // App pause stops polling
      triggers.onAppPause();
      final countBefore = triggered.length;
      scheduler.fireAll();
      expect(triggered.length, equals(countBefore));

      // App resume triggers appResume and resumes polling
      triggers.onAppResume();
      expect(triggered.last, equals(SyncTrigger.appResume));
      triggers.onCycleCompleted();

      scheduler.fireFirstMatching(const Duration(seconds: 30));
      expect(triggered.last, equals(SyncTrigger.remotePoll));
    });

    test('coalesces triggers arriving during a cycle into one run-again', () {
      triggers.requestSync(SyncTrigger.manual);
      expect(triggered, equals([SyncTrigger.manual]));
      expect(triggers.isSyncing, isTrue);

      // Arrive during active cycle: sets run-again
      triggers.requestSync(SyncTrigger.save);
      expect(triggered.length, equals(1));
      expect(triggers.hasRunAgain, isTrue);

      // Another arrives during active cycle: coalesces into single run-again
      triggers.requestSync(SyncTrigger.remotePoll);
      expect(triggered.length, equals(1));
      expect(triggers.hasRunAgain, isTrue);

      // Active cycle completes -> run-again immediately triggers one cycle
      triggers.onCycleCompleted();
      expect(triggered.length, equals(2));
      expect(triggered.last, equals(SyncTrigger.remotePoll));
      expect(triggers.isSyncing, isTrue);

      // Cycle 2 completes without further triggers -> idle
      triggers.onCycleCompleted();
      expect(triggers.isSyncing, isFalse);
      expect(triggers.hasRunAgain, isFalse);
    });
  });
}
