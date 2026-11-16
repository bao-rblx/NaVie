import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navie/features/planner/planner_screen.dart';
import 'package:navie/l10n/app_localizations.dart';

/// Serves a plan that never resolves until [gate] completes, so the loading
/// state can be inspected.
class SlowApi implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  Completer<ResponseBody> gate = Completer<ResponseBody>();
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    if (options.path == '/v1/geocode') {
      final name = options.queryParameters['q'];
      return ResponseBody.fromString(
          jsonEncode([
            {
              'name': name,
              'latlon': [10.77, name == 'Origin' ? 106.70 : 106.71]
            }
          ]),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          });
    }
    return gate.future;
  }

  ResponseBody plan() => ResponseBody.fromString(
      jsonEncode({
        'options': [
          {
            'id': 'm',
            'modes': ['motorbike'],
            'duration_s': 200,
            'distance_m': 1000,
            'cost_vnd': 0,
            'legs': [
              {
                'geometry': [
                  [10.77, 106.7],
                  [10.77, 106.71]
                ],
                'maneuvers': [],
                'duration_s': 200,
                'distance_m': 1000,
                'estimate': true
              }
            ]
          }
        ]
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });
  @override
  void close({bool force = false}) {}
}

Future<SlowApi> mount(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final api = SlowApi();
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))
    ..httpClientAdapter = api;
  await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: PlannerScreen(showMap: false, api: dio)));
  return api;
}

Future<void> choose(WidgetTester tester, int index, String name) async {
  final field = find.byType(TextField).at(index);
  await tester.ensureVisible(field);
  await tester.enterText(field, name);
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pumpAndSettle();
  final suggestion = find.widgetWithText(ListTile, name);
  await tester.ensureVisible(suggestion);
  await tester.tap(suggestion);
  await tester.pumpAndSettle();
}

/// Taps "Find route" and waits for the request to reach the adapter and for the
/// 220 ms AnimatedSwitcher to finish, without resolving the response.
Future<void> findRoute(WidgetTester tester) async {
  await tester.scrollUntilVisible(find.text('Find route'), 250,
      scrollable:
          find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Find route'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('skeleton cards replace the welcome card while planning',
      (tester) async {
    final api = await mount(tester);
    await choose(tester, 0, 'Origin');
    await choose(tester, 1, 'Destination');
    expect(find.text('Your city. Your pace.'), findsOneWidget,
        reason: 'idle state shows the welcome card');

    await findRoute(tester);
    expect(find.text('Your city. Your pace.'), findsNothing,
        reason: 'the welcome card must not stay up during a request');
    expect(find.byKey(const ValueKey('loading')), findsOneWidget);
    // Three placeholders shaped like the result rows.
    expect(find.byType(ListTile), findsNothing,
        reason: 'no real options yet, only skeletons');

    api.gate.complete(api.plan());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('loading')), findsNothing);
    expect(find.byKey(const ValueKey('results')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the chosen sort reaches the server as optimize', (tester) async {
    final api = await mount(tester);
    await choose(tester, 0, 'Origin');
    await choose(tester, 1, 'Destination');

    await findRoute(tester);
    expect(api.requests.where((r) => r.path == '/v1/plan'), hasLength(1));
    expect(api.requests.last.path, '/v1/plan');
    expect(api.requests.last.data['optimize'], 'fastest');
    api.gate.complete(api.plan());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Fastest'), 200,
        scrollable: find
            .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
            .first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fastest'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lowest cost').last);
    await tester.pumpAndSettle();

    api.gate = Completer<ResponseBody>();
    await findRoute(tester);
    expect(api.requests.last.data['optimize'], 'cheapest',
        reason: 'the sort selection must drive the backend, not a constant');
    api.gate.complete(api.plan());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('the option subtitle stays on one line with an ellipsis',
      (tester) async {
    final api = await mount(tester);
    await choose(tester, 0, 'Origin');
    await choose(tester, 1, 'Destination');
    await findRoute(tester);
    api.gate.complete(api.plan());
    await tester.pumpAndSettle();

    final subtitle = tester.widgetList<Text>(find.descendant(
        of: find.byType(ListTile), matching: find.byType(Text))).firstWhere(
        (t) => (t.data ?? '').contains('km'));
    expect(subtitle.maxLines, 1);
    expect(subtitle.overflow, TextOverflow.ellipsis);
    expect(subtitle.data, '1.0 km · Price not verified');
    expect(tester.takeException(), isNull);
  });
}
