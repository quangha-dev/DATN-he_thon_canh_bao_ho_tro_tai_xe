import 'dart:math' as math;

import 'nav_route.dart';
import 'navigation_engine.dart';

enum GuidancePriority {
  /// Progress chatter — dropped when something more important is queued.
  low,
  normal,

  /// Safety: a closure ahead, or a confirmed wrong turn. Interrupts speech.
  urgent,
}

class GuidanceCue {
  const GuidanceCue(this.id, this.text, {this.priority = GuidancePriority.normal});

  /// Stable key so the same announcement is never repeated.
  final String id;
  final String text;
  final GuidancePriority priority;
}

/// Decides what should be said, and when.
///
/// The previous implementation spoke a step the moment it became current — up
/// to a kilometre early, with no distance and no reminder as the turn
/// approached — and silently skipped instructions whenever two maneuvers fell
/// close together. Guidance here follows the tiering drivers expect: an early
/// heads-up, a confirmation, and a call at the turn itself, with the thresholds
/// scaled by speed so a city street and a ring road both get useful warning.
class GuidancePlanner {
  GuidancePlanner({this.destinationName});

  final String? destinationName;

  final Set<String> _spoken = <String>{};
  bool _wasOffRoute = false;
  int _lastLegIndex = -1;

  /// Called after a reroute: step indices restart, so the spoken history for
  /// steps has to go with them. Hazard and arrival keys are stable and are
  /// deliberately kept, so a closure is not re-announced on every reroute.
  void onRouteReplaced() {
    _spoken.removeWhere((key) => key.startsWith('step:'));
    _lastLegIndex = -1;
  }

  void reset() {
    _spoken.clear();
    _wasOffRoute = false;
    _lastLegIndex = -1;
  }

  List<GuidanceCue> plan(NavState state) {
    final cues = <GuidanceCue>[];

    if (state.offRoute && !_wasOffRoute) {
      cues.add(
        const GuidanceCue(
          'offroute',
          'Bạn đang đi lệch tuyến',
          priority: GuidancePriority.urgent,
        ),
      );
      _spoken.remove('offroute-recovered');
    }
    if (!state.offRoute && _wasOffRoute) {
      _spoken.remove('offroute');
    }
    _wasOffRoute = state.offRoute;

    if (state.arrived) {
      _emit(
        cues,
        GuidanceCue(
          'arrived',
          destinationName == null || destinationName!.isEmpty
              ? 'Bạn đã đến điểm đến'
              : 'Bạn đã đến $destinationName',
        ),
      );
      return cues;
    }

    _planHazard(cues, state);

    // Speech is suppressed while off route: the next instruction belongs to a
    // road the vehicle is no longer on, and repeating it is actively confusing.
    if (state.offRoute) return cues;

    _planContinue(cues, state);
    _planManeuver(cues, state);
    return cues;
  }

  void _planHazard(List<GuidanceCue> cues, NavState state) {
    final hazard = state.hazardAhead;
    final distance = state.hazardDistanceMeters;
    if (hazard == null || distance == null) return;
    final key = hazard.hazard.id?.toString() ?? hazard.offsetMeters.round().toString();
    final label = hazard.hazard.label;

    if (distance <= 1000 && distance > 350) {
      _emit(
        cues,
        GuidanceCue(
          'hazard:$key:far',
          'Cảnh báo $label phía trước, cách ${_spokenDistance(distance)}',
          priority: GuidancePriority.urgent,
        ),
      );
    }
    if (distance <= 350) {
      _emit(
        cues,
        GuidanceCue(
          'hazard:$key:near',
          hazard.hazard.hardClosure
              ? 'Đường phía trước bị chặn do $label, cách ${_spokenDistance(distance)}'
              : 'Sắp tới đoạn $label, cách ${_spokenDistance(distance)}, hãy giảm tốc',
          priority: GuidancePriority.urgent,
        ),
      );
    }
  }

  /// "Đi thẳng 4 ki lô mét" right after a turn, so a long leg does not feel
  /// like the guidance has stopped working.
  void _planContinue(List<GuidanceCue> cues, NavState state) {
    if (state.legIndex == _lastLegIndex) return;
    _lastLegIndex = state.legIndex;
    final legLength = _legLength(state);
    if (legLength < 2500) return;
    final road = state.currentRoadName.trim();
    _emit(
      cues,
      GuidanceCue(
        'step:${state.legIndex}:continue',
        road.isEmpty
            ? 'Đi thẳng ${_spokenDistance(legLength)}'
            : 'Đi thẳng ${_spokenDistance(legLength)} trên $road',
        priority: GuidancePriority.low,
      ),
    );
  }

