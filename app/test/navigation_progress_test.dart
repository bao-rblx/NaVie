import 'package:flutter_test/flutter_test.dart';
import 'package:navie/features/driver/navigation_progress.dart';

void main() {
  const a = (lat: 10.77, lon: 106.70);
  const b = (lat: 10.78, lon: 106.70);
  const c = (lat: 10.78, lon: 106.71);
  test('simulation interpolates road geometry and clamps at arrival', () {
    final drive = NavigationProgress([a, b, c], 200);
    drive.advance(100);
    expect(drive.remainingFraction, closeTo(.5, .00001));
    drive.advance(500);
    expect(drive.position, c);
    expect(drive.remainingFraction, 0);
  });
  test('GPS projects onto long road segments without false deviations', () {
    final drive = NavigationProgress([a, b, c], 200);
    expect(drive.update((lat: 10.775, lon: 106.70)), false);
    expect(drive.progress, inInclusiveRange(550, 560));
    expect(drive.offRouteFixes, 0);
  });
  test('rerouting requires three accurate consecutive deviations', () {
    final drive = NavigationProgress([a, b, c], 200);
    const offRoute = (lat: 10.775, lon: 106.702);
    expect(drive.update(offRoute), false);
    expect(drive.update(offRoute), false);
    expect(drive.update(offRoute, accuracy: 100), false);
    expect(drive.offRouteFixes, 2);
    expect(drive.update(a), false);
    expect(drive.offRouteFixes, 0);
    drive.update(offRoute);
    drive.update(offRoute);
    expect(drive.update(offRoute), true);
  });
  test('single node and duplicate edges do not produce NaN', () {
    final single = NavigationProgress([a], 0)..advance(1);
    expect(single.position, a);
    expect(single.remainingFraction, 0);
    final duplicate = NavigationProgress([a, a, b], 100);
    expect(duplicate.position, a);
    duplicate.advance(50);
    expect(duplicate.position.lat.isFinite, true);
  });
}
