// ignore_for_file: avoid_bool_literals_in_conditional_expressions

import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../smart_refresher.dart';
import 'slivers.dart';

typedef VoidFutureCallBack = Future<void> Function();

typedef OffsetCallBack = void Function(double offset);

typedef ModeChangeCallBack<T> = void Function(T? mode);

/// a widget  implements ios pull down refresh effect and Android material RefreshIndicator overScroll effect
abstract class RefreshIndicator extends StatefulWidget {
  const RefreshIndicator(
      {super.key,
      this.height = 60.0,
      this.offset = 0.0,
      this.completeDuration = const Duration(milliseconds: 500),
      this.refreshStyle = RefreshStyle.Follow});

  /// refresh display style
  final RefreshStyle? refreshStyle;

  /// the visual extent indicator
  final double height;

  //layout offset
  final double offset;

  /// the stopped time when refresh complete or fail
  final Duration completeDuration;
}

/// a widget  implements  pull up load
abstract class LoadIndicator extends StatefulWidget {
  const LoadIndicator(
      {super.key,
      this.onClick,
      this.loadStyle = LoadStyle.ShowAlways,
      this.height = 60.0});

  /// load more display style
  final LoadStyle loadStyle;

  /// the visual extent indicator
  final double height;

  /// callback when user click footer
  final VoidCallback? onClick;
}

