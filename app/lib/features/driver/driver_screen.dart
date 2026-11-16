import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import '../../l10n/app_localizations.dart';
import '../planner/route_map.dart';
import 'navigation_progress.dart';

/// Guided driving and clearly labeled route playback from an API route.
class DriverScreen extends StatefulWidget {
  const DriverScreen(
      {super.key,
      required this.route,
      required this.destination,
      required this.mode,
      required this.api,
      this.preview = false,
      this.showMap = true,
      this.elapsed});
  final Map<String, dynamic> route;
  final GeoPoint destination;
  final String mode;
  final Dio api;
  final bool preview, showMap;

  /// Test seam: time measured since the previous preview tick. Production
  /// leaves this null and uses a [Stopwatch]; tests inject a fixed delta.
  final Duration Function()? elapsed;

  @override
  State<DriverScreen> createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen> {
  static const _tickInterval = Duration(milliseconds: 250);

  late Map<String, dynamic> _route;
  late NavigationProgress _progress;
  final _tts = FlutterTts();
  final Map<int, Set<int>> _spoken = {};

  /// Distance travelled so far; bumped once per tick so only the banner, map
  /// and metrics rebuild instead of the whole screen four times a second.
  final ValueNotifier<double> _frame = ValueNotifier<double>(0);

  /// Playback is advanced by measured elapsed time, so a throttled timer or a
  /// throttled tab no longer makes the simulation run slower than its label.
  final Stopwatch _clock = Stopwatch();

  Timer? _timer;
  StreamSubscription<Position>? _gps;
  CancelToken? _request;
  GeoPoint? _position;
  double? _speed;
  bool _muted = false, _paused = false, _rerouting = false, _arrived = false;
  int _playback = 3;
  DateTime? _lastReroute;
  String? _status;
  String? _voiceLocale;

  @override
  void initState() {
    super.initState();
    _setRoute(widget.route);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _start();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // setLanguage is a platform round trip; do it once per locale, not before
    // every utterance.
    final locale = Localizations.localeOf(context).languageCode == 'vi'
        ? 'vi-VN'
        : 'en-US';
    if (_voiceLocale != locale) {
      _voiceLocale = locale;
      _prepareVoice(locale);
    }
  }

  Future<void> _prepareVoice(String locale) async {
    try {
      await _tts.setLanguage(locale);
      await _tts.setSpeechRate(.5);
      // Without this speak() returns immediately and prompts queue back to
      // back, so a 500 m prompt still plays when the turn is behind you.
      await _tts.awaitSpeakCompletion(true);
    } catch (_) {/* Device TTS is optional. */}
  }

  void _setRoute(Map<String, dynamic> route) {
    _route = route;
    _progress = NavigationProgress(
        decodeGeometry(route), (route['duration_s'] as num).toDouble());
    _position = _progress.position;
    _spoken.clear();
  }

  Future<void> _say(String text) async {
    if (_muted || !mounted) return;
    try {
      // Drop whatever is still playing: on the 10x replay the previous distance
      // would otherwise be heard long after it stopped being true.
      await _tts.stop();
      if (!mounted || _muted) return;
      await _tts.speak(text);
    } catch (_) {/* Device TTS is optional. */}
  }

  /// Time since the previous tick, measured rather than assumed.
  Duration _sinceLastTick() {
    final injected = widget.elapsed;
    if (injected != null) return injected();
    final elapsed = Duration(microseconds: _clock.elapsedMicroseconds);
    _clock.reset();
    return elapsed;
  }

  void _onTick() {
    if (_paused || !mounted) return;
    final seconds = _sinceLastTick().inMicroseconds / Duration.microsecondsPerSecond;
    if (seconds <= 0) return;
    _progress.advance(seconds * _playback); // also eases the displayed heading
    _position = _progress.position;
    _frame.value = _progress.progress;
    _announce();
    if (_progress.remainingFraction == 0) _arrival();
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    if (_paused) {
      // Drop the paused interval so resuming does not jump forward.
      _clock.stop();
      _clock.reset();
      _tts.stop();
    } else {
      _clock
        ..reset()
        ..start();
    }
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    if (_muted) _tts.stop();
  }

  Future<void> _start() async {
    if (widget.preview) {
      _clock.start();
      _timer = Timer.periodic(_tickInterval, (_) => _onTick());
      return;
    }
    setState(() => _status = AppLocalizations.of(context)!.waitingGps);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (!mounted) return;
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(
            () => _status = AppLocalizations.of(context)!.navigationPermission);
        return;
      }
      _gps = Geolocator.getPositionStream(
              locationSettings: const LocationSettings(
                  accuracy: LocationAccuracy.bestForNavigation,
                  distanceFilter: 3))
          .listen((fix) {
        if (!mounted) return;
        final point = (lat: fix.latitude, lon: fix.longitude);
        final reroute = _progress.update(point, accuracy: fix.accuracy);
        setState(() {
          _position = point;
          _speed = fix.speed >= 0 ? fix.speed : null;
          _status =
              fix.accuracy > 40 ? AppLocalizations.of(context)!.gpsWeak : null;
        });
        _frame.value = _progress.progress;
        if (reroute) _reroute(point);
        _announce();
        if (fix.accuracy <= 40 &&
            _progress.total - _progress.progress < 20 &&
            distanceBetween(point, _progress.geometry.last) < 25) {
          _arrival();
        }
      }, onError: (Object error) {
        if (mounted) {
          setState(
              () => _status = AppLocalizations.of(context)!.locationDenied);
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => _status = AppLocalizations.of(context)!.locationDenied);
      }
    }
  }

