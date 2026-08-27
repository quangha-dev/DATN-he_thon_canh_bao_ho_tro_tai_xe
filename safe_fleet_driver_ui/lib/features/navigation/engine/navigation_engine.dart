import 'dart:math' as math;

import 'package:maplibre_gl/maplibre_gl.dart';

import 'geo.dart';
import 'maneuver.dart';
import 'nav_route.dart';
import 'route_matcher.dart';

/// One position sample, decoupled from the platform plugin so the engine can be
/// driven by a recorded or simulated trace in tests.
class NavFix {
  const NavFix({
    required this.position,
    required this.timestamp,
    this.accuracyMeters = 0,
    this.headingDeg,
    this.speedMps = 0,
  });

  final LatLng position;
  final DateTime timestamp;
  final double accuracyMeters;
  final double? headingDeg;
  final double speedMps;
}

enum NavPhase { locating, guiding, offRoute, arrived }

class NavConfig {
  const NavConfig({
    this.offRouteBaseMeters = 35,
    this.offRouteMinMeters = 40,
    this.offRouteMaxMeters = 90,
    this.offRouteConfirmFixes = 3,
    this.offRouteConfirmDuration = const Duration(seconds: 10),
    this.offRouteConfirmTravelMeters = 20,
    this.unusableAccuracyMeters = 50,
    this.arrivalRadiusMeters = 25,
    this.hazardLookaheadMeters = 1500,
  });

  /// Off-route distance grows with the reported GPS error, so a weak fix under
  /// a flyover does not fake a detour, while a clean fix still catches a real
  /// wrong turn within one short block.
  final double offRouteBaseMeters;
  final double offRouteMinMeters;
  final double offRouteMaxMeters;

  /// A reroute needs all three: enough consecutive bad fixes, enough elapsed
  /// time, and enough ground actually covered. A vehicle parked on a GPS-noisy
  /// street satisfies the first two but never the third.
  final int offRouteConfirmFixes;
  final Duration offRouteConfirmDuration;
  final double offRouteConfirmTravelMeters;

  final double unusableAccuracyMeters;
  final double arrivalRadiusMeters;
  final double hazardLookaheadMeters;
}

class NavState {
  const NavState({
    required this.phase,
    required this.route,
    required this.snapped,
    required this.courseDeg,
    required this.travelledMeters,
    required this.remainingMeters,
    required this.remainingDuration,
    required this.eta,
    required this.legIndex,
    required this.upcomingStep,
    required this.followingStep,
    required this.distanceToManeuverMeters,
    required this.currentRoadName,
    required this.lateralMeters,
    required this.offRoute,
    required this.offRouteFor,
    required this.rerouteRequired,
    required this.speedKph,
    required this.gpsUsable,
    this.hazardAhead,
    this.hazardDistanceMeters,
  });

  final NavPhase phase;
  final NavRoute route;
  final LatLng snapped;
  final double courseDeg;
  final double travelledMeters;
  final double remainingMeters;
  final Duration remainingDuration;
  final DateTime eta;

  /// The step the vehicle is currently travelling along.
  final int legIndex;

  /// The maneuver being approached — what the instruction banner shows.
  final NavStep? upcomingStep;

  /// The maneuver after that, used for "then turn left" chaining.
  final NavStep? followingStep;
  final double distanceToManeuverMeters;
  final String currentRoadName;
  final double lateralMeters;
  final bool offRoute;
  final Duration offRouteFor;
  final bool rerouteRequired;
  final double speedKph;

  /// False when the fix is too inaccurate to drive safety decisions.
  final bool gpsUsable;
  final NavHazardOnRoute? hazardAhead;
  final double? hazardDistanceMeters;

  bool get arrived => phase == NavPhase.arrived;
}

/// Turn-by-turn state machine.
///
/// Deliberately free of plugins, timers and widgets: it takes a fix and returns
/// the complete guidance state. That makes the whole of guidance — progress,
/// step advancement, off-route confirmation, ETA, hazard lookahead — replayable
/// against a recorded drive in a unit test, which is the only practical way to
/// validate navigation without driving the route.
class NavigationEngine {
  NavigationEngine({
    required NavRoute route,
    required this.destination,
    this.config = const NavConfig(),
  }) : _route = route,
       _matcher = RouteMatcher(route);

