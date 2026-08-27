package com.safefleet.navigation.provider;

import java.util.List;

public interface RoutingProvider {

    List<ProviderRoute> routes(List<GeoPoint> points, boolean alternatives);

    default List<ProviderRoute> routes(List<GeoPoint> points,
                                       boolean alternatives,
                                       List<GeoPoint> excludedLocations) {
        return routes(points, alternatives);
    }

    default List<ProviderRoute> routes(List<GeoPoint> points,
                                       boolean alternatives,
                                       RoutingExclusions exclusions) {
        return routes(points, alternatives, exclusions.locations());
    }

    default List<ProviderRoute> routes(List<GeoPoint> points,
                                       boolean alternatives,
                                       RoutingExclusions exclusions,
                                       VehicleRoutingProfile profile) {
        return routes(points, alternatives, exclusions);
    }

    record GeoPoint(double lat, double lng) {
    }

    record RoutingExclusions(
            List<GeoPoint> locations,
            List<List<GeoPoint>> polygons
    ) {
        public RoutingExclusions {
            locations = locations == null ? List.of() : List.copyOf(locations);
            polygons = polygons == null ? List.of() : polygons.stream().map(List::copyOf).toList();
        }

        public static RoutingExclusions empty() {
            return new RoutingExclusions(List.of(), List.of());
        }
    }

    /**
     * Physical and legal properties that can change whether a road is safe for
     * the assigned vehicle. Null dimensions intentionally let the routing graph
     * use its conservative defaults instead of guessing from payload capacity.
     */
    record VehicleRoutingProfile(
            String costing,
            Double heightMeters,
            Double widthMeters,
            Double lengthMeters,
            Double grossWeightTons,
            Double axleLoadTons,
            Integer axleCount,
            Double topSpeedKph,
            boolean hazardousGoods
    ) {
        public VehicleRoutingProfile {
            costing = costing == null || costing.isBlank() ? "truck" : costing.trim();
        }

        public static VehicleRoutingProfile conservativeTruck() {
            return new VehicleRoutingProfile("truck", null, null, null, null,
                    null, null, null, false);
        }

        public boolean requiresValhalla() {
            return !"auto".equalsIgnoreCase(costing)
                    || heightMeters != null
                    || widthMeters != null
                    || lengthMeters != null
                    || grossWeightTons != null
                    || axleLoadTons != null
                    || axleCount != null
                    || topSpeedKph != null
                    || hazardousGoods;
        }
    }

    /**
     * One guidance step.
     *
     * <p>{@code beginShapeIndex} is the index into {@link ProviderRoute#geometry()}
     * where the maneuver happens. The driver app measures "distance to the next
     * turn" against the same polyline it map-matches onto, so the offset must
     * come from the shape rather than from a sum of step lengths, which drifts
     * a few percent away from the geometry.</p>
     */
    record TurnStep(
            String instruction,
            String roadName,
            double distanceMeters,
            double durationSeconds,
            ManeuverType maneuver,
            GeoPoint location,
            int beginShapeIndex,
            Integer roundaboutExitCount,
            String exitNumber,
            String toward
    ) {
        public TurnStep {
            maneuver = maneuver == null ? ManeuverType.CONTINUE : maneuver;
            beginShapeIndex = Math.max(0, beginShapeIndex);
        }

        public TurnStep(String instruction,
                        String roadName,
                        double distanceMeters,
                        double durationSeconds,
                        ManeuverType maneuver,
                        GeoPoint location) {
            this(instruction, roadName, distanceMeters, durationSeconds, maneuver,
                    location, 0, null, null, null);
        }

        /** Legacy field kept so older app builds keep rendering a turn arrow. */
        public String maneuverType() {
            return maneuver.name();
        }

        /** Legacy field: coarse left/right/uturn/roundabout/straight side. */
        public String modifier() {
            return maneuver.modifier();
        }
    }

    record ProviderRoute(
            double distanceMeters,
            double durationSeconds,
            List<GeoPoint> geometry,
            List<TurnStep> steps,
            String provider,
            boolean fallback,
            List<GeoPoint> navigationWaypoints
    ) {
        public ProviderRoute {
            geometry = geometry == null ? List.of() : List.copyOf(geometry);
            steps = steps == null ? List.of() : List.copyOf(steps);
            navigationWaypoints = navigationWaypoints == null
                    ? List.of()
                    : List.copyOf(navigationWaypoints);
        }

        public ProviderRoute(
                double distanceMeters,
                double durationSeconds,
                List<GeoPoint> geometry,
                List<TurnStep> steps,
                String provider,
                boolean fallback
        ) {
            this(distanceMeters, durationSeconds, geometry, steps, provider, fallback, List.of());
        }
    }
}
