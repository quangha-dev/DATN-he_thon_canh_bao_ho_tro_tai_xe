package com.safefleet.navigation;

/**
 * One turn instruction.
 *
 * @param maneuver          normalised {@code ManeuverType} name; the app maps it
 *                          straight to an icon and a spoken phrase
 * @param maneuverType      same value, kept under the old key so an app build
 *                          released before the normalisation still renders
 * @param beginShapeIndex   index into the route geometry where the maneuver
 *                          happens, so the device measures the distance to the
 *                          turn on the same polyline it map-matches onto
 */
public record NavigationStepResponse(
        String instruction,
        String roadName,
        Double distanceMeters,
        Double durationSeconds,
        String maneuver,
        String maneuverType,
        String modifier,
        Integer beginShapeIndex,
        Integer roundaboutExitCount,
        String exitNumber,
        String toward,
        Double lat,
        Double lng
) {
}
