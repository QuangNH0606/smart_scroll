// ignore_for_file: sort_constructors_first

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'
    hide RefreshIndicator, RefreshIndicatorState;
import '../internals/indicator_wrap.dart';
import '../smart_refresher.dart';

/// A platform-adaptive refresh indicator that automatically picks:
/// - **iOS/macOS**: Native Cupertino-style spinner (like CupertinoSliverRefreshControl)
/// - **Android/others**: Material-style circular progress indicator
///
/// Usage:
/// ```dart
/// SmartScroll(
///   header: const PlatformHeader(),
///   // ...
/// )
/// ```
///
/// This gives users a truly native refresh experience on each platform
/// without any configuration needed.
class PlatformHeader extends RefreshIndicator {
  PlatformHeader({
    super.key,
    super.height = 60.0,
    super.completeDuration = const Duration(milliseconds: 400),
    super.offset = 0.0,
    this.color,
    this.backgroundColor,
    this.distance = 50.0,
  }) : super(
          refreshStyle:
              _isApplePlatform() ? RefreshStyle.UnFollow : RefreshStyle.Front,
        );

  /// The primary color of the indicator.
  /// Defaults to theme primary on Android, grey on iOS.
  final Color? color;

  /// Background color (only applies to Material style on Android)
  final Color? backgroundColor;

  /// Distance from top when refreshing (Android only)
  final double distance;

  @override
  State<StatefulWidget> createState() => _PlatformHeaderState();
}

