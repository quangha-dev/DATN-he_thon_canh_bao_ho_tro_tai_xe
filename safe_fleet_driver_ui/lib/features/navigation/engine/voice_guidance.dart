import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

import 'guidance_planner.dart';

/// Speaks guidance cues one at a time, in order, without talking over itself.
///
/// `FlutterTts.speak` returns as soon as the utterance is handed to the
/// platform, so firing several cues from consecutive GPS fixes used to cut each
/// one off mid-word. Everything is serialised through a queue here, and a
/// safety cue is allowed to interrupt whatever progress chatter is in flight.
class VoiceGuidance {
  VoiceGuidance({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  final List<GuidanceCue> _queue = <GuidanceCue>[];

  bool _ready = false;
  bool _speaking = false;
  bool _muted = false;
  bool _disposed = false;

  bool get isMuted => _muted;

  Future<void> initialize() async {
    if (_ready || _disposed) return;
    try {
      await _tts.awaitSpeakCompletion(true);
      final available = await _tts.isLanguageAvailable('vi-VN');
      // A device without the Vietnamese voice still gets guidance; it reads the
      // text with the default voice rather than going silent.
      if (available == true) await _tts.setLanguage('vi-VN');
      await _tts.setSpeechRate(0.52);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _ready = true;
    } catch (_) {
      // Guidance must never be blocked by a missing or misbehaving TTS engine;
      // the banner keeps showing the same instruction.
      _ready = false;
    }
  }

  void setMuted(bool muted) {
    _muted = muted;
    if (muted) {
      _queue.clear();
      unawaited(_stop());
    }
  }

  void enqueueAll(Iterable<GuidanceCue> cues) {
    for (final cue in cues) {
      enqueue(cue);
    }
  }

  void enqueue(GuidanceCue cue) {
    if (_disposed || _muted || cue.text.trim().isEmpty) return;
    if (cue.priority == GuidancePriority.urgent) {
      // Drop pending chatter so the warning is not queued behind it.
      _queue.removeWhere((queued) => queued.priority != GuidancePriority.urgent);
      _queue.insert(0, cue);
      if (_speaking) unawaited(_stop());
    } else if (cue.priority == GuidancePriority.low && _queue.isNotEmpty) {
      return;
    } else {
      _queue.add(cue);
    }
    unawaited(_drain());
  }

  /// Speaks something outside the planner, e.g. the confirmation that a new
  /// route has been found.
  void say(String text, {GuidancePriority priority = GuidancePriority.normal}) =>
      enqueue(GuidanceCue('ad-hoc:${DateTime.now().microsecondsSinceEpoch}', text,
          priority: priority));

  Future<void> _drain() async {
    if (_speaking || _disposed || _muted) return;
    _speaking = true;
    try {
      while (_queue.isNotEmpty && !_disposed && !_muted) {
        final cue = _queue.removeAt(0);
        if (!_ready) await initialize();
        try {
          await _tts.speak(cue.text);
        } catch (_) {
          // Skip the utterance and keep the queue moving.
        }
      }
    } finally {
      _speaking = false;
    }
  }

  Future<void> _stop() async {
    try {
      await _tts.stop();
    } catch (_) {
      // Nothing to stop.
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _queue.clear();
    await _stop();
  }
}
