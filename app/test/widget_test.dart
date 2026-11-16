import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navie/features/planner/planner_screen.dart';
import 'package:navie/l10n/app_localizations.dart';

class FakeApi implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  Completer<ResponseBody>? pendingRoute;
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
    if (pendingRoute != null) return pendingRoute!.future;
    return routeResponse();
  }

  ResponseBody routeResponse() => ResponseBody.fromString(
          jsonEncode({
            'options': [
              {
                'id': 'motorbike',
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

Future<void> mount(WidgetTester tester, FakeApi adapter) async {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))
    ..httpClientAdapter = adapter;
  await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: PlannerScreen(showMap: false, api: dio)));
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

void main() {
  testWidgets('mobile planner fits viewport and requires selected endpoints',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mount(tester, FakeApi());
    expect(find.text('Where to today?'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Find route'), 250,
        scrollable: find
            .descendant(
                of: find.byType(ListView), matching: find.byType(Scrollable))
            .first);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'search to results to preview and back works without invented prices',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter_tts'), (call) async => 1);
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), null));
    final api = FakeApi();
    await mount(tester, api);
    await choose(tester, 0, 'Origin');
    await choose(tester, 1, 'Destination');
    await tester.ensureVisible(find.text('Find route'));
    await tester.tap(find.text('Find route'));
    await tester.pumpAndSettle();
    expect(api.requests.last.data['origin']['text'], 'Origin');
    expect(find.textContaining('Price not verified'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Preview drive'), 200,
        scrollable: find
            .descendant(
                of: find.byType(ListView), matching: find.byType(Scrollable))
            .first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Preview drive'));
    await tester.pumpAndSettle();
    expect(find.text('Simulation'), findsWidgets);
    expect(find.text('End drive'), findsOneWidget);
    await tester.tap(find.text('End drive'));
    await tester.pumpAndSettle();
    expect(find.text('Preview drive'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('changing endpoints discards a pending route response',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = FakeApi()..pendingRoute = Completer<ResponseBody>();
    await mount(tester, api);
    await choose(tester, 0, 'Origin');
    await choose(tester, 1, 'Destination');
    await tester.ensureVisible(find.text('Find route'));
    await tester.tap(find.text('Find route'));
    await tester.pump();
    await tester.tap(find.byTooltip('Reset trip'));
    await tester.pump();
    api.pendingRoute!.complete(api.routeResponse());
    await tester.pumpAndSettle();
    expect(find.text('Preview drive'), findsNothing);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    expect(tester.takeException(), isNull);
  });
}
