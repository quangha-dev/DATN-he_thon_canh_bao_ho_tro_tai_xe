import 'package:flutter/material.dart';

/// Turn taxonomy shared with the backend.
///
/// The routing providers speak two different dialects — Valhalla returns
/// numeric maneuver codes, OSRM returns a `type`/`modifier` pair — and the
/// backend normalises both onto this list before the route reaches the device.
/// The app therefore never inspects a raw provider value, which is what used to
/// make every turn render as a "go straight" arrow.
enum SfManeuver {
  depart,
  straightOn,
  keepLeft,
  keepRight,
  slightLeft,
  left,
  sharpLeft,
  slightRight,
  right,
  sharpRight,
  uturnLeft,
  uturnRight,
  rampLeft,
  rampRight,
  rampStraight,
  exitLeft,
  exitRight,
  mergeLeft,
  mergeRight,
  mergeStraight,
  roundaboutEnter,
  roundaboutExit,
  ferryEnter,
  ferryExit,
  arrive,
  arriveLeft,
  arriveRight;

  static const _byName = <String, SfManeuver>{
    'DEPART': SfManeuver.depart,
    'CONTINUE': SfManeuver.straightOn,
    'KEEP_LEFT': SfManeuver.keepLeft,
    'KEEP_RIGHT': SfManeuver.keepRight,
    'TURN_SLIGHT_LEFT': SfManeuver.slightLeft,
    'TURN_LEFT': SfManeuver.left,
    'TURN_SHARP_LEFT': SfManeuver.sharpLeft,
    'TURN_SLIGHT_RIGHT': SfManeuver.slightRight,
    'TURN_RIGHT': SfManeuver.right,
    'TURN_SHARP_RIGHT': SfManeuver.sharpRight,
    'UTURN_LEFT': SfManeuver.uturnLeft,
    'UTURN_RIGHT': SfManeuver.uturnRight,
    'RAMP_LEFT': SfManeuver.rampLeft,
    'RAMP_RIGHT': SfManeuver.rampRight,
    'RAMP_STRAIGHT': SfManeuver.rampStraight,
    'EXIT_LEFT': SfManeuver.exitLeft,
    'EXIT_RIGHT': SfManeuver.exitRight,
    'MERGE_LEFT': SfManeuver.mergeLeft,
    'MERGE_RIGHT': SfManeuver.mergeRight,
    'MERGE_STRAIGHT': SfManeuver.mergeStraight,
    'ROUNDABOUT_ENTER': SfManeuver.roundaboutEnter,
    'ROUNDABOUT_EXIT': SfManeuver.roundaboutExit,
    'FERRY_ENTER': SfManeuver.ferryEnter,
    'FERRY_EXIT': SfManeuver.ferryExit,
    'ARRIVE': SfManeuver.arrive,
    'ARRIVE_LEFT': SfManeuver.arriveLeft,
    'ARRIVE_RIGHT': SfManeuver.arriveRight,
  };

  /// Reads the normalised `maneuver` field, falling back to the coarse
  /// `modifier` so a route cached by an older app build still renders an arrow
  /// pointing the right way.
  static SfManeuver parse(String? maneuver, {String? modifier}) {
    final normalized = maneuver?.trim().toUpperCase();
    final direct = normalized == null ? null : _byName[normalized];
    if (direct != null) return direct;
    switch (modifier?.trim().toLowerCase()) {
      case 'left':
        return SfManeuver.left;
      case 'right':
        return SfManeuver.right;
      case 'uturn':
        return SfManeuver.uturnLeft;
      case 'roundabout':
        return SfManeuver.roundaboutEnter;
      default:
        return SfManeuver.straightOn;
    }
  }

  /// True when the driver has to actively change direction, which is what
  /// earns a maneuver a far-distance pre-announcement.
  bool get isDirectionChange => switch (this) {
    SfManeuver.depart ||
    SfManeuver.straightOn ||
    SfManeuver.mergeStraight ||
    SfManeuver.rampStraight => false,
    _ => true,
  };