abstract class RefreshIndicatorState<T extends RefreshIndicator>
    extends State<T>
    with IndicatorStateMixin<T, RefreshStatus>, RefreshProcessor {
  bool _inVisual() {
    return _position!.pixels < 0.0;
  }

  @override
  double _calculateScrollOffset() {
    return (floating
            ? (mode == RefreshStatus.twoLeveling ||
                    mode == RefreshStatus.twoLevelOpening ||
                    mode == RefreshStatus.twoLevelClosing
                ? refresherState!.viewportExtent
                : widget.height)
            : 0.0) -
        (_position?.pixels as num);
  }

  @override
  void _handleOffsetChange() {
    super._handleOffsetChange();
    final double oversSrollPast = _calculateScrollOffset();
    onOffsetChange(oversSrollPast);
  }

  // handle the  state change between canRefresh and idle canRefresh  before refreshing
  @override
  void _dispatchModeByOffset(double offset) {
    if (mode == RefreshStatus.twoLeveling) {
      if (_position!.pixels > configuration!.closeTwoLevelDistance &&
          activity is BallisticScrollActivity) {
        refresher!.controller.twoLevelComplete();
        return;
      }
    }
    if (RefreshStatus.twoLevelOpening == mode ||
        mode == RefreshStatus.twoLevelClosing) {
      return;
    }
    if (floating) {
      return;
    }
    // no matter what activity is done, when offset ==0.0 and !floating,it should be set to idle for setting ifCanDrag
    if (offset == 0.0) {
      mode = RefreshStatus.idle;
    }

    // If FrontStyle overScroll,it shouldn't disable gesture in scrollable
    if (_position!.extentBefore == 0.0 &&
        widget.refreshStyle == RefreshStyle.Front) {
      _position!.context.setIgnorePointer(false);
    }
    // Sometimes different devices return velocity differently, so it's impossible to judge from velocity whether the user
    // has invoked animateTo (0.0) or the user is dragging the view.Sometimes animateTo (0.0) does not return velocity = 0.0
    // velocity < 0.0 may be spring up,>0.0 spring down
    if ((configuration!.enableBallisticRefresh && activity!.velocity < 0.0) ||
        activity is DragScrollActivity ||
        activity is DrivenScrollActivity) {
      if (refresher!.enablePullDown &&
          offset >= configuration!.headerTriggerDistance) {
        if (!configuration!.skipCanRefresh) {
          mode = RefreshStatus.canRefresh;
        } else {
          floating = true;
          update();
          readyToRefresh().then((_) {
            if (!mounted) {
              return;
            }
            mode = RefreshStatus.refreshing;
          });
        }
      } else if (refresher!.enablePullDown) {
        mode = RefreshStatus.idle;
      }
      if (refresher!.enableTwoLevel &&
          offset >= configuration!.twiceTriggerDistance) {
        mode = RefreshStatus.canTwoLevel;
      } else if (refresher!.enableTwoLevel && !refresher!.enablePullDown) {
        mode = RefreshStatus.idle;
      }
    }
    //mostly for spring back
    else if (activity is BallisticScrollActivity) {
      if (RefreshStatus.canRefresh == mode) {
        // refreshing
        floating = true;
        update();
        readyToRefresh().then((_) {
          if (!mounted) {
            return;
          }
          mode = RefreshStatus.refreshing;
        });
      }
      if (mode == RefreshStatus.canTwoLevel) {
        // enter twoLevel
        floating = true;
        update();
        if (!mounted) {
          return;
        }

        mode = RefreshStatus.twoLevelOpening;
      }
    }
  }

  @override
  void _handleModeChange() {
    if (!mounted) {
      return;
    }
    update();
    if (mode == RefreshStatus.idle || mode == RefreshStatus.canRefresh) {
      floating = false;

      resetValue();

      if (mode == RefreshStatus.idle) {
        refresherState!.setCanDrag(true);
      }
    }
    if (mode == RefreshStatus.completed || mode == RefreshStatus.failed) {
      endRefresh().then((_) {
        if (!mounted) {
          return;
        }
        floating = false;
        if (mode == RefreshStatus.completed || mode == RefreshStatus.failed) {
          refresherState!
              .setCanDrag(configuration!.enableScrollWhenRefreshCompleted);
        }
        update();
        /*
          handle two Situation:
          1.when user dragging to refreshing, then user scroll down not to see the indicator,then it will not spring back,
          the _onOffsetChange didn't callback,it will keep failed or success state.
          2. As FrontStyle,when user dragging in 0~100 in refreshing state,it should be reset after the state change
          */
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          if (widget.refreshStyle == RefreshStyle.Front) {
            if (_inVisual()) {
              _position!.jumpTo(0.0);
            }
            mode = RefreshStatus.idle;
          } else {
            if (!_inVisual()) {
              mode = RefreshStatus.idle;
            } else {
              activity!.delegate.goBallistic(0.0);
            }
          }
        });
      });
    } else if (mode == RefreshStatus.refreshing) {
      if (!floating) {
        floating = true;
        readyToRefresh();
      }
      if (configuration!.enableRefreshVibrate) {
        HapticFeedback.vibrate();
      }
      if (refresher!.onRefresh != null) {
        refresher!.onRefresh!();
      }
    } else if (mode == RefreshStatus.twoLevelOpening) {
      floating = true;
      refresherState!.setCanDrag(false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        activity!.resetActivity();
        _position!
            .animateTo(0.0,
                duration: const Duration(milliseconds: 500),
                curve: Curves.linear)
            .whenComplete(() {
          mode = RefreshStatus.twoLeveling;
        });
        if (refresher!.onTwoLevel != null) {
          refresher!.onTwoLevel!(true);
        }
      });
    } else if (mode == RefreshStatus.twoLevelClosing) {
      floating = false;
      refresherState!.setCanDrag(false);
      update();
      if (refresher!.onTwoLevel != null) {
        refresher!.onTwoLevel!(false);
      }
    } else if (mode == RefreshStatus.twoLeveling) {
      refresherState!.setCanDrag(configuration!.enableScrollWhenTwoLevel);
    }
    onModeChange(mode);
  }

  // the method can provide a callback to implements some animation
  @override
  Future<void> readyToRefresh() {
    return Future.value();
  }

  // it mean the state will enter success or fail
  @override
  Future<void> endRefresh() {
    return Future.delayed(widget.completeDuration);
  }

  bool needReverseAll() {
    return true;
  }

  @override
  void resetValue() {}

  @override
  Widget build(BuildContext context) {
    return SliverRefresh(
        paintOffsetY: widget.offset,
        floating: floating,
        refreshIndicatorLayoutExtent: mode == RefreshStatus.twoLeveling ||
                mode == RefreshStatus.twoLevelOpening ||
                mode == RefreshStatus.twoLevelClosing
            ? refresherState!.viewportExtent
            : widget.height,
        refreshStyle: widget.refreshStyle,
        child: RotatedBox(
          quarterTurns: needReverseAll() &&
                  Scrollable.of(context).axisDirection == AxisDirection.up
              ? 10
              : 0,
          child: buildContent(context, mode),
        ));
  }
}