  final LatLng destination;
  final NavConfig config;

  NavRoute _route;
  RouteMatcher _matcher;

  NavState? _state;
  DateTime? _offRouteSince;
  LatLng? _offRouteAnchor;
  int _offRouteFixes = 0;
  double _speedEma = 0;
  int _movingSamples = 0;
  bool _arrived = false;

  NavRoute get route => _route;

  NavState? get state => _state;

  /// Swaps in a freshly computed route after a reroute, keeping the vehicle's
  /// current progress rather than restarting guidance from the origin.
  void replaceRoute(NavRoute route, {LatLng? at}) {
    _route = route;
    _matcher = RouteMatcher(route);
    if (at != null) {
      _matcher.match(at);
    }
    _offRouteSince = null;
    _offRouteAnchor = null;
    _offRouteFixes = 0;
    _arrived = false;
    _state = null;
  }

  NavState update(NavFix fix) {
    final usable =
        fix.accuracyMeters <= 0 ||
        fix.accuracyMeters <= config.unusableAccuracyMeters;

    final match = _matcher.match(
      fix.position,
      headingDeg: fix.headingDeg,
      speedMps: fix.speedMps,
      accuracyMeters: fix.accuracyMeters,
      timestamp: fix.timestamp,
    );

    final travelled = match.offsetMeters;
    final remaining = math.max(0.0, _route.lengthMeters - travelled);

    if (fix.speedMps >= 1.5) {
      _speedEma = _movingSamples == 0
          ? fix.speedMps
          : _speedEma * 0.8 + fix.speedMps * 0.2;
      _movingSamples++;
    }

    final legIndex = _legIndexAt(travelled);
    final steps = _route.steps;
    final upcomingIndex = steps.isEmpty
        ? -1
        : math.min(legIndex + 1, steps.length - 1);
    final upcoming = upcomingIndex < 0 ? null : steps[upcomingIndex];
    final following = upcomingIndex < 0 || upcomingIndex + 1 >= steps.length
        ? null
        : steps[upcomingIndex + 1];
    final maneuverOffset =
        upcoming == null || upcomingIndex == legIndex
        ? _route.lengthMeters
        : upcoming.startOffsetMeters;
    final distanceToManeuver = math.max(0.0, maneuverOffset - travelled);

    final offRouteThreshold =
        (config.offRouteBaseMeters + fix.accuracyMeters).clamp(
          config.offRouteMinMeters,
          config.offRouteMaxMeters,
        );

    var offRoute = _state?.offRoute ?? false;
    var rerouteRequired = false;
    // `lateralMeters` is the true distance to the route, so a fix far away from
    // it still drives the decision - that is exactly the case being detected.
    if (usable) {
      if (match.lateralMeters > offRouteThreshold) {
        offRoute = true;
        _offRouteSince ??= fix.timestamp;
        _offRouteAnchor ??= fix.position;
        _offRouteFixes++;
        final elapsed = fix.timestamp.difference(_offRouteSince!);
        final moved = SfGeo.distance(_offRouteAnchor!, fix.position);
        rerouteRequired =
            _offRouteFixes >= config.offRouteConfirmFixes &&
            elapsed >= config.offRouteConfirmDuration &&
            moved >= config.offRouteConfirmTravelMeters;
      } else if (match.lateralMeters < offRouteThreshold * 0.6) {
        // Hysteresis: re-joining the route has to be unambiguous, otherwise a
        // fix oscillating around the threshold restarts the timer forever.
        offRoute = false;
        _offRouteSince = null;
        _offRouteAnchor = null;
        _offRouteFixes = 0;
      }
    }

    final straightToDestination = SfGeo.distance(fix.position, destination);
    if (!_arrived &&
        (remaining <= config.arrivalRadiusMeters ||
            straightToDestination <= config.arrivalRadiusMeters)) {
      _arrived = true;
    }

    final hazard = _hazardAhead(travelled);
    final remainingDuration = _estimateRemaining(remaining);

    final phase = _arrived
        ? NavPhase.arrived
        : offRoute
        ? NavPhase.offRoute
        : NavPhase.guiding;

    final next = NavState(
      phase: phase,
      route: _route,
      snapped: match.snapped,
      courseDeg: match.courseDeg,
      travelledMeters: travelled,
      remainingMeters: remaining,
      remainingDuration: remainingDuration,
      eta: fix.timestamp.add(remainingDuration),
      legIndex: legIndex,
      upcomingStep: upcoming,
      followingStep: following,
      distanceToManeuverMeters: distanceToManeuver,
      currentRoadName: steps.isEmpty
          ? ''
          : steps[legIndex.clamp(0, steps.length - 1)].roadName,
      lateralMeters: match.lateralMeters,
      offRoute: offRoute,
      offRouteFor: _offRouteSince == null
          ? Duration.zero
          : fix.timestamp.difference(_offRouteSince!),
      rerouteRequired: rerouteRequired,
      speedKph: math.max(0, fix.speedMps) * 3.6,
      gpsUsable: usable,
      hazardAhead: hazard,
      hazardDistanceMeters: hazard == null
          ? null
          : math.max(0, hazard.offsetMeters - travelled),
    );
    _state = next;
    return next;
  }