  bool get isArrival => switch (this) {
    SfManeuver.arrive || SfManeuver.arriveLeft || SfManeuver.arriveRight => true,
    _ => false,
  };

  IconData get icon => switch (this) {
    SfManeuver.depart => Icons.trip_origin_rounded,
    SfManeuver.straightOn => Icons.straight_rounded,
    SfManeuver.keepLeft => Icons.fork_left_rounded,
    SfManeuver.keepRight => Icons.fork_right_rounded,
    SfManeuver.slightLeft => Icons.turn_slight_left_rounded,
    SfManeuver.left => Icons.turn_left_rounded,
    SfManeuver.sharpLeft => Icons.turn_sharp_left_rounded,
    SfManeuver.slightRight => Icons.turn_slight_right_rounded,
    SfManeuver.right => Icons.turn_right_rounded,
    SfManeuver.sharpRight => Icons.turn_sharp_right_rounded,
    SfManeuver.uturnLeft => Icons.u_turn_left_rounded,
    SfManeuver.uturnRight => Icons.u_turn_right_rounded,
    SfManeuver.rampLeft => Icons.ramp_left_rounded,
    SfManeuver.rampRight => Icons.ramp_right_rounded,
    SfManeuver.rampStraight => Icons.straight_rounded,
    SfManeuver.exitLeft => Icons.ramp_left_rounded,
    SfManeuver.exitRight => Icons.ramp_right_rounded,
    SfManeuver.mergeLeft => Icons.merge_rounded,
    SfManeuver.mergeRight => Icons.merge_rounded,
    SfManeuver.mergeStraight => Icons.merge_rounded,
    SfManeuver.roundaboutEnter => Icons.roundabout_right_rounded,
    SfManeuver.roundaboutExit => Icons.roundabout_left_rounded,
    SfManeuver.ferryEnter => Icons.directions_boat_rounded,
    SfManeuver.ferryExit => Icons.directions_boat_rounded,
    SfManeuver.arrive => Icons.flag_rounded,
    SfManeuver.arriveLeft => Icons.flag_rounded,
    SfManeuver.arriveRight => Icons.flag_rounded,
  };

  /// Short spoken form used when the full instruction is too long to be useful
  /// at the moment the driver is already in the turn.
  String get shortPhrase => switch (this) {
    SfManeuver.depart => 'Bắt đầu đi',
    SfManeuver.straightOn => 'Đi thẳng',
    SfManeuver.keepLeft => 'Đi làn bên trái',
    SfManeuver.keepRight => 'Đi làn bên phải',
    SfManeuver.slightLeft => 'Rẽ chếch trái',
    SfManeuver.left => 'Rẽ trái',
    SfManeuver.sharpLeft => 'Rẽ gấp trái',
    SfManeuver.slightRight => 'Rẽ chếch phải',
    SfManeuver.right => 'Rẽ phải',
    SfManeuver.sharpRight => 'Rẽ gấp phải',
    SfManeuver.uturnLeft || SfManeuver.uturnRight => 'Quay đầu xe',
    SfManeuver.rampLeft => 'Vào đường dẫn bên trái',
    SfManeuver.rampRight => 'Vào đường dẫn bên phải',
    SfManeuver.rampStraight => 'Vào đường dẫn',
    SfManeuver.exitLeft => 'Đi lối ra bên trái',
    SfManeuver.exitRight => 'Đi lối ra bên phải',
    SfManeuver.mergeLeft => 'Nhập làn bên trái',
    SfManeuver.mergeRight => 'Nhập làn bên phải',
    SfManeuver.mergeStraight => 'Nhập làn',
    SfManeuver.roundaboutEnter => 'Vào vòng xuyến',
    SfManeuver.roundaboutExit => 'Ra khỏi vòng xuyến',
    SfManeuver.ferryEnter => 'Lên phà',
    SfManeuver.ferryExit => 'Rời phà',
    SfManeuver.arrive => 'Đã đến nơi',
    SfManeuver.arriveLeft => 'Điểm đến bên trái',
    SfManeuver.arriveRight => 'Điểm đến bên phải',
  };
}
