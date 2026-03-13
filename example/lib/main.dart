import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:smart_scroll/smart_scroll.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Scroll Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const DemoSelector(),
    );
  }
}

// ─── Demo selector ─────────────────────────────────────────────────
class DemoSelector extends StatelessWidget {
  const DemoSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Smart Scroll Demos')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Classic Header (WaterDrop)'),
            subtitle: const Text('Original indicator'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ClassicDemo()),
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('🆕 PlatformHeader Demo'),
            subtitle: const Text('iOS = Cupertino spinner, Android = Material'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PlatformHeaderDemo()),
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('🆕 BuilderHeader Demo'),
            subtitle:
                const Text('Custom indicator with dragProgress animation'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BuilderHeaderDemo()),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Classic Demo (original) ───────────────────────────────────────
class ClassicDemo extends StatefulWidget {
  const ClassicDemo({super.key});

  @override
  State<ClassicDemo> createState() => _ClassicDemoState();
}

class _ClassicDemoState extends State<ClassicDemo> {
  List<String> items = ["1", "2", "3", "4", "5", "6", "7", "8"];
  final RefreshController _refreshController =
      RefreshController(initialRefresh: false);

  void _onRefresh() async {
    await Future.delayed(const Duration(milliseconds: 1000));
    _refreshController.refreshCompleted();
  }

  void _onLoading() async {
    await Future.delayed(const Duration(milliseconds: 1000));
    items.add((items.length + 1).toString());
    if (mounted) setState(() {});
    _refreshController.loadComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Classic Header')),
      body: SafeArea(
        child: SmartScroll(
          enablePullDown: true,
          enablePullUp: true,
          header: const WaterDropHeader(),
          controller: _refreshController,
          onRefresh: _onRefresh,
          onLoading: _onLoading,
          child: ListView.builder(
            itemBuilder: (c, i) => Card(child: Center(child: Text(items[i]))),
            itemExtent: 100.0,
            itemCount: items.length,
          ),
        ),
      ),
    );
  }
}

// ─── PlatformHeader Demo ───────────────────────────────────────────
// Tests the native-adaptive indicator (iOS = Cupertino, Android = Material)
class PlatformHeaderDemo extends StatefulWidget {
  const PlatformHeaderDemo({super.key});

  @override
  State<PlatformHeaderDemo> createState() => _PlatformHeaderDemoState();
}

class _PlatformHeaderDemoState extends State<PlatformHeaderDemo> {
  List<String> items = List.generate(15, (i) => 'Item ${i + 1}');
  final RefreshController _refreshController =
      RefreshController(initialRefresh: false);

  void _onRefresh() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    _refreshController.refreshCompleted();
  }

  void _onLoading() async {
    await Future.delayed(const Duration(milliseconds: 1000));
    final start = items.length;
    items.addAll(List.generate(5, (i) => 'Item ${start + i + 1}'));
    if (mounted) setState(() {});
    _refreshController.loadComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PlatformHeader Demo'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                Theme.of(context).platform == TargetPlatform.iOS
                    ? '🍎 iOS Mode'
                    : '🤖 Android Mode',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SmartScroll(
          enablePullDown: true,
          enablePullUp: true,
          controller: _refreshController,
          onRefresh: _onRefresh,
          onLoading: _onLoading,

          // ★ Native-adaptive header — auto picks Cupertino or Material
          header: PlatformHeader(),

          // ★ Native-adaptive footer
          footer: const PlatformFooter(),

          child: ListView.builder(
            itemBuilder: (c, i) => Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                leading: CircleAvatar(child: Text('${i + 1}')),
                title: Text(items[i]),
                subtitle: const Text('Pull down to see native refresh'),
              ),
            ),
            itemCount: items.length,
          ),
        ),
      ),
    );
  }
}

// ─── BuilderHeader Demo ────────────────────────────────────────────
// Demonstrates the new BuilderHeader API with dragProgress-driven animation
class BuilderHeaderDemo extends StatefulWidget {
  const BuilderHeaderDemo({super.key});

  @override
  State<BuilderHeaderDemo> createState() => _BuilderHeaderDemoState();
}

