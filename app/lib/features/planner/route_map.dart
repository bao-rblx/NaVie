import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../driver/navigation_progress.dart';

const double _tileSize = 256;
const double _zoomMin = 10, _zoomMax = 19, _followZoom = 17;
const Duration _cameraDuration = Duration(milliseconds: 300);

/// Normalized Web-Mercator coordinates in 0..1, independent of zoom, so a point
/// is projected once instead of repeating log/tan maths on every frame.
Offset _mercator(GeoPoint p) {
  final lat = p.lat.clamp(-85.0, 85.0) * math.pi / 180;
  return Offset(
      (p.lon + 180) / 360,
      (1 - math.log(math.tan(lat) + 1 / math.cos(lat)) / math.pi) / 2);
}

GeoPoint _fromMercator(Offset unit) {
  final m = math.pi * (1 - 2 * unit.dy);
  return (
    lat: math.atan((math.exp(m) - math.exp(-m)) / 2) * 180 / math.pi,
    lon: unit.dx * 360 - 180
  );
}

/// Pixel side of the whole world at a fractional [zoom].
double _worldSide(double zoom) => _tileSize * math.pow(2, zoom);

/// Interactive, correctly proportioned OSM map without an API key.
class RouteMap extends StatefulWidget {
  const RouteMap(
      {super.key,
      this.route = const [],
      this.origin,
      this.destination,
      this.position,
      this.heading,
      this.onTap,
      this.enabled = true});
  final List<GeoPoint> route;
  final GeoPoint? origin, destination, position;

