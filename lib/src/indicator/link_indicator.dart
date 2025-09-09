import 'package:flutter/widgets.dart';
import 'package:smart_scroll/smart_scroll.dart';

/// enable header link other header place outside the viewport
class LinkHeader extends RefreshIndicator {
  const LinkHeader(
      {super.key,
      required this.linkKey,
      super.height = 0.0,
      super.refreshStyle = null,
      super.completeDuration = const Duration(milliseconds: 200)});

  /// the key that widget outside viewport indicator
  final Key linkKey;

  @override
  State<StatefulWidget> createState() {
    return _LinkHeaderState();
  }
}

class _LinkHeaderState extends RefreshIndicatorState<LinkHeader> {
  @override
  void resetValue() {
    ((widget.linkKey as GlobalKey).currentState as RefreshProcessor)
        .resetValue();
  }

  @override
  Future<void> endRefresh() {
    return ((widget.linkKey as GlobalKey).currentState as RefreshProcessor)
        .endRefresh();
  }

  @override
  void onModeChange(RefreshStatus? mode) {
    ((widget.linkKey as GlobalKey).currentState as RefreshProcessor)
        .onModeChange(mode);
  }

  @override
  void onOffsetChange(double offset) {
    ((widget.linkKey as GlobalKey).currentState as RefreshProcessor)
        .onOffsetChange(offset);
  }

  @override
  Future<void> readyToRefresh() {
    return ((widget.linkKey as GlobalKey).currentState as RefreshProcessor)
        .readyToRefresh();
  }

  @override
  Widget buildContent(BuildContext context, RefreshStatus? mode) {
    return Container();
  }
}

class LinkFooter extends LoadIndicator {
  const LinkFooter(
      {super.key, required this.linkKey, super.height = 0.0, super.loadStyle});
  final Key linkKey;

  @override
  State<StatefulWidget> createState() {
    return _LinkFooterState();
  }
}

class _LinkFooterState extends LoadIndicatorState<LinkFooter> {
  @override
  void onModeChange(LoadStatus? mode) {
    ((widget.linkKey as GlobalKey).currentState as LoadingProcessor)
        .onModeChange(mode);
  }

  @override
  void onOffsetChange(double offset) {
    ((widget.linkKey as GlobalKey).currentState as LoadingProcessor)
        .onOffsetChange(offset);
  }

  @override
  Widget buildContent(BuildContext context, LoadStatus? mode) {
    return Container();
  }
}