abstract class LoadIndicatorState<T extends LoadIndicator> extends State<T>
    with IndicatorStateMixin<T, LoadStatus>, LoadingProcessor {
  // use to update between one page and above one page
  bool _isHide = false;
  bool _enableLoading = false;
  LoadStatus? _lastMode = LoadStatus.idle;

  @override
  double _calculateScrollOffset() {
    final double oversSrollPastEnd =
        math.max(_position!.pixels - _position!.maxScrollExtent, 0.0);
    return oversSrollPastEnd;
  }

  void enterLoading() {
    setState(() {
      floating = true;
    });
    _enableLoading = false;
    readyToLoad().then((_) {
      if (!mounted) {
        return;
      }
      mode = LoadStatus.loading;
    });
  }

  @override
  Future endLoading() {
    return Future.delayed(const Duration(milliseconds: 0));
  }

  void finishLoading() {
    if (!floating) {
      return;
    }
    endLoading().then((_) {
      if (!mounted) {
        return;
      }

      // this line for patch bug temporary:indicator disappears fastly when load more complete
      if (mounted) {
        Scrollable.of(context).position.correctBy(0.00001);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _position?.outOfRange == true) {
          activity!.delegate.goBallistic(0);
        }
      });
      setState(() {
        floating = false;
      });
    });
  }

  bool _checkIfCanLoading() {
    if (_position!.maxScrollExtent - _position!.pixels <=
            configuration!.footerTriggerDistance &&
        _position!.extentBefore > 2.0 &&
        _enableLoading) {
      if (!configuration!.enableLoadingWhenFailed &&
          mode == LoadStatus.failed) {
        return false;
      }
      if (!configuration!.enableLoadingWhenNoData &&
          mode == LoadStatus.noMore) {
        return false;
      }
      if (mode != LoadStatus.canLoading &&
          _position!.userScrollDirection == ScrollDirection.forward) {
        return false;
      }
      return true;
    }
    return false;
  }

  @override
  void _handleModeChange() {
    if (!mounted || _isHide) {
      return;
    }

    update();
    if (mode == LoadStatus.idle ||
        mode == LoadStatus.failed ||
        mode == LoadStatus.noMore) {
      // #292,#265,#208
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      if (_position!.activity!.velocity < 0 &&
          _lastMode == LoadStatus.loading &&
          !_position!.outOfRange &&
          _position is ScrollActivityDelegate) {
        _position!.beginActivity(
            IdleScrollActivity(_position as ScrollActivityDelegate));
      }

      finishLoading();
    }
    if (mode == LoadStatus.loading) {
      if (!floating) {
        enterLoading();
      }
      if (configuration!.enableLoadMoreVibrate) {
        HapticFeedback.vibrate();
      }
      if (refresher!.onLoading != null) {
        refresher!.onLoading!();
      }
      if (widget.loadStyle == LoadStyle.ShowWhenLoading) {
        floating = true;
      }
    } else {
      if (activity is! DragScrollActivity) {
        _enableLoading = false;
      }
    }
    _lastMode = mode;
    onModeChange(mode);
  }

  @override
  void _dispatchModeByOffset(double offset) {
    if (!mounted || _isHide || LoadStatus.loading == mode || floating) {
      return;
    }
    if (activity is DragScrollActivity) {
      if (_checkIfCanLoading()) {
        mode = LoadStatus.canLoading;
      } else {
        mode = _lastMode;
      }
    }
    if (activity is BallisticScrollActivity) {
      if (configuration!.enableBallisticLoad) {
        if (_checkIfCanLoading()) {
          enterLoading();
        }
      } else if (mode == LoadStatus.canLoading) {
        enterLoading();
      }
    }
  }

  @override
  void _handleOffsetChange() {
    if (_isHide) {
      return;
    }
    super._handleOffsetChange();
    final double oversSrollPast = _calculateScrollOffset();
    onOffsetChange(oversSrollPast);
  }

  void _listenScrollEnd() {
    if (!_position!.isScrollingNotifier.value) {
      // when user release gesture from screen
      if (_isHide || mode == LoadStatus.loading || mode == LoadStatus.noMore) {
        return;
      }

      if (_checkIfCanLoading()) {
        if (activity is IdleScrollActivity) {
          if ((configuration!.enableBallisticLoad) ||
              ((!configuration!.enableBallisticLoad) &&
                  mode == LoadStatus.canLoading)) {
            enterLoading();
          }
        }
      }
    } else {
      if (activity is DragScrollActivity || activity is DrivenScrollActivity) {
        _enableLoading = true;
      }
    }
  }

  @override
  void _onPositionUpdated(ScrollPosition newPosition) {
    _position?.isScrollingNotifier.removeListener(_listenScrollEnd);
    newPosition.isScrollingNotifier.addListener(_listenScrollEnd);
    super._onPositionUpdated(newPosition);
  }

  @override
  void didChangeDependencies() {
    // TODO: implement didChangeDependencies
    super.didChangeDependencies();
    _lastMode = mode;
  }

  @override
  void dispose() {
    _position?.isScrollingNotifier.removeListener(_listenScrollEnd);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SliverLoading(
        hideWhenNotFull: configuration!.hideFooterWhenNotFull,
        floating: widget.loadStyle == LoadStyle.ShowAlways
            ? true
            : widget.loadStyle == LoadStyle.HideAlways
                ? false
                : floating,
        shouldFollowContent:
            configuration!.shouldFooterFollowWhenNotFull != null
                ? configuration!.shouldFooterFollowWhenNotFull!(mode)
                : mode == LoadStatus.noMore,
        layoutExtent: widget.height,
        mode: mode,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints cons) {
            _isHide = cons.biggest.height == 0.0;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (widget.onClick != null) {
                  widget.onClick!();
                }
              },
              child: buildContent(context, mode),
            );
          },
        ));
  }
}

