import 'dart:async';

import 'package:flutter/material.dart';

/// Returns `true` when running in a live application (Edge, Chrome, Desktop, Mobile)
/// and `false` when running under `flutter_test`'s `TestWidgetsFlutterBinding`
/// so `tester.pumpAndSettle()` never hangs on infinite periodic timers.
bool get isRealtimeSyncSupported =>
    !WidgetsBinding.instance.runtimeType.toString().contains('Test');

/// Starts a periodic real-time callback while a widget or controller is active.
Timer? startRealtimePeriodicSync({
  required Duration interval,
  required FutureOr<void> Function() onTick,
}) {
  if (!isRealtimeSyncSupported) {
    return null;
  }
  var isRunning = false;
  return Timer.periodic(interval, (_) async {
    if (isRunning) return;
    isRunning = true;
    try {
      await onTick();
    } catch (_) {
      // Ignore transient network errors during background real-time sync.
    } finally {
      isRunning = false;
    }
  });
}

/// Small visual badge indicating that a screen is syncing in real-time.
class RealtimeLiveBadge extends StatelessWidget {
  const RealtimeLiveBadge({
    super.key,
    this.label = 'Realtime',
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Color(0xFF10B981),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF047857),
            ),
          ),
        ],
      ),
    );
  }
}
