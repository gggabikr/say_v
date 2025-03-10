import 'package:flutter/material.dart';

class ScrollToTop extends StatefulWidget {
  final ScrollController scrollController;
  final double showThreshold;

  const ScrollToTop({
    Key? key,
    required this.scrollController,
    this.showThreshold = 300.0, // 기본값 300
  }) : super(key: key);

  @override
  State<ScrollToTop> createState() => _ScrollToTopState();
}

class _ScrollToTopState extends State<ScrollToTop> {
  bool _showButton = false;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_scrollListener);
    super.dispose();
  }

  void _scrollListener() {
    final showButton = widget.scrollController.offset >= widget.showThreshold;
    if (showButton != _showButton) {
      setState(() {
        _showButton = showButton;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _showButton ? 0.6 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: Visibility(
        visible: _showButton,
        maintainState: false,
        maintainAnimation: false,
        maintainSize: false,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16.0),
          child: FloatingActionButton.small(
            onPressed: _showButton
                ? () {
                    widget.scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                    );
                  }
                : null,
            backgroundColor: Colors.black45,
            child: const Icon(
              Icons.keyboard_arrow_up,
              color: Colors.white70,
            ),
          ),
        ),
      ),
    );
  }
}
