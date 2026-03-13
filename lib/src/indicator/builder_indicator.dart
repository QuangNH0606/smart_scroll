import 'package:flutter/widgets.dart';
import '../internals/indicator_wrap.dart';
import '../smart_refresher.dart';

/// Data class containing all indicator state for builder callbacks.
/// Provides everything a custom indicator needs to render any animation.
///
/// Example with Lottie:
/// ```dart
/// BuilderHeader(
///   builder: (context, indicator) {
///     return Lottie.asset(
///       'assets/refresh.json',
///       controller: _lottieController,
///       // Use dragProgress (0.0 → 1.0) to drive animation frame
///     );
///   },
///   onStateChange: (indicator) {
///     if (indicator.mode == RefreshStatus.refreshing) {
///       _lottieController.repeat();
///     } else if (indicator.mode == RefreshStatus.completed) {
///       _lottieController.animateTo(1.0);
///     } else {
///       // Scrub animation to match drag progress
///       _lottieController.value = indicator.dragProgress;
///     }
///   },
/// )
/// ```
class RefreshIndicatorData {
  const RefreshIndicatorData({
    required this.mode,
    required this.offset,
    required this.triggerDistance,
    required this.indicatorHeight,
  });

  /// Current refresh status (idle, canRefresh, refreshing, completed, failed)
  final RefreshStatus? mode;

  /// Raw scroll offset in pixels from the edge
  final double offset;

  /// The trigger distance configured in RefreshConfiguration
  final double triggerDistance;

  /// The indicator widget height
  final double indicatorHeight;

  /// Normalized drag progress: 0.0 (idle) → 1.0 (trigger reached)
  /// Can exceed 1.0 if user drags beyond trigger distance.
  double get dragProgress =>
      triggerDistance > 0 ? (offset / triggerDistance).clamp(0.0, 2.0) : 0.0;

  /// Whether the indicator has been pulled past the trigger threshold
  bool get triggered => offset >= triggerDistance;

  /// Whether the indicator is currently in a loading/refreshing state
  bool get isActive =>
      mode == RefreshStatus.refreshing ||
      mode == RefreshStatus.canRefresh ||
      mode == RefreshStatus.twoLeveling;
}

/// Same data for load indicators
class LoadIndicatorData {
  const LoadIndicatorData({
    required this.mode,
    required this.offset,
    required this.indicatorHeight,
  });

  /// Current load status (idle, canLoading, loading, noMore, failed)
  final LoadStatus? mode;

  /// Raw scroll offset in pixels from the bottom edge
  final double offset;

  /// The indicator widget height
  final double indicatorHeight;

  /// Whether the indicator is currently loading
  bool get isActive => mode == LoadStatus.loading;

  /// Whether there is no more data to load
  bool get isNoMore => mode == LoadStatus.noMore;
}

/// Builder typedef that receives full indicator data
typedef RefreshIndicatorBuilder = Widget Function(
    BuildContext context, RefreshIndicatorData indicator);

/// State change callback — fires on mode transitions, useful for
/// starting/stopping animation controllers
typedef RefreshStateCallback = void Function(RefreshIndicatorData indicator);

/// Builder typedef for load indicators
typedef LoadIndicatorBuilder = Widget Function(
    BuildContext context, LoadIndicatorData indicator);

/// State change callback for load indicators
typedef LoadStateCallback = void Function(LoadIndicatorData indicator);

// ──────────────────────────────────────────────────────────────────────
// BuilderHeader — Enhanced custom header with full state data
// ──────────────────────────────────────────────────────────────────────

/// A header indicator that provides complete state data for building
/// custom refresh animations (Lottie, Rive, custom painters, etc.)
///
/// Unlike [CustomHeader] which only passes `mode`, this passes
/// [RefreshIndicatorData] containing offset, progress, and trigger info.
///
/// ```dart
/// SmartScroll(
///   header: BuilderHeader(
///     builder: (context, indicator) {
///       return AnimatedBuilder(
///         progress: indicator.dragProgress,
///         isRefreshing: indicator.mode == RefreshStatus.refreshing,
///       );
///     },
///   ),
///   ...
/// )
/// ```
class BuilderHeader extends RefreshIndicator {
  const BuilderHeader({
    super.key,
    required this.builder,
    this.onStateChange,
    this.readyToRefresh,
    this.endRefresh,
    this.onResetValue,
    this.triggerDistance = 80.0,
    super.height = 60.0,
    super.completeDuration = const Duration(milliseconds: 600),
    RefreshStyle super.refreshStyle = RefreshStyle.Follow,
  });

