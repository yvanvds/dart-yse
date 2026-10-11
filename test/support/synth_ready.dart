// Shared test helpers for synths: wait for a voice pool to clone, and make
// sure no stale synth setup job can claim the next synth before its voices
// are added (issue #81, upstream yvanvds/yse-soundengine#1177).
//
// libYSE v3.1.0 makes a synth claimable by its setup job as soon as
// `yse_synth_create()` returns. The synth manager's per-block update (run by
// every rendered block, so by `renderOffline()` here) queues a setup job while
// any synth is waiting to be built, including one spare job on the block that
// promotes a freshly built synth. A setup job builds every synth it finds, so
// if one runs between `Synth()` and the `add*Voices` calls, the synth is built
// with no voices and the later groups are dropped by the engine with only a
// log warning. Measured against v3.1.0 on Windows x64 (`dart run`, after
// another synth was just built): adding the voices immediately after
// `Synth()` still loses in roughly 1-10 % of cases, and with 5 ms or more
// between the two it loses almost every time.
//
// The engine's background ("slow") pool is a single worker draining a FIFO
// queue, so a job queued after another cannot finish before it. A sound
// becomes ready only after its own setup job has run on that worker, which
// makes a throwaway sound's readiness a fence for every job queued before it.
import 'dart:io';

import 'package:test/test.dart';
import 'package:yse/yse.dart';

import 'sound_ready.dart';

/// Drive the engine until [synth] has cloned at least [want] voices, or a
/// bounded timeout elapses. Returns the final voice count.
int pumpVoices(System sys, Synth synth, int want) {
  var vc = synth.voiceCount;
  for (var i = 0; i < 60 && vc < want; i++) {
    sys.update();
    sys.renderOffline(128);
    vc = synth.voiceCount;
    if (vc >= want) break;
    sleep(const Duration(milliseconds: 10));
  }
  return vc;
}

/// Wait until every synth setup job queued so far has run, so a synth created
/// next cannot be claimed before its voices are added.
///
/// Three fence rounds. Each rendered block updates the sound manager before
/// the synth manager, so a synth job can be queued in the same block as the
/// fence's job, just behind it. Round one drains every job queued before its
/// fence, and those jobs build every synth that was waiting. Round two drains
/// the jobs queued behind round one's fence and promotes the built synths;
/// the promoting block may queue one last spare job, which round three
/// drains. From then on no synth is waiting, so no block queues a synth job.
void settleSynthSetup(System sys) {
  for (var round = 0; round < 3; round++) {
    sys.update();
    final patcher = Patcher();
    final fence = Sound.fromPatcher(patcher);
    pumpUntilReady(sys, fence);
    fence.dispose();
    patcher.dispose();
  }
}

/// [settleSynthSetup], then create a synth. Add its voices before the next
/// `System.update()`.
Synth newSynth(System sys) {
  settleSynthSetup(sys);
  final synth = Synth();
  addTearDown(synth.dispose);
  return synth;
}
