// ignore_for_file: avoid_bool_literals_in_conditional_expressions

import 'dart:math' as math;

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/gestures.dart' show kMinFlingVelocity;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:smart_scroll/smart_scroll.dart';
import 'package:smart_scroll/src/internals/slivers.dart';

/// a scrollPhysics for config refresh scroll effect,enable viewport out of edge whatever physics it is
/// in [ClampingScrollPhysics], it doesn't allow to flip out of edge,but in RefreshPhysics,it will allow to do that,
/// by parent physics passing,it also can attach the different of iOS and Android different scroll effect
/// it also handles interception scrolling when refreshed, or when the second floor is open and closed.
/// with [SpringDescription] passing,you can custom spring back animate,the more paramter can be setting in [RefreshConfiguration]
///
/// see also:
///
/// * [RefreshConfiguration], a configuration for Controlling how SmartScroll widgets behave in a subtree
// ignore: MUST_BE_IMMUTABLE
class RefreshPhysics extends ScrollPhysics {
  final double? maxOverScrollExtent, maxUnderScrollExtent;
  final double? topHitBoundary, bottomHitBoundary;
  final SpringDescription? springDescription;
  final double? dragSpeedRatio;
  final bool? enableScrollWhenTwoLevel, enableScrollWhenRefreshCompleted;
  final RefreshController? controller;
  final int? updateFlag;

  /// Cached config values to avoid per-frame InheritedWidget lookup.
  /// Populated from RefreshConfiguration in _getScrollPhysics() and
  /// preserved through applyTo(). Safe because physics is recreated
  /// when config changes (via didChangeDependencies).
  final bool enableLoadingWhenNoData;
  final bool hideFooterWhenNotFull;

  /// find out the viewport when bouncing,for compute the layoutExtent in header and footer
  /// This does not have any impact on performance. it only  execute once
  RenderViewport? viewportRender;

  /// Creates scroll physics that bounce back from the edge.
  RefreshPhysics(
      {super.parent,
      this.updateFlag,
      this.maxUnderScrollExtent,
      this.springDescription,
      this.controller,
      this.dragSpeedRatio,
      this.topHitBoundary,
      this.bottomHitBoundary,
      this.enableScrollWhenRefreshCompleted,
      this.enableScrollWhenTwoLevel,
      this.maxOverScrollExtent,
      this.enableLoadingWhenNoData = false,
      this.hideFooterWhenNotFull = false});

  @override
  RefreshPhysics applyTo(ScrollPhysics? ancestor) {
    final result = RefreshPhysics(
        parent: buildParent(ancestor),
        updateFlag: updateFlag,
        springDescription: springDescription,
        dragSpeedRatio: dragSpeedRatio,
        enableScrollWhenTwoLevel: enableScrollWhenTwoLevel,
        topHitBoundary: topHitBoundary,
        bottomHitBoundary: bottomHitBoundary,
        controller: controller,
        enableScrollWhenRefreshCompleted: enableScrollWhenRefreshCompleted,
        maxUnderScrollExtent: maxUnderScrollExtent,
        maxOverScrollExtent: maxOverScrollExtent,
        enableLoadingWhenNoData: enableLoadingWhenNoData,
        hideFooterWhenNotFull: hideFooterWhenNotFull);
    // Preserve cached viewport reference to avoid repeated tree traversal
    result.viewportRender = viewportRender;
    return result;
  }

