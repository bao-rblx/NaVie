import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navie/features/driver/driver_screen.dart';
import 'package:navie/features/driver/navigation_progress.dart';
import 'package:navie/l10n/app_localizations.dart';

// ~1.09 km west-to-east at this latitude, so the banner reads out in meters and
// a single tick visibly changes the digits.
const _route = {
  'geometry': [
    [10.77, 106.70],
    [10.77, 106.71]
  ],
  'duration_s': 1095,
  'distance_m': 1095,
  'maneuvers': [
    {'at_index': 1, 'type': 'turn_right', 'text_en': 'Turn right', 'text_vi': 'Rẽ phải'}
  ]
};

/// Two turns on one straight road, so both can come into range during a run.
const _twoTurnRoute = {
  'geometry': [
    [10.77, 106.70],
    [10.77, 106.705],
    [10.77, 106.71]
  ],
  'duration_s': 1095,
  'distance_m': 1095,
  'maneuvers': [
    {'at_index': 1, 'type': 'turn_right', 'text_en': 'Turn right', 'text_vi': 'Rẽ phải'},
    {'at_index': 2, 'type': 'turn_left', 'text_en': 'Turn left', 'text_vi': 'Rẽ trái'}
  ]
};
const _path = [(lat: 10.77, lon: 106.70), (lat: 10.77, lon: 106.71)];

/// The banner readout the screen must show after [seconds] of measured
/// playback at [playback]x, derived from the same model the screen uses
/// (including its "<1 km shows whole metres" formatting).
String bannerAfter(double seconds, {int playback = 3}) {
  final model = NavigationProgress(_path, 1095)..advance(seconds * playback);
  final meters = model.total - model.progress;
  return meters < 1000
      ? '${(meters / 10).round() * 10} m'
      : '${(meters / 1000).toStringAsFixed(1)} km';
}

Future<void> mountDriver(WidgetTester tester,
    {required bool preview,
    Duration Function()? elapsed,
    bool mockTts = true,
    Map<String, dynamic> route = _route}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  if (mockTts) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter_tts'), (call) async => 1);
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), null));
  }
  await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DriverScreen(
          route: route,
          destination: (lat: 10.77, lon: 106.71),
          mode: 'motorbike',
          api: Dio(BaseOptions(baseUrl: 'http://localhost')),
          preview: preview,
          showMap: false,
          elapsed: elapsed)));
  await tester.pump();
}

/// The banner's big distance readout: the first Text in the driver tree.
String banner(WidgetTester tester) =>
    (find.byType(Text).evaluate().first.widget as Text).data!;

/// The corrupted byte sequences this work removed, built from code points so
/// the literals never live in the source and cannot be re-corrupted by an
/// editor save.
final mojibake = [
  String.fromCharCodes([0xC3]), // the 'Ã' of a mis-saved '×'
  String.fromCharCodes([0xE2, 0x20AC]), // first two bytes of a mis-saved em dash
  String.fromCharCodes([0xC2]), // the 'Â' of a mis-saved middle dot
];

/// Records every flutter_tts platform call so the speech contract can be
/// asserted: language configured once, and stop() before each utterance.
List<MethodCall> recordTts(WidgetTester tester) {
  final calls = <MethodCall>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'), (call) async {
    calls.add(call);
    return call.method == 'getVoices' ? <dynamic>[] : 1;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('flutter_tts'), null));
  return calls;
}

