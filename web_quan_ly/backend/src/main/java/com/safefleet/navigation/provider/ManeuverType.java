package com.safefleet.navigation.provider;

/**
 * Provider-independent turn taxonomy.
 *
 * <p>Valhalla reports numeric maneuver codes and OSRM reports a
 * {@code type}/{@code modifier} pair. Neither is safe to forward to a driver
 * device: the mobile client would have to re-implement two vendor mappings and
 * would silently fall back to a "go straight" arrow for anything it does not
 * recognise. Both providers are normalised into this enum instead, so the app
 * renders one icon set and speaks one phrase set.</p>
 */
public enum ManeuverType {

    DEPART,
    CONTINUE,
    KEEP_LEFT,
    KEEP_RIGHT,
    TURN_SLIGHT_LEFT,
    TURN_LEFT,
    TURN_SHARP_LEFT,
    TURN_SLIGHT_RIGHT,
    TURN_RIGHT,
    TURN_SHARP_RIGHT,
    UTURN_LEFT,
    UTURN_RIGHT,
    RAMP_LEFT,
    RAMP_RIGHT,
    RAMP_STRAIGHT,
    EXIT_LEFT,
    EXIT_RIGHT,
    MERGE_LEFT,
    MERGE_RIGHT,
    MERGE_STRAIGHT,
    ROUNDABOUT_ENTER,
    ROUNDABOUT_EXIT,
    FERRY_ENTER,
    FERRY_EXIT,
    ARRIVE,
    ARRIVE_LEFT,
    ARRIVE_RIGHT;

    /** Coarse side used by legacy clients that still read {@code modifier}. */
    public String modifier() {
        return switch (this) {
            case KEEP_LEFT, TURN_SLIGHT_LEFT, TURN_LEFT, TURN_SHARP_LEFT,
                 RAMP_LEFT, EXIT_LEFT, MERGE_LEFT, ARRIVE_LEFT -> "left";
            case KEEP_RIGHT, TURN_SLIGHT_RIGHT, TURN_RIGHT, TURN_SHARP_RIGHT,
                 RAMP_RIGHT, EXIT_RIGHT, MERGE_RIGHT, ARRIVE_RIGHT -> "right";
            case UTURN_LEFT, UTURN_RIGHT -> "uturn";
            case ROUNDABOUT_ENTER, ROUNDABOUT_EXIT -> "roundabout";
            default -> "straight";
        };
    }

    /**
     * True when the driver has to actively change direction. Guidance uses this
     * to decide whether a maneuver deserves a far-distance pre-announcement;
     * lane keeps and "continue" steps only get a reminder when they are long.
     */
    public boolean isDirectionChange() {
        return switch (this) {
            case DEPART, CONTINUE, KEEP_LEFT, KEEP_RIGHT, MERGE_STRAIGHT, RAMP_STRAIGHT -> false;
            default -> true;
        };
    }

    /** Maps Valhalla's {@code DirectionsLeg.Maneuver.Type} ordinal. */
    public static ManeuverType fromValhalla(int type) {
        return switch (type) {
            case 1, 2, 3 -> DEPART;
            case 4 -> ARRIVE;
            case 5 -> ARRIVE_RIGHT;
            case 6 -> ARRIVE_LEFT;
            case 9 -> TURN_SLIGHT_RIGHT;
            case 10 -> TURN_RIGHT;
            case 11 -> TURN_SHARP_RIGHT;
            case 12 -> UTURN_RIGHT;
            case 13 -> UTURN_LEFT;
            case 14 -> TURN_SHARP_LEFT;
            case 15 -> TURN_LEFT;
            case 16 -> TURN_SLIGHT_LEFT;
            case 17 -> RAMP_STRAIGHT;
            case 18 -> RAMP_RIGHT;
            case 19 -> RAMP_LEFT;
            case 20 -> EXIT_RIGHT;
            case 21 -> EXIT_LEFT;
            case 23 -> KEEP_RIGHT;
            case 24 -> KEEP_LEFT;
            case 25 -> MERGE_STRAIGHT;
            case 26 -> ROUNDABOUT_ENTER;
            case 27 -> ROUNDABOUT_EXIT;
            case 28 -> FERRY_ENTER;
            case 29 -> FERRY_EXIT;
            case 38 -> MERGE_RIGHT;
            case 39 -> MERGE_LEFT;
            // 0 (none), 7 (becomes), 8 (continue), 22 (stay straight) and every
            // transit/pedestrian code degrade to a straight-ahead instruction.
            default -> CONTINUE;
        };
    }

    /** Maps an OSRM {@code maneuver.type} plus {@code maneuver.modifier} pair. */
    public static ManeuverType fromOsrm(String type, String modifier) {
        String maneuver = type == null ? "" : type.trim().toLowerCase();
        String side = modifier == null ? "" : modifier.trim().toLowerCase();
        return switch (maneuver) {
            case "depart" -> DEPART;
            case "arrive" -> switch (side) {
                case "left" -> ARRIVE_LEFT;
                case "right" -> ARRIVE_RIGHT;
                default -> ARRIVE;
            };
            case "roundabout", "rotary", "roundabout turn" -> ROUNDABOUT_ENTER;
            case "exit roundabout", "exit rotary" -> ROUNDABOUT_EXIT;
            case "on ramp" -> switch (side) {
                case "left", "slight left", "sharp left" -> RAMP_LEFT;
                case "right", "slight right", "sharp right" -> RAMP_RIGHT;
                default -> RAMP_STRAIGHT;
            };
            case "off ramp" -> "left".equals(side) || "slight left".equals(side)
                    || "sharp left".equals(side) ? EXIT_LEFT : EXIT_RIGHT;
            case "merge" -> switch (side) {
                case "left", "slight left", "sharp left" -> MERGE_LEFT;
                case "right", "slight right", "sharp right" -> MERGE_RIGHT;
                default -> MERGE_STRAIGHT;
            };
            case "fork", "continue", "new name", "notification" -> switch (side) {
                case "left", "slight left" -> "continue".equals(maneuver) ? TURN_LEFT : KEEP_LEFT;
                case "right", "slight right" -> "continue".equals(maneuver) ? TURN_RIGHT : KEEP_RIGHT;
                case "uturn" -> UTURN_LEFT;
                default -> CONTINUE;
            };
            // "turn", "end of road" and anything unknown are driven by modifier.
            default -> fromModifier(side);
        };
    }

    private static ManeuverType fromModifier(String side) {
        return switch (side) {
            case "sharp left" -> TURN_SHARP_LEFT;
            case "left" -> TURN_LEFT;
            case "slight left" -> TURN_SLIGHT_LEFT;
            case "sharp right" -> TURN_SHARP_RIGHT;
            case "right" -> TURN_RIGHT;
            case "slight right" -> TURN_SLIGHT_RIGHT;
            case "uturn" -> UTURN_LEFT;
            default -> CONTINUE;
        };
    }
}