  void _planManeuver(List<GuidanceCue> cues, NavState state) {
    final step = state.upcomingStep;
    if (step == null) return;
    final distance = state.distanceToManeuverMeters;
    final speed = math.max(state.speedKph / 3.6, 4.0);
    final legLength = _legLength(state);

    final prepareAt = (speed * 45).clamp(400.0, 1500.0);
    final confirmAt = (speed * 18).clamp(150.0, 500.0);
    final executeAt = (speed * 5).clamp(30.0, 120.0);

    final base = _instruction(step);
    final chained = _chain(state);

    // An early heads-up is only useful when the leg is long enough that it does
    // not land on top of the previous instruction.
    if (step.maneuver.isDirectionChange &&
        legLength >= prepareAt * 1.3 &&
        distance <= prepareAt &&
        distance > confirmAt) {
      _emit(
        cues,
        GuidanceCue(
          'step:${step.index}:prepare',
          'Sau ${_spokenDistance(distance)}, $base',
        ),
      );
    }

    if (legLength >= confirmAt * 1.2 && distance <= confirmAt && distance > executeAt) {
      _emit(
        cues,
        GuidanceCue(
          'step:${step.index}:confirm',
          'Sau ${_spokenDistance(distance)}, $base',
        ),
      );
    }

    // The arrival step gets no call at the turn: the dedicated arrival cue
    // fires a moment later and saying both is just noise.
    if (distance <= executeAt && !step.isArrival) {
      _emit(
        cues,
        GuidanceCue(
          'step:${step.index}:execute',
          '${_shortInstruction(step)}$chained',
        ),
      );
    }
  }

  double _legLength(NavState state) {
    final steps = state.route.steps;
    final upcoming = state.upcomingStep;
    if (steps.isEmpty || upcoming == null) return state.route.lengthMeters;
    final from = steps[state.legIndex.clamp(0, steps.length - 1)];
    if (identical(from, upcoming)) {
      return math.max(0, state.route.lengthMeters - from.startOffsetMeters);
    }
    return math.max(0, upcoming.startOffsetMeters - from.startOffsetMeters);
  }

  String _chain(NavState state) {
    final upcoming = state.upcomingStep;
    final following = state.followingStep;
    if (upcoming == null || following == null) return '';
    final gap = following.startOffsetMeters - upcoming.startOffsetMeters;
    if (gap > 180 || !following.maneuver.isDirectionChange) return '';
    return ', sau đó ${following.maneuver.shortPhrase.toLowerCase()}';
  }

  String _instruction(NavStep step) {
    if (step.isArrival) {
      final target = destinationName == null || destinationName!.isEmpty
          ? 'điểm đến'
          : destinationName!;
      return 'bạn sẽ đến $target';
    }
    final instruction = step.instruction.trim();
    if (instruction.isNotEmpty) return _lowerFirst(instruction);
    final road = step.roadName.trim();
    return _lowerFirst(
      road.isEmpty ? step.maneuver.shortPhrase : '${step.maneuver.shortPhrase} vào $road',
    );
  }

  /// At the turn itself the road name is noise — the driver can see it.
  String _shortInstruction(NavStep step) => step.maneuver.shortPhrase;

  void _emit(List<GuidanceCue> cues, GuidanceCue cue) {
    if (_spoken.add(cue.id)) cues.add(cue);
  }

  static String _lowerFirst(String value) =>
      value.isEmpty ? value : value[0].toLowerCase() + value.substring(1);

  /// Spelled out rather than abbreviated: a TTS engine reads "km" as two
  /// letters in Vietnamese.
  static String _spokenDistance(double meters) {
    if (meters >= 1000) {
      final km = meters / 1000;
      final rounded = (km * 10).round() / 10;
      if (rounded == rounded.roundToDouble()) {
        return '${rounded.round()} ki lô mét';
      }
      return '${rounded.toStringAsFixed(1).replaceAll('.', ' phẩy ')} ki lô mét';
    }
    if (meters >= 100) return '${(meters / 50).round() * 50} mét';
    return '${math.max(10, (meters / 10).round() * 10)} mét';
  }
}