void main() {
  testWidgets('preview advances by measured elapsed time, not a fixed 0.25 s',
      (tester) async {
    // Every tick claims 100 real seconds, i.e. 300 s of the trip at 3x.
    await mountDriver(tester,
        preview: true, elapsed: () => const Duration(seconds: 100));
    await tester.pump(const Duration(milliseconds: 250));

    final measured = bannerAfter(100);
    expect(banner(tester), measured);
    expect(find.text(measured), findsWidgets);

    // What the hard-coded 0.25 s constant would have moved: three orders of
    // magnitude less, which is the bug this test pins down.
    expect(measured, isNot(bannerAfter(.25)));
    expect(find.text(bannerAfter(.25)), findsNothing);

    // A second tick compounds instead of restarting.
    await tester.pump(const Duration(milliseconds: 250));
    expect(banner(tester), bannerAfter(200));
    expect(find.text(bannerAfter(200)), findsWidgets);
  });

  testWidgets('pausing freezes playback and resuming continues from there',
      (tester) async {
    await mountDriver(tester,
        preview: true, elapsed: () => const Duration(seconds: 30));
    await tester.pump(const Duration(milliseconds: 250));
    final afterFirstTick = banner(tester);
    expect(afterFirstTick, bannerAfter(30));

    await tester.tap(find.byTooltip('Pause or resume'));
    await tester.pump();
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(banner(tester), afterFirstTick,
        reason: 'a paused preview must not advance, nor bank the paused time');

    await tester.tap(find.byTooltip('Pause or resume'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(banner(tester), bannerAfter(60),
        reason: 'exactly one further tick after resuming, not the paused span');
  });

  testWidgets('a preview tick rebuilds the banner, not the whole screen',
      (tester) async {
    await mountDriver(tester,
        preview: true, elapsed: () => const Duration(seconds: 30));
    await tester.pump();
    // The end-of-drive button is outside the notifier subtree, so it must keep
    // its widget identity across ticks; the old whole-screen setState recreated
    // it four times a second along with every map tile.
    final buttonBefore = tester.widget<Text>(find.text('End drive'));
    final bannerBefore = tester.widget<Text>(find.byType(Text).first);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    final buttonAfter = tester.widget<Text>(find.text('End drive'));
    final bannerAfter = tester.widget<Text>(find.byType(Text).first);
    expect(identical(buttonBefore, buttonAfter), isTrue,
        reason: 'the rest of the screen must not rebuild on a tick');
    expect(identical(bannerBefore, bannerAfter), isFalse,
        reason: 'the banner must rebuild to show the new distance');
    expect(bannerBefore.data, isNot(bannerAfter.data));
  });

  testWidgets('speech configures language once and stops before each prompt',
      (tester) async {
    final calls = recordTts(tester);
    // 30 s per tick at 1x walks in through the 500 m and then the 200 m
    // threshold, which is exactly the case where queued prompts played stale
    // distances one after another.
    await mountDriver(tester,
        preview: true,
        elapsed: () => const Duration(seconds: 30),
        mockTts: false,
        route: _twoTurnRoute);
    await tester.pump();
    for (var i = 0; i < 14; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    final languages = calls.where((c) => c.method == 'setLanguage');
    expect(languages.length, lessThanOrEqualTo(1),
        reason: 'setLanguage is a platform round trip; once is enough');
    expect(languages.single.arguments, 'en-US');

    final spoken = calls.where((c) => c.method == 'speak').toList();
    expect(spoken.length, greaterThanOrEqualTo(2),
        reason: 'two maneuvers in range must produce two prompts');
    // Every utterance is immediately preceded by its own stop(), so no two
    // prompts can overlap or queue up behind each other.
    for (final call in spoken) {
      final index = calls.indexOf(call);
      expect(index, greaterThan(0));
      expect(calls[index - 1].method, 'stop',
          reason: 'speak() must be preceded by stop()');
      final stopsBefore = calls.take(index).where((c) => c.method == 'stop');
      expect(stopsBefore.length,
          greaterThanOrEqualTo(spoken.indexOf(call) + 1),
          reason: 'each utterance needs its own stop(), not a shared one');
    }
    // Distances are recomputed per prompt, so the second is smaller.
    final messages = spoken.map((c) => c.arguments as String).toList();
    expect(messages.first, contains('meters.'));
    expect(messages.first, contains('Turn right'));
    final first = int.parse(RegExp(r'^(\d+)').firstMatch(messages.first)![1]!);
    final second =
        int.parse(RegExp(r'^(\d+)').firstMatch(messages[1])![1]!);
    expect(second, lessThan(first),
        reason: 'the newer prompt must not repeat the stale distance');
  });

  testWidgets('muting stops the current utterance immediately', (tester) async {
    final calls = recordTts(tester);
    await mountDriver(tester,
        preview: true,
        elapsed: () => const Duration(seconds: 30),
        mockTts: false,
        route: _twoTurnRoute);
    await tester.pump();
    for (var i = 0; i < 12 && !calls.any((c) => c.method == 'speak'); i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(calls.where((c) => c.method == 'speak'), isNotEmpty);

    final beforeMute = calls.length;
    await tester.tap(find.byTooltip('Voice guidance'), warnIfMissed: false);
    await tester.pump();
    final duringMute = calls.skip(beforeMute).toList();
    expect(duringMute.where((c) => c.method == 'stop'), isNotEmpty,
        reason: 'mute must silence the in-flight prompt, not just future ones');
    expect(duringMute.where((c) => c.method == 'speak'), isEmpty);

    final afterMute = calls.length;
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(calls.skip(afterMute).where((c) => c.method == 'speak'), isEmpty,
        reason: 'a muted screen must stay silent while the route continues');
  });

  testWidgets('playback multiplier renders U+00D7, not the mojibake',
      (tester) async {
    await mountDriver(tester, preview: true);
    // The multiplier label must use U+00D7 MULTIPLICATION SIGN.
    expect(find.text('3×'), findsOneWidget);
    for (final bad in mojibake) {
      expect(find.textContaining(bad), findsNothing);
    }

    await tester.tap(find.text('3×'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1×').last);
    await tester.pumpAndSettle();
    expect(find.text('1×'), findsOneWidget);
    expect(find.text('3×'), findsNothing);
  });

  testWidgets('speed line renders U+2014 and U+00B7, not the mojibake',
      (tester) async {
    await mountDriver(tester, preview: false);
    await tester.pumpAndSettle();
    // U+2014 EM DASH and U+00B7 MIDDLE DOT, restored from a non-UTF-8 save.
    expect(find.text('— km/h · Speed limit: —'), findsOneWidget);
    for (final bad in mojibake) {
      expect(find.textContaining(bad), findsNothing);
    }
  });
}