  RenderViewport? findViewport(BuildContext? context) {
    if (context == null) {
      return null;
    }
    RenderViewport? result;
    context.visitChildElements((Element e) {
      // Skip remaining siblings once viewport is found
      if (result != null) return;
      final RenderObject? renderObject = e.findRenderObject();
      if (renderObject is RenderViewport) {
        result = renderObject;
      } else {
        result = findViewport(e);
      }
    });
    return result;
  }

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) {
    if (parent is NeverScrollableScrollPhysics) {
      return false;
    }
    return true;
  }

  // to detect physics changes. Flutter's ScrollableState compares
  // oldPhysics.runtimeType != newPhysics.runtimeType to decide whether to
  // recreate the ScrollPosition. By alternating between RefreshPhysics and
  // BouncingScrollPhysics types via updateFlag, we force ScrollPosition
  // updates when enablePullDown/enablePullUp state changes.
  //
  // WARNING: This breaks `is` operator checks, debugPrint, and reflection.
  // There is no clean alternative until Flutter exposes a `shouldUpdate()`
  // hook on ScrollPhysics. This pattern is also used by flutter_pulltorefresh
  // and easy_refresh libraries.
  @override
  Type get runtimeType {
    if (updateFlag == 0) {
      return RefreshPhysics;
    } else {
      return BouncingScrollPhysics;
    }
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    viewportRender ??=
        findViewport(controller!.position?.context.storageContext);
    final headerModeValue = controller!.headerMode!.value;
    if (headerModeValue == RefreshStatus.twoLeveling) {
      if (offset > 0.0) {
        return parent!.applyPhysicsToUserOffset(position, offset);
      }
    } else {
      if ((offset > 0.0 &&
              viewportRender?.firstChild is! RenderSliverRefresh) ||
          (offset < 0 && viewportRender?.lastChild is! RenderSliverLoading)) {
        return parent!.applyPhysicsToUserOffset(position, offset);
      }
    }
    if (position.outOfRange || headerModeValue == RefreshStatus.twoLeveling) {
      final double overScrollPastStart =
          math.max(position.minScrollExtent - position.pixels, 0.0);
      final double overScrollPastEnd = math.max(
          position.pixels -
              (headerModeValue == RefreshStatus.twoLeveling
                  ? 0.0
                  : position.maxScrollExtent),
          0.0);
      final double overScrollPast =
          math.max(overScrollPastStart, overScrollPastEnd);
      final bool easing = (overScrollPastStart > 0.0 && offset < 0.0) ||
          (overScrollPastEnd > 0.0 && offset > 0.0);

      final double friction = easing
          // Apply less resistance when easing the overscroll vs tensioning.
          ? frictionFactor(
              (overScrollPast - offset.abs()) / position.viewportDimension)
          : frictionFactor(overScrollPast / position.viewportDimension);
      final double direction = offset.sign;
      return direction *
          _applyFriction(overScrollPast, offset.abs(), friction) *
          (dragSpeedRatio ?? 1.0);
    }
    return super.applyPhysicsToUserOffset(position, offset);
  }

  static double _applyFriction(
      double extentOutside, double absDelta, double gamma) {
    assert(absDelta > 0);
    double total = 0.0;
    if (extentOutside > 0) {
      final double deltaToLimit = extentOutside / gamma;
      if (absDelta < deltaToLimit) {
        return absDelta * gamma;
      }
      total += extentOutside;
      absDelta -= deltaToLimit;
    }
    return total + absDelta;
  }

  double frictionFactor(double overScrollFraction) =>
      0.52 * math.pow(1 - overScrollFraction, 2);

  // ── Fling behavior overrides ──────────────────────────────────────
  // These ensure consistent scroll feel even though RefreshPhysics
  // sits in the physics chain with a runtimeType hack that can
  // break parent delegation.

  /// iOS momentum stacking: repeated quick flings accumulate speed.
  /// Without this override, the runtimeType hack can break the
  /// parent chain and lose momentum transfer between flings.
  ///
  /// Formula from Flutter's BouncingScrollPhysics — empirically
  /// calibrated against native iOS UIScrollView:
  ///   velocity_carry = sign * min(0.000816 * |v|^1.967, 40000)
  @override
  double carriedMomentum(double existingVelocity) {
    return existingVelocity.sign *
        math.min(
          0.000816 * math.pow(existingVelocity.abs(), 1.967).toDouble(),
          40000.0,
        );
  }

  /// Minimum velocity required to trigger a fling animation.
  /// BouncingScrollPhysics uses 2x the default to require more
  /// deliberate gestures (matching iOS feel).
  /// Explicit override prevents the runtimeType hack from
  /// accidentally falling back to the wrong threshold.
  @override
  double get minFlingVelocity {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        // iOS: higher threshold = more deliberate flings required
        return kMinFlingVelocity * 2.0;
      default:
        // Android/others: standard threshold
        return kMinFlingVelocity;
    }
  }

  /// Filters out unintentional scroll from natural finger-lift motion.
  /// 3.5 pixels is the iOS-calibrated threshold from BouncingScrollPhysics.
  @override
  double get dragStartDistanceMotionThreshold => 3.5;

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    final ScrollPosition scrollPosition = position as ScrollPosition;
    viewportRender ??=
        findViewport(controller!.position?.context.storageContext);
    final headerModeValue = controller!.headerMode!.value;
    final bool notFull = position.minScrollExtent == position.maxScrollExtent;
    final bool enablePullDown = viewportRender == null
        ? false
        : viewportRender!.firstChild is RenderSliverRefresh;
    final bool enablePullUp = viewportRender == null
        ? false
        : viewportRender!.lastChild is RenderSliverLoading;
    if (headerModeValue == RefreshStatus.twoLeveling) {
      if (position.pixels - value > 0.0) {
        return parent!.applyBoundaryConditions(position, value);
      }
    } else {
      if ((position.pixels - value > 0.0 && !enablePullDown) ||
          (position.pixels - value < 0 && !enablePullUp)) {
        return parent!.applyBoundaryConditions(position, value);
      }
    }
    double topExtra = 0.0;
    double? bottomExtra = 0.0;
    if (enablePullDown) {
      final RenderSliverRefresh sliverHeader =
          viewportRender!.firstChild as RenderSliverRefresh;
      topExtra = sliverHeader.hasLayoutExtent
          ? 0.0
          : sliverHeader.refreshIndicatorLayoutExtent;
    }
    if (enablePullUp) {
      final RenderSliverLoading? sliverFooter =
          viewportRender!.lastChild as RenderSliverLoading?;
      // Use cached config fields instead of per-frame InheritedWidget lookup
      bottomExtra = (!notFull && sliverFooter!.geometry!.scrollExtent != 0) ||
              (notFull &&
                  controller!.footerStatus == LoadStatus.noMore &&
                  !enableLoadingWhenNoData) ||
              (notFull && hideFooterWhenNotFull)
          ? 0.0
          : sliverFooter!.layoutExtent;
    }
    final double topBoundary =
        position.minScrollExtent - maxOverScrollExtent! - topExtra;
    final double bottomBoundary =
        position.maxScrollExtent + maxUnderScrollExtent! + bottomExtra!;

    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    if (scrollPosition.activity is BallisticScrollActivity) {
      if (topHitBoundary != double.infinity) {
        if (value < -topHitBoundary! && -topHitBoundary! <= position.pixels) {
          // hit top edge
          return value + topHitBoundary!;
        }
      }
      if (bottomHitBoundary != double.infinity) {
        if (position.pixels < bottomHitBoundary! + position.maxScrollExtent &&
            bottomHitBoundary! + position.maxScrollExtent < value) {
          // hit bottom edge
          return value - bottomHitBoundary! - position.maxScrollExtent;
        }
      }
    }
    if (maxOverScrollExtent != double.infinity &&
        value < topBoundary &&
        topBoundary < position.pixels) {
      // hit top edge
      return value - topBoundary;
    }
    if (maxUnderScrollExtent != double.infinity &&
        position.pixels < bottomBoundary &&
        bottomBoundary < value) {
      // hit bottom edge
      return value - bottomBoundary;
    }

    // check user is dragging,it is import,some devices may not bounce with different frame and time,bouncing return the different velocity
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    if (scrollPosition.activity is DragScrollActivity) {
      if (maxOverScrollExtent != double.infinity &&
          value < position.pixels &&
          position.pixels <= topBoundary) {
        return value - position.pixels;
      }
      if (maxUnderScrollExtent != double.infinity &&
          bottomBoundary <= position.pixels &&
          position.pixels < value) {
        return value - position.pixels;
      }
    }
    return 0.0;
  }

  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    viewportRender ??=
        findViewport(controller!.position?.context.storageContext);

    final bool enablePullDown = viewportRender == null
        ? false
        : viewportRender!.firstChild is RenderSliverRefresh;
    final bool enablePullUp = viewportRender == null
        ? false
        : viewportRender!.lastChild is RenderSliverLoading;
    final headerModeValue = controller!.headerMode!.value;
    if (headerModeValue == RefreshStatus.twoLeveling) {
      if (velocity < 0.0) {
        return parent!.createBallisticSimulation(position, velocity);
      }
    } else if (!position.outOfRange) {
      if ((velocity < 0.0 && !enablePullDown) ||
          (velocity > 0 && !enablePullUp)) {
        return parent!.createBallisticSimulation(position, velocity);
      }
    }
    if ((position.pixels > 0 && headerModeValue == RefreshStatus.twoLeveling) ||
        position.outOfRange) {
      return BouncingScrollSimulation(
        spring: springDescription ?? spring,
        position: position.pixels,
        // Dampen velocity by 0.91 to prevent abrupt spring-back stops
        // when the user releases a drag gesture near the overscroll edge.
        // Without this, BouncingScrollSimulation can settle prematurely.
        velocity: velocity * 0.91,
        leadingExtent: position.minScrollExtent,
        trailingExtent: headerModeValue == RefreshStatus.twoLeveling
            ? 0.0
            : position.maxScrollExtent,
        // ignore: deprecated_member_use
        tolerance: tolerance,
      );
    }
    return super.createBallisticSimulation(position, velocity);
  }
}
