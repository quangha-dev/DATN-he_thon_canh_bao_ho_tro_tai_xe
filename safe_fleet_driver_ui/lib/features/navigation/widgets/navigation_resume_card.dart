import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app.dart';
import '../../../core/widgets/ui.dart';
import '../../../models/driver_models.dart';
import '../engine/nav_route.dart';
import '../engine/navigation_engine.dart';
import '../turn_by_turn_screen.dart';

/// The navigation session the driver has open, if any.
///
/// Falls back to the copy cached in SQLite when the phone is offline, so a
/// driver who lost signal mid-route still gets offered their route back.
final activeNavigationProvider = FutureProvider.autoDispose<NavSession?>((
  ref,
) async {
  final session = await ref.read(driverRepositoryProvider).currentNavigation();
  // A session with no destination cannot be resumed, so it must not be offered.
  if (session == null || session.isEmpty || session.destination == null) {
    return null;
  }
  return session;
});

/// Brings a driver back into guidance they left.
///
/// Killing the app, taking a call or stepping out of the cab used to strand an
/// active route: it stayed open on the server but nothing on screen led back to
/// it, and the driver had to search the destination again. Guidance is the one
/// task that must survive leaving the app.
class NavigationResumeCard extends ConsumerWidget {
  const NavigationResumeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeNavigationProvider);
    return active.maybeWhen(
      data: (session) =>
          session == null ? const SizedBox.shrink() : _Card(session: session),
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _Card extends ConsumerStatefulWidget {
  const _Card({required this.session});

  final NavSession session;

  @override
  ConsumerState<_Card> createState() => _CardState();
}

class _CardState extends ConsumerState<_Card> {
  bool _busy = false;

  LocationPoint get _destination {
    final point = widget.session.destination;
    final name = widget.session.destinationName?.trim();
    return LocationPoint(
      name: name == null || name.isEmpty ? 'Điểm đến đã lưu' : name,
      address: point == null
          ? ''
          : '${point.latitude.toStringAsFixed(5)}, '
                '${point.longitude.toStringAsFixed(5)}',
      lat: point?.latitude ?? 0,
      lng: point?.longitude ?? 0,
      source: 'RESUMED_SESSION',
    );
  }

  Future<void> _resume() async {
    if (widget.session.destination == null) return;
    await Navigator.of(context).push<void>(
      SfDriveRoute<void>(
        builder: (_) => TurnByTurnScreen(
          session: widget.session,
          destination: _destination,
        ),
      ),
    );
    if (mounted) ref.invalidate(activeNavigationProvider);
  }

  Future<void> _discard() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(driverRepositoryProvider)
          .completeNavigation(
            sessionId: widget.session.sessionId,
            reason: 'CANCELLED',
          );
    } catch (_) {
      // The next routing request supersedes the session anyway.
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        ref.invalidate(activeNavigationProvider);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.session.selected;
    final p = context.sf;

    return Padding(
      padding: const EdgeInsets.only(bottom: SfSpace.x12),
      child: SfCard(
        emphasis: SfStatus.pending,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.navigation_rounded,
                  color: SfColors.green700,
                  size: 26,
                ),
                const SizedBox(width: SfSpace.x12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Đang dẫn đường',
                        style: SfType.caption.copyWith(color: p.textMuted),
                      ),
                      Text(
                        _destination.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SfType.titleCardSm.copyWith(
                          color: p.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (route.providerFallback)
                  const SfStatusPill(
                    'Tuyến suy giảm',
                    status: SfStatus.warning,
                    dense: true,
                  ),
              ],
            ),
            const SizedBox(height: SfSpace.x8),
            Text(
              '${formatDistance(route.lengthMeters)} · '
              '${formatDuration(Duration(seconds: route.reportedDurationSeconds.round()))}'
              '${route.hazardsOnRouteCount == 0 ? '' : ' · ${route.hazardsOnRouteCount} điểm ngập trên tuyến'}',
              style: SfType.caption.copyWith(color: p.textMuted),
            ),
            const SizedBox(height: SfSpace.x14),
            Row(
              children: [
                Expanded(
                  child: SfPrimaryAction(
                    label: 'Tiếp tục dẫn đường',
                    icon: Icons.navigation_rounded,
                    onPressed: _busy ? null : () => unawaited(_resume()),
                  ),
                ),
                const SizedBox(width: SfSpace.x10),
                SfIconButton(
                  icon: Icons.close_rounded,
                  size: SfTouch.primaryHeight,
                  tooltip: 'Kết thúc phiên dẫn đường',
                  onTap: _busy ? null : () => unawaited(_discard()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
