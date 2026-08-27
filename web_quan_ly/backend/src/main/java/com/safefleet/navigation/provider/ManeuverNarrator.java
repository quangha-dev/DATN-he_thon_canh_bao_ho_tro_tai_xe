package com.safefleet.navigation.provider;

/**
 * Builds the Vietnamese sentence shown on a navigation step.
 *
 * <p>Neither Valhalla nor OSRM ships Vietnamese narrative strings, so the text
 * is generated from the normalised maneuver instead of being translated. The
 * mobile client prepends its own distance phrase ("Sau 300 mét, ...") when it
 * speaks the step, so the sentence produced here never contains a distance.</p>
 */
public final class ManeuverNarrator {

    private ManeuverNarrator() {
    }

    public static String describe(ManeuverType maneuver,
                                  String roadName,
                                  Integer roundaboutExitCount,
                                  String exitNumber,
                                  String toward) {
        String road = blank(roadName) ? "" : " vào " + roadName.trim();
        String onRoad = blank(roadName) ? "" : " trên " + roadName.trim();
        String exit = blank(exitNumber) ? "" : " số " + exitNumber.trim();
        String destination = blank(toward) ? "" : " hướng " + toward.trim();

        return switch (maneuver) {
            case DEPART -> blank(roadName) ? "Bắt đầu hành trình" : "Bắt đầu đi" + onRoad;
            case CONTINUE -> blank(roadName) ? "Tiếp tục đi thẳng" : "Đi thẳng" + onRoad;
            case KEEP_LEFT -> "Đi theo làn bên trái" + road + destination;
            case KEEP_RIGHT -> "Đi theo làn bên phải" + road + destination;
            case TURN_SLIGHT_LEFT -> "Rẽ chếch trái" + road;
            case TURN_LEFT -> "Rẽ trái" + road;
            case TURN_SHARP_LEFT -> "Rẽ gấp trái" + road;
            case TURN_SLIGHT_RIGHT -> "Rẽ chếch phải" + road;
            case TURN_RIGHT -> "Rẽ phải" + road;
            case TURN_SHARP_RIGHT -> "Rẽ gấp phải" + road;
            case UTURN_LEFT, UTURN_RIGHT -> "Quay đầu xe" + road;
            case RAMP_LEFT -> "Đi vào đường dẫn bên trái" + destination;
            case RAMP_RIGHT -> "Đi vào đường dẫn bên phải" + destination;
            case RAMP_STRAIGHT -> "Đi vào đường dẫn" + destination;
            case EXIT_LEFT -> "Đi theo lối ra bên trái" + exit + destination;
            case EXIT_RIGHT -> "Đi theo lối ra bên phải" + exit + destination;
            case MERGE_LEFT -> "Nhập làn về bên trái" + road;
            case MERGE_RIGHT -> "Nhập làn về bên phải" + road;
            case MERGE_STRAIGHT -> "Nhập làn" + road;
            case ROUNDABOUT_ENTER -> roundaboutExitCount == null || roundaboutExitCount <= 0
                    ? "Đi vào vòng xuyến"
                    : "Vào vòng xuyến, đi theo lối ra thứ " + roundaboutExitCount;
            case ROUNDABOUT_EXIT -> "Ra khỏi vòng xuyến" + road;
            case FERRY_ENTER -> "Lên phà";
            case FERRY_EXIT -> "Rời phà" + road;
            case ARRIVE -> "Đã đến điểm đến";
            case ARRIVE_LEFT -> "Điểm đến ở bên trái";
            case ARRIVE_RIGHT -> "Điểm đến ở bên phải";
        };
    }

    private static boolean blank(String value) {
        return value == null || value.isBlank();
    }
}
