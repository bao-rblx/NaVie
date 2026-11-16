import 'dart:math' as math;

typedef GeoPoint = ({double lat, double lon});

/// Great-circle distance in meters, using API coordinates without speed guesses.
double distanceBetween(GeoPoint a, GeoPoint b) {
  const radians = math.pi / 180;
  final h = math.pow(math.sin((b.lat - a.lat) * radians / 2), 2) +
      math.cos(a.lat * radians) *
          math.cos(b.lat * radians) *
          math.pow(math.sin((b.lon - a.lon) * radians / 2), 2);
  return 12742000 * math.asin(math.sqrt(h.clamp(0, 1)));
}

/// Fraction of the remaining bearing error removed per tick (0..1).
const double kHeadingSmoothing = .25;

/// Signed shortest rotation from [from] to [to], in degrees within (-180, 180].
///
/// Without this, 359° -> 1° would ease the long way round and spin the
/// heading-up map almost a full turn at every north crossing.
double shortestHeadingDelta(double from, double to) {
  final delta = (to - from) % 360;
  return delta > 180 ? delta - 360 : delta;
}

/// Eases [from] toward [to] along the shortest arc; result is normalized to [0, 360).
double lerpHeading(double from, double to, double t) =>
    (from + shortestHeadingDelta(from, to) * t.clamp(0, 1) + 360) % 360;

/// Route projection and simulation shared by the driver view and its tests.
class NavigationProgress {
  NavigationProgress(this.geometry, this.durationSeconds) {
    for (var i = 1; i < geometry.length; i++) {
      cumulative
          .add(cumulative.last + distanceBetween(geometry[i - 1], geometry[i]));
    }
    _displayedHeading = segmentHeading;
  }
  final List<GeoPoint> geometry;
  final double durationSeconds;
  final List<double> cumulative = [0];
  double progress = 0;
  int offRouteFixes = 0;
  double _displayedHeading = 0;
  double get total => cumulative.last;
  double get remainingFraction =>
      total == 0 ? 0 : (1 - progress / total).clamp(0, 1);

  /// Bearing of the road segment currently under the vehicle, clockwise from
  /// true north. It jumps at every vertex, so render [heading] instead.
  double get segmentHeading {
    if (geometry.length < 2) return 0;
    var i = 1;
    while (i < cumulative.length - 1 && cumulative[i] < progress) {
      i++;
    }
    final a = geometry[i - 1], b = geometry[i];
    const rad = math.pi / 180;
    final y = math.sin((b.lon - a.lon) * rad) * math.cos(b.lat * rad);
    final x = math.cos(a.lat * rad) * math.sin(b.lat * rad) -
        math.sin(a.lat * rad) *
            math.cos(b.lat * rad) *
            math.cos((b.lon - a.lon) * rad);
    return (math.atan2(y, x) / rad + 360) % 360;
  }

  /// Bearing to display: [segmentHeading] eased along the shortest arc so turns
  /// are smooth and never rotate the long way round.
  double get heading => _displayedHeading;

  /// Steps [heading] [factor] of the way toward the current road segment.
  void smoothHeading({double factor = kHeadingSmoothing}) {
    _displayedHeading = lerpHeading(_displayedHeading, segmentHeading, factor);
  }

  /// Snaps [heading] to the road, for a new route rather than a new position.
  void resetHeading() => _displayedHeading = segmentHeading;

  GeoPoint get position {
    if (geometry.length < 2) return geometry.first;
    var i = 1;
    while (i < cumulative.length - 1 && cumulative[i] < progress) {
      i++;
    }
    final length = cumulative[i] - cumulative[i - 1];
    final t = length == 0 ? 0 : (progress - cumulative[i - 1]) / length;
    return (
      lat: geometry[i - 1].lat + (geometry[i].lat - geometry[i - 1].lat) * t,
      lon: geometry[i - 1].lon + (geometry[i].lon - geometry[i - 1].lon) * t
    );
  }

  void advance(double seconds) {
    final speed = durationSeconds > 0 ? total / durationSeconds : total;
    progress =
        (progress + seconds.clamp(0, double.infinity) * speed).clamp(0, total);
    smoothHeading();
  }

  /// Ignores inaccurate fixes; three consecutive >40 m deviations reroute.
  bool update(GeoPoint point, {double accuracy = 0}) {
    if (accuracy > 40) return false;
    var gap = double.infinity;
    var nearest = 0.0;
    final cos = math.cos(point.lat * math.pi / 180);
    const scale = 6371000 * math.pi / 180;
    for (var i = 1; i < geometry.length; i++) {
      final a = geometry[i - 1], b = geometry[i];
      final ax = (a.lon - point.lon) * scale * cos,
          ay = (a.lat - point.lat) * scale;
      final dx = (b.lon - a.lon) * scale * cos, dy = (b.lat - a.lat) * scale;
      final length = dx * dx + dy * dy;
      final t =
          length == 0 ? 0.0 : (-(ax * dx + ay * dy) / length).clamp(0.0, 1.0);
      final distance =
          math.sqrt(math.pow(ax + t * dx, 2) + math.pow(ay + t * dy, 2));
      if (distance < gap) {
        gap = distance;
        nearest = cumulative[i - 1] + t * (cumulative[i] - cumulative[i - 1]);
      }
    }
    if (geometry.length == 1) gap = distanceBetween(point, geometry.first);
    offRouteFixes = gap > 40 ? offRouteFixes + 1 : 0;
    if (gap <= 40) {
      progress = nearest;
      smoothHeading();
    }
    return offRouteFixes >= 3;
  }
}

/// Decode latitude-first API geometry.
List<GeoPoint> decodeGeometry(Map<String, dynamic> route) => (route['geometry']
        as List)
    .map((p) => (lat: (p[0] as num).toDouble(), lon: (p[1] as num).toDouble()))
    .toList();