  /// Smoothed heading; the map eases toward it and never spins the long way.
  final double? heading;
  final ValueChanged<GeoPoint>? onTap;
  final bool enabled;
  @override
  State<RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<RouteMap>
    with SingleTickerProviderStateMixin {
  static const GeoPoint _home = (lat: 10.7769, lon: 106.7009);

  /// Camera and bearing share one controller so a retarget restarts both from
  /// their current on-screen values instead of teleporting.
  late final AnimationController _camera = AnimationController(
      vsync: this, duration: _cameraDuration, value: 1);

  GeoPoint _center = _home, _fromCenter = _home, _toCenter = _home;
  double _zoom = 14, _fromZoom = 14, _toZoom = 14;
  double _turns = 0, _fromTurns = 0, _toTurns = 0;
  bool _reduceMotion = false;

  Offset? _lastFocal;
  double _lastScale = 1;
  Size _size = Size.zero;
  bool _following = true;
  bool _needsFit = false;

  /// Projection cache. The polyline used to be re-projected from scratch on
  /// every build; now only a route, zoom, camera or size change invalidates it.
  List<GeoPoint> _unitSource = const [];
  List<Offset> _unit = const [];
  Path? _routePath;
  double _projectedZoom = double.nan;
  Offset? _projectedTopLeft;

  @override
  void initState() {
    super.initState();
    if (widget.position != null) {
      _center = _fromCenter = _toCenter = widget.position!;
      _zoom = _fromZoom = _toZoom = _followZoom;
    } else {
      _needsFit = widget.route.isNotEmpty;
    }
    _turns = _fromTurns = _toTurns = _targetTurns;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  @override
  void didUpdateWidget(covariant RouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final follow = widget.position != null && _following;
    final rerouted = !listEquals(widget.route, oldWidget.route);
    if (follow) {
      _moveTo(center: widget.position!, zoom: _followZoom);
    } else if (rerouted &&
        widget.route.isNotEmpty &&
        widget.position == null) {
      _fit(animate: true);
    } else if (widget.destination != oldWidget.destination &&
        widget.destination != null) {
      _moveTo(center: widget.destination!);
    } else if (widget.heading != oldWidget.heading) {
      _moveTo();
    }
  }

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  /// Heading in turns, clockwise, for the rotation of the heading-up map.
  double get _targetTurns =>
      _following ? -(widget.heading ?? 0) / 360 : 0;

  /// Eases the camera and the bearing to new targets from wherever they are now.
  void _moveTo({GeoPoint? center, double? zoom}) {
    final targetCenter = center ?? _toCenter;
    final targetZoom = (zoom ?? _toZoom).clamp(_zoomMin, _zoomMax);
    _fromCenter = _center;
    _fromZoom = _zoom;
    _fromTurns = _turns;
    _toCenter = targetCenter;
    _toZoom = targetZoom;
    // Unwrap into (-.5, .5] turns so 359 deg -> 1 deg rotates one degree, not 358.
    var delta = (_targetTurns - _turns) % 1;
    if (delta > .5) delta -= 1;
    _toTurns = _turns + delta;
    // Ignore sub-pixel retargets: GPS jitter would otherwise restart the
    // animation on every fix and keep the map permanently in motion.
    final side = _worldSide(targetZoom);
    final drift = (_mercator(targetCenter) - _mercator(_center)) * side;
    if (drift.distance < .5 &&
        (_fromZoom - _toZoom).abs() < .01 &&
        (_fromTurns - _toTurns).abs() < .002) {
      return;
    }
    _camera
      ..stop()
      ..duration = _reduceMotion ? Duration.zero : _cameraDuration
      ..forward(from: 0);
  }

  /// Jumps the camera without animating: gesture pan/zoom must stay 1:1.
  void _jumpTo(GeoPoint center, double zoom) {
    _camera.stop();
    _center = _fromCenter = _toCenter = center;
    _zoom = _fromZoom = _toZoom = zoom.clamp(_zoomMin, _zoomMax);
    _turns = _fromTurns = _toTurns = _targetTurns;
    _camera.value = 1;
  }

  ({GeoPoint center, double zoom})? _fitTarget() {
    if (widget.route.isEmpty || _size.isEmpty) return null;
    final lat = widget.route.map((p) => p.lat),
        lon = widget.route.map((p) => p.lon);
    final low = (lat: lat.reduce(math.min), lon: lon.reduce(math.min)),
        high = (lat: lat.reduce(math.max), lon: lon.reduce(math.max));
    final span = _mercator(high) - _mercator(low);
    final width = math.max(_size.width - 80, 1.0),
        height = math.max(_size.height - 160, 1.0);
    final scaleX = span.dx == 0 ? double.infinity : width / span.dx,
        scaleY = span.dy == 0 ? double.infinity : height / span.dy;
    final side = math.min(scaleX, scaleY);
    // Fractional zoom keeps the fit smooth; integer steps used to jump a level.
    final zoom = side.isFinite && side > 0
        ? math.log(side / _tileSize) / math.ln2
        : _zoomMax;
    return (
      center: (lat: (low.lat + high.lat) / 2, lon: (low.lon + high.lon) / 2),
      zoom: zoom.clamp(_zoomMin, _zoomMax)
    );
  }

  void _fit({bool animate = false}) {
    final target = _fitTarget();
    if (target == null) {
      // Nothing has been laid out yet; fit as soon as a size is known.
      _needsFit = widget.route.isNotEmpty;
      return;
    }
    if (animate) {
      _moveTo(center: target.center, zoom: target.zoom);
    } else {
      _jumpTo(target.center, target.zoom);
    }
  }

  /// Rebuilds the projected polyline and its [Path] only when one of its inputs
  /// changed; called from build, so it must stay cheap on a cache hit.
  ///
  /// Callers often hand over a freshly decoded list for the same road geometry,
  /// so identity alone is not enough: fall back to value comparison before
  /// throwing away a projection that is still valid.
  void _project(Offset topLeft) {
    if (!identical(widget.route, _unitSource)) {
      final sameGeometry = listEquals(widget.route, _unitSource);
      _unitSource = widget.route;
      if (!sameGeometry) {
        _unit = [for (final p in widget.route) _mercator(p)];
        _projectedTopLeft = null;
      }
    }
    if (_projectedTopLeft == topLeft && _projectedZoom == _zoom) return;
    final side = _worldSide(_zoom);
    final points = [for (final u in _unit) u * side - topLeft];
    final path = Path();
    if (points.length > 1) {
      path.moveTo(points.first.dx, points.first.dy);
      for (final p in points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
    }
    _routePath = points.length > 1 ? path : null;
    _projectedTopLeft = topLeft;
    _projectedZoom = _zoom;
  }

  GeoPoint _atWorld(Offset world) => _fromMercator(world / _worldSide(_zoom));

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        if (c.biggest != _size) {
          _size = c.biggest;
          if (_needsFit) {
            _needsFit = false;
            _fit();
          }
        }
        return AnimatedBuilder(
            animation: _camera, builder: (context, _) => _map(context));
      });

  Widget _map(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    // Derived view of the easing camera; everything below reads these fields.
    final t = Curves.easeInOutCubic.transform(_camera.value);
    _center = t == 1
        ? _toCenter
        : _fromMercator(Offset.lerp(_mercator(_fromCenter),
            _mercator(_toCenter), t)!);
    _zoom = _fromZoom + (_toZoom - _fromZoom) * t;
    _turns = _fromTurns + (_toTurns - _fromTurns) * t;

    final side = _worldSide(_zoom);
    final topLeft =
        _mercator(_center) * side - Offset(_size.width / 2, _size.height / 2);
    Offset screen(GeoPoint p) => _mercator(p) * side - topLeft;
    _project(topLeft);

    final angle = _turns * 2 * math.pi;
    final margin = angle == 0
        ? 0.0
        : math.sqrt(_size.width * _size.width + _size.height * _size.height) /
            2;
    return Stack(children: [
      Positioned.fill(
          child: GestureDetector(
        onTapUp: widget.onTap == null
            ? null
            : (details) =>
                widget.onTap!(_atWorld(topLeft + _unrotate(details.localPosition))),
        onScaleStart: (details) {
          _lastFocal = details.localFocalPoint;
          _lastScale = 1;
          _following = false;
        },
        onScaleUpdate: (details) => setState(() {
          final delta =
              details.localFocalPoint - (_lastFocal ?? details.localFocalPoint);
          // Screen -> map space: undo the heading rotation so dragging a
          // heading-up map still moves the map the way the finger goes.
          final center = _mercator(_center) * side -
              Offset(delta.dx * math.cos(angle) + delta.dy * math.sin(angle),
                  -delta.dx * math.sin(angle) + delta.dy * math.cos(angle));
          var zoom = _zoom;
          if (details.scale / _lastScale > 1.5 ||
              details.scale / _lastScale < .66) {
            zoom = (_zoom + (details.scale > _lastScale ? 1 : -1)).clamp(10, 19);
            _lastScale = details.scale;
          }
          _jumpTo(_fromMercator(center / side), zoom);
          _lastFocal = details.localFocalPoint;
        }),
        child: ClipRect(
            child: Stack(children: [
          const Positioned.fill(child: ColoredBox(color: Color(0xffe5ede5))),
          Positioned.fill(
              child: Transform.rotate(
                  angle: angle,
                  child: Stack(clipBehavior: Clip.none, children: [
                    if (widget.enabled) _tiles(topLeft, margin),
                    Positioned.fill(
                        child: IgnorePointer(
                            child: RepaintBoundary(
                                child: CustomPaint(
                                    painter: RouteMapPainter(
                                        path: _routePath,
                                        origin: widget.origin == null
                                            ? null
                                            : screen(widget.origin!),
                                        destination: widget.destination == null
                                            ? null
                                            : screen(widget.destination!),
                                        position: widget.position == null
                                            ? null
                                            : screen(widget.position!)))))),
                  ]))),
        ])),
      )),
      Positioned(
          right: 12,
          top: 12,
          child: Column(children: [
            _control(
                Icons.add,
                l.zoomIn,
                () => _moveTo(
                    zoom: (_toZoom + 1).clamp(_zoomMin, _zoomMax))),
            _control(
                Icons.remove,
                l.zoomOut,
                () => _moveTo(
                    zoom: (_toZoom - 1).clamp(_zoomMin, _zoomMax))),
            _control(
                Icons.my_location,
                l.recenter,
                () => setState(() {
                      _following = true;
                      if (widget.position != null) {
                        _moveTo(center: widget.position!, zoom: _followZoom);
                      } else {
                        _fit(animate: true);
                      }
                    })),
          ])),
      Positioned(
          right: 4,
          bottom: 4,
          child: ColoredBox(
              color: Colors.white.withValues(alpha: .95),
              child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Text(l.osmAttribution,
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xff344b3d)))))),
    ]);
  }

  /// Undoes the heading rotation so a tap on the rotated map lands on the place
  /// that is actually under the finger.
  Offset _unrotate(Offset p) {
    final angle = _turns * 2 * math.pi, c = Offset(_size.width / 2, _size.height / 2);
    if (angle == 0) return p;
    final d = p - c;
    return c +
        Offset(d.dx * math.cos(-angle) - d.dy * math.sin(-angle),
            d.dx * math.sin(-angle) + d.dy * math.cos(-angle));
  }

  /// Tiles are laid out in map space and rotated with the route; each one is
  /// keyed by URL and isolated so re-compositing never re-decodes the grid.
  Widget _tiles(Offset topLeft, double margin) {
    if (_size.isEmpty) return const SizedBox();
    // Tiles are always fetched at an integer zoom and scaled to the fractional
    // display zoom, so zooming stays continuous instead of stepping.
    final tileZoom = _zoom.round().clamp(10, 19);
    final tileSide = _tileSize * math.pow(2, _zoom - tileZoom).toDouble();
    final count = 1 << tileZoom;
    final x0 = ((topLeft.dx - margin) / tileSide).floor(),
        x1 = ((topLeft.dx + _size.width + margin) / tileSide).ceil(),
        y0 = ((topLeft.dy - margin) / tileSide).floor(),
        y1 = ((topLeft.dy + _size.height + margin) / tileSide).ceil();
    return RepaintBoundary(
        child: Stack(clipBehavior: Clip.none, children: [
      for (var y = y0; y < y1; y++)
        for (var x = x0; x < x1; x++)
          if (x >= 0 && y >= 0 && x < count && y < count)
            Positioned(
                key: ValueKey('$tileZoom/$x/$y'),
                left: x * tileSide - topLeft.dx,
                top: y * tileSide - topLeft.dy,
                width: tileSide,
                height: tileSide,
                child: Image.network(
                    'https://tile.openstreetmap.org/$tileZoom/$x/$y.png',
                    fit: BoxFit.cover,
                    // Keeps the previous frame visible while a tile decodes, so
                    // the grid no longer blanks out on every zoom change.
                    gaplessPlayback: true,
                    filterQuality: FilterQuality.low,
                    excludeFromSemantics: true,
                    errorBuilder: (_, __, ___) => const SizedBox()))
    ]));
  }

  Widget _control(IconData icon, String label, VoidCallback action) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
          color: Theme.of(context).colorScheme.surface,
          elevation: 2,
          borderRadius: BorderRadius.circular(14),
          child:
              IconButton(tooltip: label, onPressed: action, icon: Icon(icon))));
}

