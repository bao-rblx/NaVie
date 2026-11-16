import 'dart:ui' show PictureRecorder;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navie/features/planner/route_map.dart';
import 'package:navie/l10n/app_localizations.dart';
import 'package:navie/features/driver/navigation_progress.dart';

const _route = [
  (lat: 10.770, lon: 106.700),
  (lat: 10.775, lon: 106.705),
  (lat: 10.780, lon: 106.710)
];

Widget host(Widget child) => MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Align(alignment: Alignment.topLeft, child: child));

void main() {
  testWidgets('mounting with a route fits the camera without throwing',
      (tester) async {
    await tester.pumpWidget(host(const SizedBox(
        width: 400, height: 400, child: RouteMap(route: _route, enabled: false))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('moving the position animates the camera instead of teleporting',
      (tester) async {
    final position = ValueNotifier<GeoPoint?>(null);
    await tester.pumpWidget(host(SizedBox(
        width: 400,
        height: 400,
        child: ValueListenableBuilder<GeoPoint?>(
            valueListenable: position,
            builder: (_, p, __) => RouteMap(
                route: _route,
                position: p,
                heading: p == null ? null : 90,
                enabled: false)))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    position.value = (lat: 10.775, lon: 106.705);
    await tester.pump();
    expect(tester.takeException(), isNull, reason: 'first frame of the move');
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.takeException(), isNull, reason: 'mid-animation');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'settled');
    addTearDown(position.dispose);
  });

  testWidgets('a tap on the heading-up map lands where the finger is',
      (tester) async {
    GeoPoint? tapped;
    await tester.pumpWidget(host(SizedBox(
        width: 400,
        height: 400,
        child: RouteMap(
            route: _route,
            heading: 90,
            enabled: false,
            onTap: (p) => tapped = p))));
    await tester.pumpAndSettle();
    // 100 px to the right of the map centre. With heading 90 the map is rotated
    // -90 degrees, so that screen point sits 100 px SOUTH in map space.
    await tester.tapAt(const Offset(300, 200));
    await tester.pumpAndSettle();
    expect(tapped, isNotNull);
    final centre = (lat: 10.775, lon: 106.705);
    expect(tapped!.lat, lessThan(centre.lat),
        reason: 'rotation must be undone before unprojecting the tap');
    expect(tapped!.lon, closeTo(centre.lon, .0005));
  });

  testWidgets('the camera eases toward a new position instead of teleporting',
      (tester) async {
    // Sample the geographic point under a fixed screen coordinate one frame
    // after the move starts and again once it has settled. If the camera
    // teleported, both samples would already be the final camera.
    final position = ValueNotifier<GeoPoint?>((lat: 10.770, lon: 106.700));
    GeoPoint? tapped;
    await tester.pumpWidget(host(SizedBox(
        width: 400,
        height: 400,
        child: ValueListenableBuilder<GeoPoint?>(
            valueListenable: position,
            builder: (_, p, __) => RouteMap(
                route: _route,
                position: p,
                enabled: false,
                onTap: (point) => tapped = point)))));
    await tester.pumpAndSettle();

    position.value = (lat: 10.780, lon: 106.710);
    await tester.pump(); // first frame of the move only
    await tester.tapAt(const Offset(200, 200));
    await tester.pump();
    final midFlight = tapped;

    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(200, 200));
    await tester.pump();
    final settled = tapped;

    expect(midFlight, isNotNull);
    expect(settled, isNotNull);
    expect(midFlight!.lat, isNot(closeTo(settled!.lat, 1e-6)),
        reason: 'the camera must still be travelling on the first frame');
    expect(settled.lat, closeTo(10.780, .001),
        reason: 'it must reach the new position once settled');
    addTearDown(position.dispose);
  });

  test('shouldRepaint compares fields instead of always returning true', () {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(10, 10);
    const pin = Offset(4, 4);
    final base = RouteMapPainter(path: path, origin: pin, position: pin);

    expect(base.shouldRepaint(RouteMapPainter(path: path, origin: pin, position: pin)),
        isFalse,
        reason: 'a paused map with identical inputs must not repaint');
    expect(base.shouldRepaint(RouteMapPainter(origin: pin, position: pin)), isTrue,
        reason: 'dropping the route is a real change');
    expect(base.shouldRepaint(RouteMapPainter(path: path, position: pin)), isTrue,
        reason: 'dropping the origin pin is a real change');
    expect(
        base.shouldRepaint(
            RouteMapPainter(path: path, origin: pin, position: const Offset(5, 5))),
        isTrue,
        reason: 'the moving position pin must repaint');
    expect(
        base.shouldRepaint(RouteMapPainter(
            path: Path()..lineTo(1, 1), origin: pin, position: pin)),
        isTrue,
        reason: 'a re-projected path must repaint');

    // The painter must also be safe to run with no route at all.
    final recorder = PictureRecorder();
    RouteMapPainter(origin: pin).paint(Canvas(recorder), const Size(100, 100));
    recorder.endRecording();
  });
}