bool _isApplePlatform() {
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

class _PlatformHeaderState extends RefreshIndicatorState<PlatformHeader>
    with TickerProviderStateMixin {
  // ─── Material (Android) animation controllers ───
  late AnimationController _materialScaleFactor;
  late AnimationController _materialPositionController;
  late AnimationController _materialValueAni;
  Animation<Offset>? _materialPositionFactor;
  Animation<Color?>? _materialValueColor;
  ScrollPosition? _scrollPosition;

  // ─── Cupertino (iOS) state ───
  double _cupertinoOpacity = 0.0;
  double _cupertinoTickProgress = 0.0;

  bool get _isApple => _isApplePlatform();

  @override
  void initState() {
    super.initState();

    if (!_isApple) {
      _initMaterialControllers();
    }
  }

  void _initMaterialControllers() {
    _materialValueAni = AnimationController(
      vsync: this,
      value: 0.0,
      lowerBound: 0.0,
      upperBound: 1.0,
      duration: const Duration(milliseconds: 500),
    );
    _materialValueAni.addListener(() {
      if (mounted && _scrollPosition != null && _scrollPosition!.pixels <= 0) {
        setState(() {});
      }
    });

    _materialPositionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _materialScaleFactor = AnimationController(
      vsync: this,
      value: 1.0,
      lowerBound: 0.0,
      upperBound: 1.0,
      duration: const Duration(milliseconds: 300),
    );
    _materialPositionFactor = _materialPositionController.drive(
      Tween<Offset>(
        begin: const Offset(0.0, -1.0),
        end: Offset(0.0, widget.height / 40.0),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scrollPosition = Scrollable.of(context).position;

    if (!_isApple) {
      final ThemeData theme = Theme.of(context);
      final Color indicatorColor = widget.color ?? theme.primaryColor;
      _materialValueColor = _materialPositionController.drive(
        ColorTween(
          begin: indicatorColor.withValues(alpha: 0.0),
          end: indicatorColor.withValues(alpha: 1.0),
        ).chain(
          CurveTween(curve: const Interval(0.0, 1.0 / 1.5)),
        ),
      );
    }
  }

  @override
  void didUpdateWidget(covariant PlatformHeader oldWidget) {
    _scrollPosition = Scrollable.of(context).position;
    super.didUpdateWidget(oldWidget);
  }

  // ─── Offset change ──────────────────────────────────
  @override
  void onOffsetChange(double offset) {
    if (_isApple) {
      _handleCupertinoOffset(offset);
    } else {
      _handleMaterialOffset(offset);
    }
  }

  void _handleCupertinoOffset(double offset) {
    if (!floating) {
      final double triggerDistance =
          configuration?.headerTriggerDistance ?? 80.0;
      final double progress = (offset / triggerDistance).clamp(0.0, 1.0);

      setState(() {
        _cupertinoOpacity = progress;
        // Tick marks appear gradually — simulate the native "winding" effect
        _cupertinoTickProgress = progress;
      });
    }
  }

  void _handleMaterialOffset(double offset) {
    if (!floating) {
      final double triggerDistance =
          configuration?.headerTriggerDistance ?? 80.0;
      _materialValueAni.value = offset / triggerDistance;
      _materialPositionController.value = offset / triggerDistance;
    }
  }

  // ─── Mode change ────────────────────────────────────
  @override
  void onModeChange(RefreshStatus? mode) {
    if (_isApple) {
      if (mode == RefreshStatus.refreshing ||
          mode == RefreshStatus.canRefresh) {
        setState(() {
          _cupertinoOpacity = 1.0;
        });
      }
    } else {
      if (mode == RefreshStatus.refreshing) {
        _materialPositionController.value = widget.distance / widget.height;
        _materialScaleFactor.value = 1;
      }
    }
    super.onModeChange(mode);
  }

  // ─── Ready to refresh ──────────────────────────────
  @override
  Future<void> readyToRefresh() {
    if (_isApple) {
      // iOS: instant — no animation needed, just start spinning
      return Future.value();
    }
    return _materialPositionController
        .animateTo(widget.distance / widget.height);
  }

  // ─── End refresh ────────────────────────────────────
  @override
  Future<void> endRefresh() {
    if (_isApple) {
      // iOS: fade out naturally
      return Future.value();
    }
    return _materialScaleFactor.animateTo(0.0);
  }

  // ─── Reset ──────────────────────────────────────────
  @override
  void resetValue() {
    if (_isApple) {
      _cupertinoOpacity = 0.0;
      _cupertinoTickProgress = 0.0;
    } else {
      _materialScaleFactor.value = 1.0;
      _materialPositionController.value = 0.0;
      _materialValueAni.value = 0.0;
    }
    super.resetValue();
  }

  // ─── Build ──────────────────────────────────────────
  @override
  Widget buildContent(BuildContext context, RefreshStatus? mode) {
    if (_isApple) {
      return _buildCupertinoContent(mode);
    }
    return _buildMaterialContent(context);
  }

  // ─── iOS: Cupertino-style spinner ───────────────────
  // Matches native CupertinoSliverRefreshControl:
  // - During drag: partially revealed spinner (opacity + partial ticks)
  // - During refresh: fully spinning
  Widget _buildCupertinoContent(RefreshStatus? mode) {
    final bool isRefreshing = mode == RefreshStatus.refreshing ||
        mode == RefreshStatus.completed ||
        mode == RefreshStatus.failed;

    return SizedBox(
      height: widget.height,
      child: Center(
        child: Opacity(
          opacity: _cupertinoOpacity.clamp(0.0, 1.0),
          child: isRefreshing
              ? const CupertinoActivityIndicator(radius: 14)
              : CupertinoActivityIndicator.partiallyRevealed(
                  radius: 14,
                  progress: _cupertinoTickProgress,
                ),
        ),
      ),
    );
  }

  // ─── Android: Material-style indicator ──────────────
  Widget _buildMaterialContent(BuildContext context) {
    return SlideTransition(
      position: _materialPositionFactor!,
      child: ScaleTransition(
        scale: _materialScaleFactor,
        child: Align(
          alignment: Alignment.topCenter,
          child: RefreshProgressIndicator(
            semanticsLabel:
                MaterialLocalizations.of(context).refreshIndicatorSemanticLabel,
            value: floating ? null : _materialValueAni.value,
            valueColor: _materialValueColor,
            backgroundColor: widget.backgroundColor ?? Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (!_isApple) {
      _materialValueAni.dispose();
      _materialScaleFactor.dispose();
      _materialPositionController.dispose();
    }
    super.dispose();
  }
}

// ──────────────────────────────────────────────────────────────────────
// PlatformFooter — platform-adaptive footer
// ──────────────────────────────────────────────────────────────────────

/// A platform-adaptive load-more footer.
/// - **iOS**: Minimal text + CupertinoActivityIndicator
/// - **Android**: Material CircularProgressIndicator
///
/// ```dart
/// SmartScroll(
///   footer: const PlatformFooter(),
///   // ...
/// )
/// ```
class PlatformFooter extends LoadIndicator {
  const PlatformFooter({
    super.key,
    super.height = 60.0,
    super.onClick,
    super.loadStyle = LoadStyle.ShowAlways,
    this.idleText,
    this.loadingText,
    this.noMoreText,
    this.failedText,
    this.color,
  });

  final String? idleText;
  final String? loadingText;
  final String? noMoreText;
  final String? failedText;
  final Color? color;

  @override
  State<StatefulWidget> createState() => _PlatformFooterState();
}

class _PlatformFooterState extends LoadIndicatorState<PlatformFooter> {
  bool get _isApple => _isApplePlatform();

  @override
  Widget buildContent(BuildContext context, LoadStatus? mode) {
    return _isApple
        ? _buildCupertinoFooter(context, mode)
        : _buildMaterialFooter(context, mode);
  }

  // ─── iOS: Clean, minimal — spinner only, no text ───
  Widget _buildCupertinoFooter(BuildContext context, LoadStatus? mode) {
    final Color secondaryColor =
        CupertinoColors.secondaryLabel.resolveFrom(context);

    Widget body;
    switch (mode) {
      case LoadStatus.loading:
        body = const CupertinoActivityIndicator(radius: 10);
        break;
      case LoadStatus.noMore:
        body = Text(
          widget.noMoreText ?? '— No more —',
          style: TextStyle(
            color: widget.color ?? secondaryColor,
            fontSize: 13,
          ),
        );
        break;
      case LoadStatus.failed:
        body = Text(
          widget.failedText ?? 'Tap to retry',
          style: TextStyle(
            color: widget.color ?? secondaryColor,
            fontSize: 13,
          ),
        );
        break;
      case LoadStatus.idle:
      default:
        // iOS native: nothing visible when idle
        body = const SizedBox.shrink();
        break;
    }

    return SizedBox(
      height: widget.height,
      child: Center(child: body),
    );
  }

  // ─── Android: Material style with text labels ───
  Widget _buildMaterialFooter(BuildContext context, LoadStatus? mode) {
    final Color textColor = widget.color ?? Colors.grey.shade600;
    final TextStyle style = TextStyle(color: textColor, fontSize: 14);

    Widget body;
    switch (mode) {
      case LoadStatus.loading:
        body = Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(textColor),
              ),
            ),
            const SizedBox(width: 10),
            Text(widget.loadingText ?? 'Loading...', style: style),
          ],
        );
        break;
      case LoadStatus.noMore:
        body = Text(widget.noMoreText ?? 'No more data', style: style);
        break;
      case LoadStatus.failed:
        body = Text(widget.failedText ?? 'Load failed, tap to retry',
            style: style);
        break;
      case LoadStatus.idle:
      default:
        body = Text(widget.idleText ?? 'Pull up to load more', style: style);
        break;
    }

    return SizedBox(
      height: widget.height,
      child: Center(child: body),
    );
  }
}
