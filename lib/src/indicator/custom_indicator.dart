import 'package:flutter/widgets.dart';
import '../internals/indicator_wrap.dart';
import '../smart_refresher.dart';

typedef HeaderBuilder = Widget Function(
    BuildContext context, RefreshStatus? mode);

typedef FooterBuilder = Widget Function(BuildContext context, LoadStatus? mode);

/// a custom Indicator for header
///
/// here is the very simple usage
///
/// ```dart
/// CustomHeader(
///      builder: (context,mode){
///        Widget body;
///        if(mode==RefreshStatus.idle){
///          body = Text("pull down refresh");
///        }
///       else if(mode==RefreshStatus.refreshing){
///          body = CupertinoActivityIndicator();
///        }
///        else if(mode==RefreshStatus.canRefresh){
///          body = Text("release to refresh");
///        }
///        else if(mode==RefreshStatus.completed){
///          body = Text("refreshCompleted!");
///       }
///        return Container(
///          height: 60.0,
///          child: Center(
///            child: body,
///          ),
///       );
///      },
///    )
/// ```
/// If you need to listen overScroll event do some animate,you should use [OnOffsetChange] callback in [SmartScroll]
/// finally,If your indicator contain more complex animation and need to update frequently ,I suggest you extends [RefreshIndicator] to implements
///
/// See also
///
/// [CustomFooter], a custom Indicator for footer
class CustomHeader extends RefreshIndicator {
  const CustomHeader({
    super.key,
    required this.builder,
    this.readyToRefresh,
    this.endRefresh,
    this.onOffsetChange,
    this.onModeChange,
    this.onResetValue,
    super.height,
    super.completeDuration = const Duration(milliseconds: 600),
    RefreshStyle super.refreshStyle,
  });
  final HeaderBuilder builder;

  final VoidFutureCallBack? readyToRefresh;

  final VoidFutureCallBack? endRefresh;

  final OffsetCallBack? onOffsetChange;

  final ModeChangeCallBack<RefreshStatus>? onModeChange;

  final VoidCallback? onResetValue;

  @override
  State<StatefulWidget> createState() {
    return _CustomHeaderState();
  }
}

class _CustomHeaderState extends RefreshIndicatorState<CustomHeader> {
  @override
  void onOffsetChange(double offset) {
    if (widget.onOffsetChange != null) {
      widget.onOffsetChange!(offset);
    }
    super.onOffsetChange(offset);
  }

  @override
  void onModeChange(RefreshStatus? mode) {
    if (widget.onModeChange != null) {
      widget.onModeChange!(mode);
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
  Widget buildContent(BuildContext context, RefreshStatus? mode) {
    return widget.builder(context, mode);
  }
}

/// a custom Indicator for footer,the usage I have put in [CustomHeader],same with that
/// See also
///
/// [CustomHeader], a custom Indicator for header
class CustomFooter extends LoadIndicator {
  const CustomFooter({
    super.key,
    super.height,
    this.onModeChange,
    this.onOffsetChange,
    this.readyLoading,
    this.endLoading,
    super.loadStyle,
    required this.builder,
    Function? onClick,
  }) : super(onClick: onClick as void Function()?);
  final FooterBuilder builder;

  final OffsetCallBack? onOffsetChange;

  final ModeChangeCallBack? onModeChange;

  final VoidFutureCallBack? readyLoading;

  final VoidFutureCallBack? endLoading;

  @override
  State<StatefulWidget> createState() {
    return _CustomFooterState();
  }
}

class _CustomFooterState extends LoadIndicatorState<CustomFooter> {
  @override
  void onOffsetChange(double offset) {
    if (widget.onOffsetChange != null) {
      widget.onOffsetChange!(offset);
    }
    super.onOffsetChange(offset);
  }

  @override
  void onModeChange(LoadStatus? mode) {
    if (widget.onModeChange != null) {
      widget.onModeChange!(mode);
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
    return widget.builder(context, mode);
  }
}