class _BuilderHeaderDemoState extends State<BuilderHeaderDemo> {
  List<String> items = List.generate(15, (i) => 'Item ${i + 1}');
  final RefreshController _refreshController =
      RefreshController(initialRefresh: false);

  void _onRefresh() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    _refreshController.refreshCompleted();
  }

  void _onLoading() async {
    await Future.delayed(const Duration(milliseconds: 1000));
    final start = items.length;
    items.addAll(List.generate(5, (i) => 'Item ${start + i + 1}'));
    if (mounted) setState(() {});
    _refreshController.loadComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BuilderHeader Demo')),
      body: SafeArea(
        child: SmartScroll(
          enablePullDown: true,
          enablePullUp: true,
          controller: _refreshController,
          onRefresh: _onRefresh,
          onLoading: _onLoading,

          // ★ NEW: BuilderHeader with full indicator data
          header: BuilderHeader(
            height: 80,
            triggerDistance: 80,
            builder: (context, indicator) {
              return _AnimatedRefreshIndicator(indicator: indicator);
            },
          ),

          // ★ NEW: BuilderFooter with full indicator data
          footer: BuilderFooter(
            builder: (context, indicator) {
              if (indicator.isNoMore) {
                return const SizedBox(
                  height: 60,
                  child: Center(
                    child: Text('No more data',
                        style: TextStyle(color: Colors.grey)),
                  ),
                );
              }
              if (indicator.isActive) {
                return const SizedBox(
                  height: 60,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return const SizedBox(
                height: 60,
                child: Center(
                  child: Text('Pull to load more',
                      style: TextStyle(color: Colors.grey)),
                ),
              );
            },
          ),

          child: ListView.builder(
            itemBuilder: (c, i) => Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                leading: CircleAvatar(child: Text('${i + 1}')),
                title: Text(items[i]),
                subtitle: Text('Subtitle for item ${i + 1}'),
              ),
            ),
            itemCount: items.length,
          ),
        ),
      ),
    );
  }
}

/// Custom animated indicator that uses dragProgress to drive visuals.
/// This is the kind of indicator you'd build with Lottie in production.
class _AnimatedRefreshIndicator extends StatelessWidget {
  final RefreshIndicatorData indicator;

  const _AnimatedRefreshIndicator({required this.indicator});

  @override
  Widget build(BuildContext context) {
    final progress = indicator.dragProgress;
    final mode = indicator.mode;

    return SizedBox(
      height: 80,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated icon that rotates based on drag progress
          _buildIcon(mode, progress),
          const SizedBox(height: 8),
          // Status text
          Text(
            _statusText(mode, progress),
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
          // Progress bar showing exact drag position
          if (mode != RefreshStatus.refreshing &&
              mode != RefreshStatus.completed)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(
                    indicator.triggered
                        ? Colors.green
                        : Colors.deepPurple.shade300,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIcon(RefreshStatus? mode, double progress) {
    if (mode == RefreshStatus.refreshing) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (mode == RefreshStatus.completed) {
      return const Icon(Icons.check_circle, color: Colors.green, size: 24);
    }
    if (mode == RefreshStatus.failed) {
      return const Icon(Icons.error, color: Colors.red, size: 24);
    }

    // Rotate arrow based on drag progress
    return Transform.rotate(
      angle: progress * math.pi, // 0° → 180° as user pulls
      child: Icon(
        Icons.arrow_downward,
        color: indicator.triggered ? Colors.green : Colors.deepPurple,
        size: 24,
      ),
    );
  }

  String _statusText(RefreshStatus? mode, double progress) {
    switch (mode) {
      case RefreshStatus.idle:
        return 'Pull to refresh (${(progress * 100).toInt()}%)';
      case RefreshStatus.canRefresh:
        return 'Release to refresh! ✓';
      case RefreshStatus.refreshing:
        return 'Refreshing...';
      case RefreshStatus.completed:
        return 'Done! ✓';
      case RefreshStatus.failed:
        return 'Failed ✗';
      default:
        return '';
    }
  }
}
