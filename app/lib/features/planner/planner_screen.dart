import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/app_localizations.dart';
import '../driver/driver_screen.dart';
import '../driver/navigation_progress.dart';
import 'route_map.dart';

const _modeIcons = {
  'all': Icons.compare_arrows,
  'motorbike': Icons.two_wheeler,
  'car': Icons.directions_car,
  'walk': Icons.directions_walk,
  'taxi': Icons.local_taxi
};

/// Responsive trip planning, mode comparison and navigation entry point.
class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key, this.showMap = true, this.api});
  final bool showMap;
  final Dio? api;
  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  late final Dio _api = widget.api ??
      Dio(BaseOptions(
          baseUrl: const String.fromEnvironment('NAVIE_API_URL',
              defaultValue: 'http://127.0.0.1:8000'),
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 45)));
  final _inputs = [TextEditingController(), TextEditingController()];
  final List<Map<String, dynamic>?> _places = [null, null];
  List<Map<String, dynamic>> _options = [], _suggestions = [];
  Map<String, dynamic>? _selected;
  String _mode = 'motorbike', _sort = 'fastest';
  int _picking = 0, _revision = 0, _searchSerial = 0;
  bool _loading = false;
  String? _error;
  Timer? _searchTimer;
  CancelToken? _routeRequest, _searchRequest;
  AppLocalizations get l => AppLocalizations.of(context)!;

  void _invalidate() {
    _revision++;
    _routeRequest?.cancel();
    _loading = false;
    _options = [];
    _selected = null;
    _error = null;
  }

  void _select(int index, Map<String, dynamic> place) {
    _searchSerial++;
    _searchTimer?.cancel();
    _searchRequest?.cancel();
    setState(() {
      _invalidate();
      _places[index] = place;
      _inputs[index].text = place['name'] as String;
      _suggestions = [];
      _picking = 1;
    });
  }

  void _search(int index, String query) {
    _searchTimer?.cancel();
    _searchRequest?.cancel();
    final serial = ++_searchSerial;
    setState(() {
      _invalidate();
      _places[index] = null;
      _picking = index;
      _suggestions = [];
    });
    if (query.trim().length < 2) return;
    _searchTimer = Timer(const Duration(milliseconds: 300), () async {
      final token = CancelToken();
      _searchRequest = token;
      try {
        final response = await _api.get<List<dynamic>>('/v1/geocode',
            queryParameters: {'q': query, 'near': '10.7769,106.7009'},
            cancelToken: token);
        if (mounted && serial == _searchSerial) {
          setState(
              () => _suggestions = response.data!.cast<Map<String, dynamic>>());
        }
      } on DioException catch (error) {
        if (mounted &&
            serial == _searchSerial &&
            !CancelToken.isCancel(error)) {
          setState(() => _error = l.serverUnavailable);
        }
      }
    });
  }

  Future<void> _find() async {
    if (_places.any((p) => p == null)) return;
    final revision = _revision;
    _routeRequest = CancelToken();
    setState(() {
      _loading = true;
      _error = null;
      _suggestions = [];
    });
    try {
      final response = await _api.post<Map<String, dynamic>>('/v1/plan',
          data: {
            'origin': {
              'text': _places[0]!['name'],
              'latlon': _places[0]!['latlon']
            },
            'destination': {
              'text': _places[1]!['name'],
              'latlon': _places[1]!['latlon']
            },
            'modes_allowed': _mode == 'all' ? [] : [_mode],
            'optimize': _sort
          },
          cancelToken: _routeRequest);
      if (!mounted || revision != _revision) return;
      setState(() {
        _options =
            (response.data!['options'] as List).cast<Map<String, dynamic>>();
        _sortOptions();
        _selected = _options.isEmpty ? null : _options.first;
        if (_options.isEmpty) _error = l.errorNoPath;
      });
    } on DioException catch (error) {
      if (!mounted || revision != _revision || CancelToken.isCancel(error)) {
        return;
      }
      final body = error.response?.data,
          locale = Localizations.localeOf(context).languageCode;
      setState(() => _error = body is Map && body['error'] is Map
          ? body['error']['message_$locale']?.toString() ?? l.serverUnavailable
          : l.serverUnavailable);
    } finally {
      if (mounted && revision == _revision) setState(() => _loading = false);
    }
  }

  void _sortOptions() {
    _options.sort((a, b) {
      if (_sort == 'cheapest') {
        final au = (a['legs'] as List).any((leg) => leg['estimate'] == true),
            bu = (b['legs'] as List).any((leg) => leg['estimate'] == true);
        if (au != bu) return au ? 1 : -1;
        if (!au) {
          final price = (a['cost_vnd'] as num).compareTo(b['cost_vnd'] as num);
          if (price != 0) return price;
        }
      }
      return (a['duration_s'] as num).compareTo(b['duration_s'] as num);
    });
  }

  Future<void> _locate() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('Location denied');
      }
      final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 15)));
      if (mounted) {
        _select(0, {
          'name': l.myLocation,
          'latlon': [position.latitude, position.longitude]
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = l.locationDenied);
    }
  }

  GeoPoint? _point(int index) {
    final p = _places[index]?['latlon'] as List?;
    return p == null
        ? null
        : (lat: (p[0] as num).toDouble(), lon: (p[1] as num).toDouble());
  }

  Map<String, dynamic>? get _route => _selected == null
      ? null
      : (_selected!['legs'] as List).first as Map<String, dynamic>;

  Map<String, dynamic>? _geometrySource;
  List<GeoPoint> _geometry = const [];

  /// Decoded geometry, memoised on the leg identity. Decoding used to run on
  /// every rebuild and produced a new list each time, which defeated the map's
  /// projection cache.
  List<GeoPoint> get _geometryFor {
    final route = _route;
    if (route == null) return const [];
    if (!identical(route, _geometrySource)) {
      _geometrySource = route;
      _geometry = decodeGeometry(route);
    }
    return _geometry;
  }
  String _modeName(String mode) => switch (mode) {
        'walk' => l.modeWalk,
        'car' => l.modeCar,
        'taxi' => l.modeTaxi,
        'all' => l.compareAll,
        _ => l.modeMotorbike
      };
  void _drive(bool preview) {
    if (_route == null || _point(1) == null) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => DriverScreen(
            route: _route!,
            destination: _point(1)!,
            mode: (_selected!['modes'] as List).first as String,
            api: _api,
            preview: preview,
            showMap: widget.showMap)));
  }

  @override
  void dispose() {
    _searchSerial++;
    _searchTimer?.cancel();
    _routeRequest?.cancel();
    _searchRequest?.cancel();
    for (final input in _inputs) {
      input.dispose();
    }
    if (widget.api == null) _api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
        body: SafeArea(child: LayoutBuilder(builder: (context, size) {
      final wide = size.maxWidth >= 800;
      final map = RouteMap(
          enabled: widget.showMap,
          route: _geometryFor,
          origin: _point(0),
          destination: _point(1),
          onTap: (point) => _select(_picking, {
                'name': l.mapPin,
                'latlon': [point.lat, point.lon]
              }));
      final panel = Material(
          color: colors.surface,
          child: ListView(padding: const EdgeInsets.all(24), children: [
            Row(children: [
              Text(l.appTitle,
                  style: TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      color: colors.primary)),
              const Spacer(),
              IconButton(
                  tooltip: l.settings,
                  onPressed: () => context.push('/settings'),
                  icon: const Icon(Icons.settings_outlined)),
              IconButton(
                  tooltip: l.resetTrip,
                  onPressed: () {
                    setState(() {
                      _invalidate();
                      _searchSerial++;
                      _searchTimer?.cancel();
                      _searchRequest?.cancel();
                      _places.fillRange(0, 2, null);
                      for (final input in _inputs) {
                        input.clear();
                      }
                      _suggestions = [];
                      _picking = 0;
                    });
                  },
                  icon: const Icon(Icons.refresh))
            ]),
            const SizedBox(height: 24),
            Text(l.whereTo,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(l.journeySubtitle,
                style: TextStyle(color: colors.onSurfaceVariant)),
            const SizedBox(height: 24),
            Container(
                decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(18)),
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  for (var i = 0; i < 2; i++)
                    TextField(
                        controller: _inputs[i],
                        onChanged: (q) => _search(i, q),
                        onTap: () => setState(() => _picking = i),
                        decoration: InputDecoration(
                            labelText:
                                i == 0 ? l.searchOrigin : l.searchDestination,
                            hintText: i == 0
                                ? l.originPlaceholder
                                : l.destinationPlaceholder,
                            prefixIcon: Icon(i == 0
                                ? Icons.trip_origin
                                : Icons.location_on_outlined),
                            suffixIcon: IconButton(
                                tooltip: i == 0
                                    ? l.chooseOrigin
                                    : l.chooseDestination,
                                onPressed: () => setState(() => _picking = i),
                                icon: const Icon(Icons.map_outlined)),
                            border: InputBorder.none)),
                ])),
            if (_suggestions.isNotEmpty)
              Card(
                  child: Column(
                      children: _suggestions
                          .take(5)
                          .map((p) => ListTile(
                              leading: const Icon(Icons.place_outlined),
                              title: Text(p['name'] as String),
                              subtitle: Text(p['address'] as String? ?? l.place,
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              onTap: () => _select(_picking, p)))
                          .toList())),
            Row(children: [
              TextButton.icon(
                  onPressed: _locate,
                  icon: const Icon(Icons.my_location, size: 18),
                  label: Text(l.useMyLocation)),
              const Spacer(),
              IconButton(
                  tooltip: l.swapPlaces,
                  onPressed: () => setState(() {
                        _invalidate();
                        _searchSerial++;
                        _searchTimer?.cancel();
                        _searchRequest?.cancel();
                        _suggestions = [];
                        final place = _places[0];
                        _places[0] = _places[1];
                        _places[1] = place;
                        for (var i = 0; i < 2; i++) {
                          _inputs[i].text =
                              _places[i]?['name'] as String? ?? '';
                        }
                      }),
                  icon: const Icon(Icons.swap_vert))
            ]),
            const SizedBox(height: 15),
            Text(l.travelYourWay,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _modeIcons.entries
                    .map((entry) => ChoiceChip(
                        selected: _mode == entry.key,
                        label: Text(_modeName(entry.key)),
                        avatar: Icon(entry.value, size: 19),
                        onSelected: (_) => setState(() {
                              _invalidate();
                              _mode = entry.key;
                            })))
                    .toList()),
            const SizedBox(height: 20),
            FilledButton.icon(
                onPressed:
                    _loading || _places.any((p) => p == null) ? null : _find,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.route),
                label: Text(_loading ? l.findingRoute : l.findRoute)),
            if (_error != null)
              Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(_error!, style: TextStyle(color: colors.error))),
            const SizedBox(height: 20),
            AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _resultsArea(colors)),
            const SizedBox(height: 20),
            Text(l.coverageNote, style: Theme.of(context).textTheme.bodySmall),
          ]));
      if (wide) {
        return Row(children: [
          SizedBox(width: 420, child: panel),
          Expanded(child: map)
        ]);
      }
      return Column(children: [
        Expanded(flex: 4, child: map),
        Expanded(flex: 6, child: panel)
      ]);
    })));
  }
  /// Results-area state: skeleton while the request is in flight, then the
  /// route options, then the welcome card. Leaving the welcome card up during a
  /// request made a 45 s wait look like an idle, finished layout.
  Widget _resultsArea(ColorScheme colors) {
    final l = this.l;
    if (_loading) {
      return Column(key: const ValueKey('loading'), children: [
        for (var i = 0; i < 3; i++)
          const Padding(
              padding: EdgeInsets.only(bottom: 8), child: _SkeletonOption())
      ]);
    }
    if (_options.isEmpty) {
      return Container(
          key: const ValueKey('welcome'),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: colors.primaryContainer.withValues(alpha: .35),
              borderRadius: BorderRadius.circular(18)),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.route, size: 30),
                const SizedBox(height: 12),
                Text(l.yourCityYourPace,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(l.mapHelp)
              ]));
    }
    return Column(key: const ValueKey('results'), children: [
      Row(children: [
        Expanded(
            child: Text(l.routeOptions,
                style: Theme.of(context).textTheme.titleMedium)),
        DropdownButton<String>(
            value: _sort,
            items: [
              DropdownMenuItem(value: 'fastest', child: Text(l.fastest)),
              DropdownMenuItem(value: 'cheapest', child: Text(l.cheapest))
            ],
            onChanged: (v) => setState(() {
                  _sort = v!;
                  _sortOptions();
                }))
      ]),
      for (final option in _options)
        Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
                color: identical(option, _selected)
                    ? colors.primaryContainer
                    : colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                child: ListTile(
                    selected: identical(option, _selected),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    leading: Icon(_modeIcons[(option['modes'] as List).first]),
                    title: Text(
                        _modeName((option['modes'] as List).first as String)),
                    // One line only: a wrapping subtitle used to make the
                    // ListTile grow and shove the rest of the panel around.
                    subtitle: Text(
                        '${l.distanceKilometers(((option['distance_m'] as num) / 1000).toStringAsFixed(1))} ${l.metaSeparator} ${(option['legs'] as List).any((leg) => leg['estimate'] == true) ? l.priceUnavailable : '${option['cost_vnd']} ₫'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    trailing: Text(
                        '${((option['duration_s'] as num) / 60).ceil()} ${l.minutesShort}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    onTap: () => setState(() => _selected = option)))),
      Text(l.routeEstimateNote, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 12),
      SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
              onPressed: () => _drive(false),
              icon: const Icon(Icons.navigation),
              label: Text(l.startNavigation))),
      const SizedBox(height: 8),
      SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
              onPressed: () => _drive(true),
              icon: const Icon(Icons.play_arrow),
              label: Text(l.previewDrive))),
    ]);
  }
}

/// Neutral placeholder shaped like a route option row, shown while a plan is
/// in flight so the panel keeps its final height instead of jumping.
class _SkeletonOption extends StatelessWidget {
  const _SkeletonOption();
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget bar(double width, double height) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6)));
    return Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          bar(32, 32),
          const SizedBox(width: 16),
          Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bar(110, 13),
                const SizedBox(height: 8),
                bar(160, 11)
              ])
        ]));
  }
}