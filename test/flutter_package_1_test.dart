import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scroll/smart_scroll.dart';

void main() {
  group('RefreshController Tests', () {
    test('Dispose safety: controller runs safely after calling dispose()', () {
      final controller = RefreshController();
      controller.dispose();
      controller.dispose();

      // Verify no-ops and no exceptions
      expect(() => controller.refreshCompleted(), returnsNormally);
      expect(() => controller.refreshFailed(), returnsNormally);
      expect(() => controller.refreshToIdle(), returnsNormally);
      expect(() => controller.loadComplete(), returnsNormally);
      expect(() => controller.loadFailed(), returnsNormally);
      expect(() => controller.loadNoData(), returnsNormally);
      expect(() => controller.resetNoData(), returnsNormally);
      expect(() => controller.requestRefresh(), returnsNormally);
      expect(() => controller.requestLoading(), returnsNormally);
      expect(() => controller.twoLevelComplete(), returnsNormally);
      expect(() => controller.requestTwoLevel(), returnsNormally);
    });

    testWidgets(
        'Dispose while mounted: outgoing route can rebuild its final frame',
        (WidgetTester tester) async {
      final controller = RefreshController();

      Widget buildApp() {
        return MaterialApp(
          home: SmartScroll(
            controller: controller,
            // Intentionally non-const to exercise didUpdateWidget like
            // production builders that create indicators on every rebuild.
            // ignore: prefer_const_constructors
            header: MaterialClassicHeader(),
            // ignore: prefer_const_constructors
            footer: ClassicFooter(),
            child: ListView(
              children: const [Text('Item')],
            ),
          ),
        );
      }

      await tester.pumpWidget(buildApp());
      expect(tester.takeException(), isNull);

      controller.dispose();
      expect(controller.headerMode, isNotNull);
      expect(controller.footerMode, isNotNull);

      await tester.pumpWidget(buildApp());

      expect(tester.takeException(), isNull);
      expect(find.text('Item'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
      expect(controller.headerMode, isNull);
      expect(controller.footerMode, isNull);
    });

    testWidgets('Controller replacement detaches the old controller safely',
        (WidgetTester tester) async {
      final oldController = RefreshController(
        initialRefreshStatus: RefreshStatus.completed,
        initialLoadStatus: LoadStatus.failed,
      );
      final newController = RefreshController();

      Widget buildApp(RefreshController controller) {
        return MaterialApp(
          home: SmartScroll(
            controller: controller,
            child: ListView(
              children: const [Text('Item')],
            ),
          ),
        );
      }

      await tester.pumpWidget(buildApp(oldController));
      await tester.pumpWidget(buildApp(newController));

      expect(tester.takeException(), isNull);
      expect(newController.headerStatus, RefreshStatus.idle);
      expect(newController.footerStatus, LoadStatus.failed);

      oldController.dispose();
      expect(oldController.headerMode, isNull);
      expect(oldController.footerMode, isNull);

      await tester.pump();
      expect(tester.takeException(), isNull);

      newController.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
        'Multi-bind protection: throws StateError when bound to multiple SmartScroll widgets',
        (WidgetTester tester) async {
      final controller = RefreshController();

      final firstRefresher = SmartScroll(
        controller: controller,
        child: ListView(
          children: const [Text('Item 1'), Text('Item 2')],
        ),
      );

      final secondRefresher = SmartScroll(
        controller: controller,
        child: ListView(
          children: const [Text('Item A'), Text('Item B')],
        ),
      );

      // Build both refreshers simultaneously in a Column so they are active at the same time
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Expanded(child: firstRefresher),
              Expanded(child: secondRefresher),
            ],
          ),
        ),
      ));

      final dynamic exception = tester.takeException();
      expect(exception, isA<StateError>());
      expect(
        exception.toString(),
        contains(
            'A RefreshController can only be used with one SmartScroll widget at a time.'),
      );

      // Consume any cascading exceptions just in case
      while (tester.takeException() != null) {}
    });

    testWidgets(
        'Timeout mechanism: automatically fails after timeout when refreshing',
        (WidgetTester tester) async {
      final controller = RefreshController();
      bool onRefreshCalled = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SmartScroll(
            controller: controller,
            enablePullDown: true,
            refreshTimeout: const Duration(milliseconds: 50),
            onRefresh: () {
              onRefreshCalled = true;
            },
            child: ListView(
              children: const [Text('Item 1'), Text('Item 2')],
            ),
          ),
        ),
      ));

      // Call requestRefresh with needMove: false to transition state instantly without scroll animation
      controller.requestRefresh(needMove: false);
      await tester.pump(); // Run the future task that sets status to refreshing

      expect(controller.headerMode!.value, RefreshStatus.refreshing);

      // Wait for timeout to expire (needs more than 50ms)
      await tester.pump(const Duration(milliseconds: 100));

      // The status should now transition to failed automatically because of timeout
      expect(controller.headerMode!.value, RefreshStatus.failed);
      expect(onRefreshCalled, isTrue);

      // Advance clock to clean up all timers (like 300ms endRefresh / endLoading timers)
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
    });

    testWidgets(
        'Timeout mechanism: automatically fails after timeout when loading',
        (WidgetTester tester) async {
      final controller = RefreshController();
      bool onLoadingCalled = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SmartScroll(
            controller: controller,
            enablePullUp: true,
            loadTimeout: const Duration(milliseconds: 50),
            onLoading: () {
              onLoadingCalled = true;
            },
            child: ListView(
              children: const [Text('Item 1'), Text('Item 2')],
            ),
          ),
        ),
      ));

      // Call requestLoading with needMove: false to transition state instantly without scroll animation
      controller.requestLoading(needMove: false);
      await tester.pump(); // Run the future task that sets status to loading

      expect(controller.footerMode!.value, LoadStatus.loading);

      // Wait for timeout to expire (needs more than 50ms)
      await tester.pump(const Duration(milliseconds: 100));

      // The status should now transition to failed automatically because of timeout
      expect(controller.footerMode!.value, LoadStatus.failed);
      expect(onLoadingCalled, isTrue);

      // Advance clock to clean up all timers (like 300ms endRefresh / endLoading timers)
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
    });

    testWidgets('Timeout updates when the widget keeps the same controller',
        (WidgetTester tester) async {
      final controller = RefreshController();

      Widget buildApp(Duration timeout) {
        return MaterialApp(
          home: SmartScroll(
            controller: controller,
            enablePullDown: true,
            refreshTimeout: timeout,
            onRefresh: () {},
            child: ListView(
              children: const [Text('Item')],
            ),
          ),
        );
      }

      await tester.pumpWidget(buildApp(const Duration(seconds: 1)));
      controller.requestRefresh(needMove: false);
      await tester.pump();
      expect(controller.headerStatus, RefreshStatus.refreshing);

      await tester.pumpWidget(buildApp(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 100));

      expect(controller.headerStatus, RefreshStatus.failed);
      expect(tester.takeException(), isNull);

      controller.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  });

  group('Compatibility Tests', () {
    test('Built-in localization strings remain customizable', () {
      final strings = EnRefreshString();
      strings.idleRefreshText = 'Custom refresh';

      expect(strings.idleRefreshText, 'Custom refresh');
    });

    test('RefreshConfiguration keeps the 1.0.4 default spring', () {
      const configuration = RefreshConfiguration(child: SizedBox.shrink());

      expect(configuration.springDescription.mass, 1.0);
      expect(configuration.springDescription.stiffness, 100);
      expect(configuration.springDescription.damping, 16);
    });

    test('RefreshPhysics respects a custom spring on every platform', () {
      final controller = RefreshController();
      const customSpring = SpringDescription(
        mass: 2,
        stiffness: 250,
        damping: 30,
      );
      final physics = RefreshPhysics(
        parent: const BouncingScrollPhysics(),
        controller: controller,
        springDescription: customSpring,
      );
      final metrics = FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: 100,
        pixels: -20,
        viewportDimension: 400,
        axisDirection: AxisDirection.down,
        devicePixelRatio: 1,
      );

      final simulation = physics.createBallisticSimulation(metrics, 0);

      expect(simulation, isA<BouncingScrollSimulation>());
      expect(
        (simulation! as BouncingScrollSimulation).spring,
        same(customSpring),
      );
      controller.dispose();
    });
  });
}
