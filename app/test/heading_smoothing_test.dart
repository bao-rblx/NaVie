import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:navie/features/driver/navigation_progress.dart';

void main() {
  // A route that turns 90 degrees: north along 106.70, then east along 10.78.
  const a = (lat: 10.77, lon: 106.70);
  const b = (lat: 10.78, lon: 106.70);
  const c = (lat: 10.78, lon: 106.71);

  group('heading smoothing', () {
    test('shortest arc crosses north instead of spinning 358 degrees', () {
      expect(shortestHeadingDelta(359, 1), closeTo(2, 1e-9));
      expect(shortestHeadingDelta(1, 359), closeTo(-2, 1e-9));
      expect(shortestHeadingDelta(0, 180), closeTo(180, 1e-9));
      expect(shortestHeadingDelta(10, 10), closeTo(0, 1e-9));
      // 350 -> 10 must pass through 360, never through 180.
      expect(lerpHeading(350, 10, .5), closeTo(0, 1e-9));
      expect(lerpHeading(10, 350, .5), closeTo(0, 1e-9));
      // Results stay normalized into [0, 360).
      for (final t in [0.0, .25, .5, .9, 1.0]) {
        final h = lerpHeading(359, 1, t);
        expect(h, greaterThanOrEqualTo(0));
        expect(h, lessThan(360));
      }
    });

    test('displayed heading eases toward each segment instead of snapping', () {
      final drive = NavigationProgress([a, b, c], 200);
      expect(drive.heading, closeTo(drive.segmentHeading, 1e-9));
      expect(drive.heading, closeTo(0, .5)); // straight north out of the origin

      // Sit just past the vertex, where the raw bearing jumps to "east".
      drive.progress = drive.cumulative[1] + 10;
      final target = drive.segmentHeading;
      expect(target, greaterThan(45));
      expect(drive.heading, closeTo(0, .5),
          reason: 'the rendered heading must not snap with the segment');

      drive.smoothHeading();
      expect(drive.heading, closeTo(lerpHeading(0, target, kHeadingSmoothing), 1e-9));
      final firstStep = drive.heading;
      expect(firstStep, lessThan(target),
          reason: 'one tick removes 25% of the error, not all of it');

      // Converges instead of oscillating or getting stuck.
      var previous = firstStep;
      for (var i = 0; i < 20; i++) {
        drive.smoothHeading();
        expect(drive.heading, greaterThanOrEqualTo(previous - 1e-9));
        previous = drive.heading;
      }
      expect(drive.heading, closeTo(target, .5));
    });

    test('advance() drives the smoothing so playback never whips the map', () {
      final drive = NavigationProgress([a, b, c], 20);
      final headings = <double>[];
      for (var i = 0; i < 40; i++) {
        drive.advance(1);
        headings.add(drive.heading);
      }
      // Every step is a shortest-arc ease, so no step may rotate more than the
      // 25% of the remaining error, and 0 -> ~90 degrees never overshoots.
      for (var i = 1; i < headings.length; i++) {
        final step = shortestHeadingDelta(headings[i - 1], headings[i]);
        expect(step.abs(), lessThan(45));
        expect(step, greaterThanOrEqualTo(-1e-9));
      }
      expect(headings.last, closeTo(drive.segmentHeading, .5));
    });

    test('resetHeading snaps deliberately for a brand new route', () {
      final drive = NavigationProgress([a, b, c], 200);
      drive.progress = drive.cumulative[1] + 10;
      expect((drive.heading - drive.segmentHeading).abs(), greaterThan(45));
      drive.resetHeading();
      expect(drive.heading, closeTo(drive.segmentHeading, 1e-9));
    });

    test('heading stays finite for degenerate geometry', () {
      final single = NavigationProgress([a], 0);
      expect(single.heading.isFinite, true);
      expect(single.segmentHeading, 0);
      final duplicate = NavigationProgress([a, a], 10)..advance(1);
      expect(duplicate.heading.isFinite, true);
      expect(duplicate.heading, greaterThanOrEqualTo(0));
      expect(duplicate.heading, lessThan(360));
      // The route-level bearing is still exposed for callers that need it.
      expect(math.max(duplicate.segmentHeading, 0), greaterThanOrEqualTo(0));
    });
  });
}