  /// Builder that receives full indicator state data.
  final RefreshIndicatorBuilder builder;

  /// Called on every mode transition. Use this to control
  /// external animation controllers (Lottie, Rive, etc.)
  final RefreshStateCallback? onStateChange;

  /// The trigger distance — should match RefreshConfiguration.headerTriggerDistance
  final double triggerDistance;

  final VoidFutureCallBack? readyToRefresh;
  final VoidFutureCallBack? endRefresh;
  final VoidCallback? onResetValue;

  @override
  State<StatefulWidget> createState() => _BuilderHeaderState();
}

class _BuilderHeaderState extends RefreshIndicatorState<BuilderHeader> {
  double _currentOffset = 0.0;

  RefreshIndicatorData get _indicatorData => RefreshIndicatorData(
        mode: mode,
        offset: _currentOffset,
        triggerDistance: widget.triggerDistance,
        indicatorHeight: widget.height,
      );

  @override
  void onOffsetChange(double offset) {
    _currentOffset = offset;
    super.onOffsetChange(offset);
  }

  @override
  void onModeChange(RefreshStatus? mode) {
    if (widget.onStateChange != null) {
      widget.onStateChange!(_indicatorData);
    }
    super.onModeChange(mode);
  }

  @override
  Future<void> readyToRefresh() {
    if (widget.readyToRefresh != null) {
      return widget.readyToRefresh!();
    }
    return super.readyToRefresh();
  }

  @override
  Future<void> endRefresh() {
    if (widget.endRefresh != null) {
      return widget.endRefresh!();
    }
    return super.endRefresh();
  }

  @override
  void resetValue() {
    if (widget.onResetValue != null) {
      widget.onResetValue!();
    }
    super.resetValue();
  }

  @override
  Widget buildContent(BuildContext context, RefreshStatus? mode) {
    return widget.builder(context, _indicatorData);
  }
}

// ──────────────────────────────────────────────────────────────────────
// BuilderFooter — Enhanced custom footer with full state data
// ──────────────────────────────────────────────────────────────────────

/// A footer indicator that provides complete state data for building
/// custom load-more animations.
///
/// ```dart
/// SmartScroll(
///   footer: BuilderFooter(
///     builder: (context, indicator) {
///       if (indicator.isNoMore) return Text('No more data');
///       if (indicator.isActive) return CircularProgressIndicator();
///       return Text('Pull to load more');
///     },
///   ),
///   ...
/// )
/// ```
class BuilderFooter extends LoadIndicator {
  const BuilderFooter({
    super.key,
    required this.builder,
    this.onStateChange,
    this.readyLoading,
    this.endLoading,
    super.height = 60.0,
    super.loadStyle = LoadStyle.ShowAlways,
    super.onClick,
  });

  /// Builder that receives full indicator state data.
  final LoadIndicatorBuilder builder;

  /// Called on every mode transition.
  final LoadStateCallback? onStateChange;

  final VoidFutureCallBack? readyLoading;
  final VoidFutureCallBack? endLoading;

  @override
  State<StatefulWidget> createState() => _BuilderFooterState();
}

class _BuilderFooterState extends LoadIndicatorState<BuilderFooter> {
  double _currentOffset = 0.0;

  LoadIndicatorData get _indicatorData => LoadIndicatorData(
        mode: mode,
        offset: _currentOffset,
        indicatorHeight: widget.height,
      );

  @override
  void onOffsetChange(double offset) {
    _currentOffset = offset;
    super.onOffsetChange(offset);
  }

  @override
  void onModeChange(LoadStatus? mode) {
    if (widget.onStateChange != null) {
      widget.onStateChange!(_indicatorData);
    }
    super.onModeChange(mode);
  }

  @override
  Future readyToLoad() {
    if (widget.readyLoading != null) {
      return widget.readyLoading!();
    }
    return super.readyToLoad();
  }

  @override
  Future endLoading() {
    if (widget.endLoading != null) {
      return widget.endLoading!();
    }
    return super.endLoading();
  }

  @override
  Widget buildContent(BuildContext context, LoadStatus? mode) {
    return widget.builder(context, _indicatorData);
  }
}
