import 'package:flutter/material.dart';

import '../../../core/widgets/ui.dart';
import '../engine/nav_route.dart';
import '../engine/navigation_engine.dart';

/// The instruction banner: the one thing a driver may look at mid-junction.
///
/// It leads with the distance to the next maneuver — measured on the polyline
/// the vehicle is matched onto — then the instruction, then a muted preview of
/// the maneuver after it.
class NavigationInstructionBanner extends StatelessWidget {
  const NavigationInstructionBanner({
    super.key,
    required this.state,
    this.rerouting = false,
  });

  final NavState? state;
  final bool rerouting;

  @override
  Widget build(BuildContext context) {
    final current = state;
    final offRoute = current?.offRoute == true;
    final step = current?.upcomingStep;
    final following = current?.followingStep;

    return Container(
      padding: const EdgeInsets.all(SfSpace.x16),
      decoration: BoxDecoration(
        color: offRoute
            ? SfColors.warning
            : SfColors.green700.withValues(alpha: .97),
        borderRadius: SfRadius.heroR,
        boxShadow: SfShadow.dock,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                rerouting
                    ? Icons.autorenew_rounded
                    : offRoute
                    ? Icons.report_problem_rounded
                    : bannerManeuver(step).icon,
                size: 54,
                color: SfColors.onAccent,
              ),
              const SizedBox(width: SfSpace.x14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!offRoute && !rerouting && current != null)
                      Text(
                        formatDistance(current.distanceToManeuverMeters),
                        style: SfType.titleCard.copyWith(
                          color: SfColors.onAccent,
                          fontSize: 34,
                          height: 1.05,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    Text(
                      rerouting
                          ? 'Đang tìm tuyến mới…'
                          : offRoute
                          ? 'Đã đi lệch tuyến — quay lại đường màu xanh'
                          : bannerInstruction(step),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: SfType.titleCard.copyWith(
                        color: SfColors.onAccent,
                        fontSize: SfTouch.driveFontFloor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!offRoute && !rerouting && following != null)
            Padding(
              padding: const EdgeInsets.only(top: SfSpace.x10),
              child: Row(
                children: [
                  Icon(
                    following.maneuver.icon,
                    size: 20,
                    color: SfColors.green300,
                  ),
                  const SizedBox(width: SfSpace.x8),
                  Expanded(
                    child: Text(
                      'Sau đó ${following.maneuver.shortPhrase.toLowerCase()}'
                      '${following.roadName.isEmpty ? '' : ' vào ${following.roadName}'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SfType.bodySm.copyWith(color: SfColors.green300),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Warns about the closure or jam the route still runs through.
class NavigationHazardBanner extends StatelessWidget {
  const NavigationHazardBanner({
    super.key,
    required this.hazard,
    required this.distanceMeters,
  });

  final NavHazardOnRoute hazard;
  final double distanceMeters;

  @override
  Widget build(BuildContext context) => SfInfoBox(
    icon: hazard.hazard.isTrafficJam
        ? Icons.directions_car_filled_rounded
        : Icons.water_drop_rounded,
    status: hazard.hazard.hardClosure ? SfStatus.danger : SfStatus.warning,
    text:
        '${hazard.hazard.hardClosure ? 'Đường bị chặn do' : 'Cảnh báo'} '
        '${hazard.hazard.label}, cách ${formatDistance(distanceMeters)}'
        '${hazard.hazard.address == null ? '' : ' · ${hazard.hazard.address}'}',
  );
}

class NavigationArrivalCard extends StatelessWidget {
  const NavigationArrivalCard({
    super.key,
    required this.destination,
    required this.onClose,
  });

  final String destination;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => SfCard(
    radius: SfRadius.hero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Icon(Icons.flag_rounded, color: SfColors.green700, size: 30),
            const SizedBox(width: SfSpace.x12),
            Expanded(
              child: Text(
                'Đã đến $destination',
                style: SfType.titleCard,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: SfSpace.x14),
        SfPrimaryAction(
          label: 'Kết thúc dẫn đường',
          icon: Icons.check_rounded,
          onPressed: onClose,
        ),
      ],
    ),
  );
}

/// ETA, remaining distance, connection state and the driving-mode controls.
class NavigationProgressDock extends StatelessWidget {
  const NavigationProgressDock({
    super.key,
    required this.state,
    required this.route,
    required this.online,
    required this.muted,
    required this.onMute,
    required this.onStop,
    this.simulating = false,
    this.reporting = false,
    this.onSimulate,
    this.onReport,
    this.onAgent,
  });

  final NavState? state;
  final NavRoute route;
  final bool online;
  final bool muted;
  final bool simulating;
  final bool reporting;
  final VoidCallback onMute;
  final VoidCallback onStop;
  final VoidCallback? onSimulate;
  final VoidCallback? onReport;
  final VoidCallback? onAgent;

  @override
  Widget build(BuildContext context) {
    final current = state;
    return Container(
      padding: const EdgeInsets.all(SfSpace.x12),
      decoration: BoxDecoration(
        color: SfColors.darkSurface.withValues(alpha: .97),
        borderRadius: SfRadius.heroR,
        boxShadow: SfShadow.dock,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      current == null
                          ? 'Đang định vị…'
                          : '${_clock(current.eta)}'
                                ' · ${formatDuration(current.remainingDuration)}'
                                ' · ${formatDistance(current.remainingMeters)}',
                      style: SfType.titleCardSm.copyWith(
                        color: SfColors.darkTextPrimary,
                      ),
                    ),
                    const SizedBox(height: SfSpace.x4),
                    Wrap(
                      spacing: SfSpace.x8,
                      runSpacing: SfSpace.x4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SfStatusPill(
                          online ? 'Trực tuyến' : 'Ngoại tuyến',
                          status: online ? SfStatus.good : SfStatus.warning,
                          dense: true,
                        ),
                        // A degraded graph could not apply the closure list, so
                        // this route must not read as flood-checked.
                        if (route.providerFallback)
                          const SfStatusPill(
                            'Tuyến suy giảm',
                            status: SfStatus.warning,
                            dense: true,
                          ),
                        if (simulating)
                          const SfStatusPill(
                            'Đang chạy thử',
                            status: SfStatus.pending,
                            dense: true,
                          ),
                        if (current?.gpsUsable == false)
                          const SfStatusPill(
                            'GPS yếu',
                            status: SfStatus.warning,
                            dense: true,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              SfIconButton(
                icon: muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                onDark: true,
                tooltip: muted ? 'Bật giọng dẫn đường' : 'Tắt giọng dẫn đường',
                onTap: onMute,
              ),
            ],
          ),
          const SizedBox(height: SfSpace.x10),
          Row(
            children: [
              Expanded(
                child: SfPrimaryAction(
                  label: 'Kết thúc',
                  icon: Icons.close_rounded,
                  onPressed: onStop,
                ),
              ),
              if (onReport != null) ...[
                const SizedBox(width: SfSpace.x8),
                SfIconButton(
                  icon: reporting
                      ? Icons.hourglass_top_rounded
                      : Icons.add_road_rounded,
                  onDark: true,
                  tooltip: 'Báo ngập hoặc kẹt xe tại đây',
                  onTap: reporting ? null : onReport,
                ),
              ],
              if (onAgent != null) ...[
                const SizedBox(width: SfSpace.x8),
                SfIconButton(
                  icon: Icons.mic_rounded,
                  onDark: true,
                  tooltip: 'Mở trợ lý giọng nói',
                  onTap: onAgent,
                ),
              ],
              if (onSimulate != null) ...[
                const SizedBox(width: SfSpace.x8),
                SfIconButton(
                  icon: simulating
                      ? Icons.stop_rounded
                      : Icons.play_arrow_rounded,
                  onDark: true,
                  tooltip: 'Chạy thử tuyến',
                  onTap: onSimulate,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static String _clock(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';
}
