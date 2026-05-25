import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

void handleBackOrFallback(BuildContext context, String fallbackRoute) {
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop();
    return;
  }
  context.go(fallbackRoute);
}

class BackNavigationScope extends StatelessWidget {
  const BackNavigationScope({
    super.key,
    required this.fallbackRoute,
    required this.child,
  });

  final String fallbackRoute;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !context.mounted) return;
        handleBackOrFallback(context, fallbackRoute);
      },
      child: child,
    );
  }
}