  Map<String, dynamic>? get _next {
    for (final m
        in (_route['maneuvers'] as List? ?? []).cast<Map<String, dynamic>>()) {
      final i = m['at_index'] as int;
      if (i < _progress.cumulative.length &&
          _progress.cumulative[i] > _progress.progress + 8) {
        return m;
      }
    }
    return null;
  }

  void _announce() {
    final next = _next;
    if (next == null || _muted) return;
    final index = next['at_index'] as int,
        meters = _progress.cumulative[index] - _progress.progress;
    final seen = _spoken.putIfAbsent(index, () => {});
    for (final threshold in widget.mode == 'walk' ? [50] : [50, 200, 500]) {
      if (meters <= threshold && !seen.contains(threshold)) {
        seen.addAll([50, 200, 500].where((v) => v >= threshold));
        final locale = Localizations.localeOf(context).languageCode;
        _say(
            '${meters.round()} ${AppLocalizations.of(context)!.metersWord}. ${next['text_$locale']}');
        break;
      }
    }
  }

  Future<void> _reroute(GeoPoint position) async {
    if (_rerouting ||
        (_lastReroute != null &&
            DateTime.now().difference(_lastReroute!).inSeconds < 10)) {
      return;
    }
    setState(() => _rerouting = true);
    _lastReroute = DateTime.now();
    _request = CancelToken();
    try {
      final response = await widget.api.post<Map<String, dynamic>>('/v1/route',
          data: {
            'origin': [position.lat, position.lon],
            'destination': [widget.destination.lat, widget.destination.lon],
            'mode': widget.mode,
            'algorithm': 'astar'
          },
          cancelToken: _request);
      if (!mounted) return;
      setState(() {
        _setRoute(response.data!);
        _position = position;
        _status = AppLocalizations.of(context)!.routeUpdated;
      });
      _frame.value = _progress.progress;
    } catch (_) {
      if (mounted) {
        setState(() => _status = AppLocalizations.of(context)!.rerouteFailed);
      }
    } finally {
      if (mounted) setState(() => _rerouting = false);
    }
  }