/// Strokes and pins are allocated once: [CustomPainter.paint] runs many times a
/// second and used to build a fresh [Path] and two [Paint]s on every frame.
abstract final class _MapStyle {
  static final Paint casing = Paint()
    ..color = Colors.white
    ..strokeWidth = 9
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;
  static final Paint line = Paint()
    ..color = const Color(0xff087f5b)
    ..strokeWidth = 5
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;
  static final Paint pinHalo = Paint()..color = Colors.white;
  static final Paint pinOrigin = Paint()..color = const Color(0xff087f5b);
  static final Paint pinDestination = Paint()..color = const Color(0xff19382e);
  static final Paint pinPosition = Paint()..color = const Color(0xff1769e0);
}

/// Draws the route and the pins.
///
/// Exposed (rather than private) so the repaint contract can be asserted by a
/// test: allocating a [Path] per paint is invisible, but repainting a static
/// map sixty times a second is not.
class RouteMapPainter extends CustomPainter {
  RouteMapPainter({this.path, this.origin, this.destination, this.position});
  final Path? path;
  final Offset? origin, destination, position;
  @override
  void paint(Canvas canvas, Size size) {
    final route = path;
    if (route != null) {
      canvas.drawPath(route, _MapStyle.casing);
      canvas.drawPath(route, _MapStyle.line);
    }
    for (final (p, pin) in [
      (origin, _MapStyle.pinOrigin),
      (destination, _MapStyle.pinDestination),
      (position, _MapStyle.pinPosition)
    ]) {
      if (p != null) {
        canvas.drawCircle(p, 11, _MapStyle.pinHalo);
        canvas.drawCircle(p, 7, pin);
      }
    }
  }

  @override
  bool shouldRepaint(covariant RouteMapPainter oldDelegate) =>
      oldDelegate.path != path ||
      oldDelegate.origin != origin ||
      oldDelegate.destination != destination ||
      oldDelegate.position != position;
}