  int _legIndexAt(double travelled) {
    final steps = _route.steps;
    if (steps.isEmpty) return 0;
    var index = 0;
    for (var candidate = 0; candidate < steps.length; candidate++) {
      if (steps[candidate].startOffsetMeters <= travelled + 1) {
        index = candidate;
      } else {
        break;
      }
    }
    return index;
  }

  NavHazardOnRoute? _hazardAhead(double travelled) {
    NavHazardOnRoute? nearest;
    for (final hazard in _route.hazardsOnRoute) {
      if (!hazard.onRoute) continue;
      final ahead = hazard.offsetMeters - travelled;
      if (ahead < -20 || ahead > config.hazardLookaheadMeters) continue;
      // A hard closure always outranks an advisory hazard, then proximity.
      final better =
          nearest == null ||
          (hazard.hazard.hardClosure && !nearest.hazard.hardClosure) ||
          (hazard.hazard.hardClosure == nearest.hazard.hardClosure &&
              hazard.offsetMeters < nearest.offsetMeters);
      if (better) nearest = hazard;
    }
    return nearest;
  }

  Duration _estimateRemaining(double remaining) {
    final total = _route.lengthMeters;
    final baseline = total <= 0 || _route.reportedDurationSeconds <= 0
        ? remaining / 8.5
        : _route.reportedDurationSeconds * (remaining / total);
    if (_movingSamples < 10 || _speedEma < 1.0) {
      return Duration(seconds: baseline.round());
    }
    // Blend the plan with what the vehicle is actually doing. Half weight keeps
    // a single traffic light from collapsing the ETA, while a genuinely slow
    // stretch still moves it.
    final live = remaining / math.max(_speedEma, 2.0);
    final blended = (baseline * 0.5 + live * 0.5).clamp(
      baseline * 0.5,
      baseline * 2.5,
    );
    return Duration(seconds: blended.round());
  }
}

/// Formats a distance the way a Vietnamese driver reads it on the banner.
String formatDistance(double meters) {
  if (meters >= 10000) return '${(meters / 1000).round()} km';
  // Switch to kilometres as soon as the metre reading would round up to a
  // whole one: 997 m has to read "1,0 km", never "1000 m".
  if (meters >= 950) {
    // Rounded on the integer decimetre rather than through toStringAsFixed,
    // whose binary representation turns 1450 m into "1.4 km".
    final tenths = (meters / 100).round();
    return tenths % 10 == 0 && tenths >= 100
        ? '${tenths ~/ 10} km'
        : '${tenths ~/ 10},${tenths % 10} km';
  }
  if (meters >= 100) return '${(meters / 10).round() * 10} m';
  return '${(meters / 5).round() * 5} m';
}

String formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  if (minutes >= 60) {
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '$hours giờ' : '$hours giờ $rest phút';
  }
  return '${math.max(1, minutes)} phút';
}

/// Instruction text for the banner, kept short enough to read at a glance.
String bannerInstruction(NavStep? step) {
  if (step == null) return 'Tiếp tục theo tuyến';
  final instruction = step.instruction.trim();
  if (instruction.isNotEmpty) return instruction;
  final road = step.roadName.trim();
  return road.isEmpty
      ? step.maneuver.shortPhrase
      : '${step.maneuver.shortPhrase} vào $road';
}

SfManeuver bannerManeuver(NavStep? step) =>
    step?.maneuver ?? SfManeuver.straightOn;
