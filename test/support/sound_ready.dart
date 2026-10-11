// Shared test helper: wait for a sound's asynchronous setup to finish before
// measuring what it renders.
//
// A sound becomes audible only once the engine's setup job has run on its
// background ("slow") thread pool and the next `update()` has promoted it to
// ready. That worker backs off when idle: after ~5 ms without work it polls
// in 1 ms sleeps (longer on Windows' default timer granularity). An offline
// `update()` + `renderOffline(1)` tick costs about a microsecond, so a fixed
// loop of a few dozen ticks can finish long before the worker wakes, and the
// sound is still silent when the test reads its peak (issues #77, #82).
// Pumping on wall-clock time with a short sleep gives the worker room to run.
import 'dart:io';

import 'package:test/test.dart';
import 'package:yse/yse.dart';

/// Pump [sys] (`update()` + `renderOffline(1)`, with a 1 ms sleep between
/// ticks) until [sound] reports [Sound.isReady], then fail the test if it
/// never does within [timeout].
///
/// Call this after `play()` (a start on a not-yet-ready sound is queued) and
/// before measuring any level the sound should produce.
void pumpUntilReady(
  System sys,
  Sound sound, {
  Duration timeout = const Duration(seconds: 5),
}) {
  final deadline = DateTime.now().add(timeout);
  while (!sound.isReady && DateTime.now().isBefore(deadline)) {
    sys.update();
    sys.renderOffline(1);
    if (!sound.isReady) sleep(const Duration(milliseconds: 1));
  }
  expect(sound.isReady, isTrue, reason: 'the sound never finished setup');
}