  Future<void> _arrival() async {
    if (_arrived) return;
    _arrived = true;
    _timer?.cancel();
    _clock.stop();
    await _gps?.cancel();
    if (!mounted) return;
    final l = AppLocalizations.of(context)!;
    _say(l.youArrived);
    await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
                icon: const Icon(Icons.check_circle_outline, size: 56),
                title: Text(l.youArrived),
                actions: [
                  FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l.done))
                ]));
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _clock.stop();
    _gps?.cancel();
    _request?.cancel();
    _frame.dispose();
    _tts.stop();
    super.dispose();
  }

  String _distance(double value) => value < 1000
      ? '${(value / 10).round() * 10} m'
      : '${(value / 1000).toStringAsFixed(1)} km';

  Widget _banner(AppLocalizations l) {
    final next = _next;
    final locale = Localizations.localeOf(context).languageCode;
    final toTurn = next == null
        ? _progress.total - _progress.progress
        : _progress.cumulative[next['at_index'] as int] - _progress.progress;
    return Container(
        padding: const EdgeInsets.all(20),
        color: const Color(0xff087f5b),
        child: Row(children: [
          Icon(
              (next?['type'] as String? ?? '').contains('left')
                  ? Icons.turn_left
                  : (next?['type'] as String? ?? '').contains('right')
                      ? Icons.turn_right
                      : Icons.straight,
              color: Colors.white,
              size: 45),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(_distance(toTurn),
                    style: const TextStyle(
                        fontSize: 29,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                Text(
                    next?['text_$locale'] as String? ?? l.continueToDestination,
                    style: const TextStyle(fontSize: 17, color: Colors.white)),
                const SizedBox(height: 5),
                Text(
                    _rerouting
                        ? l.rerouting
                        : _status ?? (widget.preview ? l.simulation : l.gpsActive),
                    style: const TextStyle(fontSize: 11, color: Colors.white))
              ])),
          IconButton(
              tooltip: l.voiceGuidance,
              onPressed: _toggleMute,
              icon: Icon(_muted ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white)),
        ]));
  }

  Widget _metrics(AppLocalizations l) {
    final remaining =
        (_route['duration_s'] as num) * _progress.remainingFraction;
    final eta = DateTime.now()
        .toUtc()
        .add(Duration(hours: 7, seconds: remaining.round()));
    return Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
      _metric('${(remaining / 60).ceil()} ${l.minutesShort}', l.remaining),
      _metric(
          _distance(
              (_route['distance_m'] as num) * _progress.remainingFraction),
          l.distance),
      _metric(
          '${eta.hour.toString().padLeft(2, '0')}:${eta.minute.toString().padLeft(2, '0')}',
          l.arrivalTime)
    ]);
  }

  Widget _speedLine(AppLocalizations l) => Text(
      '${_speed == null ? l.speedUnknown : l.speedValue((_speed! * 3.6).round())} ${l.metaSeparator} ${l.speedLimitUnknown}');

  Widget _playbackControls(AppLocalizations l) => Row(children: [
        Text(l.simulation,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        const Spacer(),
        IconButton(
            tooltip: l.pauseResume,
            onPressed: _togglePause,
            icon: Icon(_paused ? Icons.play_arrow : Icons.pause)),
        DropdownButton<int>(
            value: _playback,
            items: [1, 3, 5, 10]
                .map((v) => DropdownMenuItem(
                    value: v, child: Text(l.playbackMultiplier(v))))
                .toList(),
            onChanged: (v) => setState(() => _playback = v!))
      ]);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
        body: SafeArea(
            child: Column(children: [
      // Only these three subtrees follow the simulation clock; the rest of the
      // screen rebuilds on real state changes (pause, mute, reroute) only.
      ValueListenableBuilder<double>(
          valueListenable: _frame,
          builder: (context, _, __) => _banner(l)),
      Expanded(
          child: ValueListenableBuilder<double>(
              valueListenable: _frame,
              builder: (context, _, __) => RouteMap(
                  heading: _progress.heading,
                  route: _progress.geometry,
                  position: _position,
                  enabled: widget.showMap))),
      Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            ValueListenableBuilder<double>(
                valueListenable: _frame,
                builder: (context, _, __) => _metrics(l)),
            const SizedBox(height: 14),
            if (widget.preview)
              _playbackControls(l)
            else
              _speedLine(l),
            const SizedBox(height: 8),
            SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: Text(l.endNavigation))),
          ])),
    ])));
  }

  Widget _metric(String value, String label) => Flexible(
          child: Column(children: [
        Text(value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        Text(label, style: Theme.of(context).textTheme.labelSmall)
      ]));
}