/// mixin in IndicatorState,it will get position and remove when dispose,init mode state
///
/// help to finish the work that the header indicator and footer indicator need to do
mixin IndicatorStateMixin<T extends StatefulWidget, V> on State<T> {
  SmartScroll? refresher;

  RefreshConfiguration? configuration;
  SmartScrollState? refresherState;

  bool _floating = false;

  set floating(floating) => _floating = floating;

  bool get floating => _floating;

  set mode(mode) => _mode?.value = mode;

  get mode => _mode?.value;

  RefreshNotifier<V?>? _mode;

  // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
  ScrollActivity? get activity => _position!.activity;

  // it doesn't support get the ScrollController as the listener, because it will cause "multiple scrollview use one ScrollController"
  // error,only replace the ScrollPosition to listen the offset
  ScrollPosition? _position;

  // update ui
  void update() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleOffsetChange() {
    if (!mounted) {
      return;
    }
    final double oversSrollPast = _calculateScrollOffset();
    if (oversSrollPast < 0.0) {
      return;
    }
    _dispatchModeByOffset(oversSrollPast);
  }

  void disposeListener() {
    _mode?.removeListener(_handleModeChange);
    _position?.removeListener(_handleOffsetChange);
    _position = null;
    _mode = null;
  }

  void _updateListener() {
    configuration = RefreshConfiguration.of(context);
    refresher = SmartScroll.of(context);
    refresherState = SmartScroll.ofState(context);
    final RefreshNotifier<V>? newMode = V == RefreshStatus
        ? refresher!.controller.headerMode as RefreshNotifier<V>?
        : refresher!.controller.footerMode as RefreshNotifier<V>?;
    final ScrollPosition newPosition = Scrollable.of(context).position;
    if (newMode != _mode) {
      _mode?.removeListener(_handleModeChange);
      _mode = newMode;
      _mode?.addListener(_handleModeChange);
    }
    if (newPosition != _position) {
      _position?.removeListener(_handleOffsetChange);
      _onPositionUpdated(newPosition);
      _position = newPosition;
      _position?.addListener(_handleOffsetChange);
    }
  }

  @override
  void initState() {
    if (V == RefreshStatus) {
      SmartScroll.of(context)?.controller.headerMode?.value =
          RefreshStatus.idle;
    }
    super.initState();
  }

  @override
  void dispose() {
    //1.3.7: here need to careful after add asSliver builder
    disposeListener();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    _updateListener();
    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(T oldWidget) {
    // needn't to update _headerMode,because it's state will never change
    // 1.3.7: here need to careful after add asSliver builder
    _updateListener();
    super.didUpdateWidget(oldWidget);
  }

  void _onPositionUpdated(ScrollPosition newPosition) {
    refresher!.controller.onPositionUpdated(newPosition);
  }

  void _handleModeChange();

  double _calculateScrollOffset();

  void _dispatchModeByOffset(double offset);

  Widget buildContent(BuildContext context, V mode);
}

/// head Indicator exposure interface
mixin RefreshProcessor {
  /// out of edge offset callback
  void onOffsetChange(double offset) {}

  /// mode change callback
  void onModeChange(RefreshStatus? mode) {}

  /// when indicator is ready into refresh,it will call back and waiting for this function finish,then callback onRefresh
  Future readyToRefresh() {
    return Future.value();
  }

  // when indicator is ready to dismiss layout ,it will callback and then spring back after finish
  Future endRefresh() {
    return Future.value();
  }

  // when indicator has been spring back,it  need to reset value
  void resetValue() {}
}

/// footer Indicator exposure interface
mixin LoadingProcessor {
  void onOffsetChange(double offset) {}

  void onModeChange(LoadStatus? mode) {}

  /// when indicator is ready into refresh,it will call back and waiting for this function finish,then callback onRefresh
  Future readyToLoad() {
    return Future.value();
  }

  // when indicator is ready to dismiss layout ,it will callback and then spring back after finish
  Future endLoading() {
    return Future.value();
  }

  // when indicator has been spring back,it  need to reset value
  void resetValue() {}
}
