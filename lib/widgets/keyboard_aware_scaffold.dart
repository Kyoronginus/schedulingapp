import 'package:flutter/material.dart';

/// A scaffold that automatically handles keyboard appearance by adjusting content
/// to prevent bottom overflow and provide smooth user experience
class KeyboardAwareScaffold extends StatefulWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Color? backgroundColor;
  final bool resizeToAvoidBottomInset;
  final EdgeInsetsGeometry? padding;
  final Duration animationDuration;

  const KeyboardAwareScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.backgroundColor,
    this.resizeToAvoidBottomInset = true,
    this.padding,
    this.animationDuration = const Duration(milliseconds: 300),
  });

  @override
  State<KeyboardAwareScaffold> createState() => _KeyboardAwareScaffoldState();
}

class _KeyboardAwareScaffoldState extends State<KeyboardAwareScaffold>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  double _keyboardHeight = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final keyboardHeight = mediaQuery.viewInsets.bottom;

    // Animate keyboard changes
    if (keyboardHeight != _keyboardHeight) {
      _keyboardHeight = keyboardHeight;
      if (keyboardHeight > 0) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }

    return Scaffold(
      appBar: widget.appBar,
      backgroundColor: widget.backgroundColor,
      resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
      floatingActionButton: widget.floatingActionButton,
      floatingActionButtonLocation: widget.floatingActionButtonLocation,
      body: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: widget.padding ?? EdgeInsets.zero,
                        child: widget.body,
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      bottomNavigationBar: widget.bottomNavigationBar,
    );
  }
}

/// A form wrapper that provides keyboard-aware scrolling for forms with input fields
class KeyboardAwareForm extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;

  const KeyboardAwareForm({
    super.key,
    required this.child,
    this.padding,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: physics ?? const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: IntrinsicHeight(
              child: Padding(
                padding: padding ?? const EdgeInsets.all(16.0),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
