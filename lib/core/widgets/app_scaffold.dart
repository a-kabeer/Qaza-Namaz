import 'package:flutter/material.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.onBack,
    this.actions = const <Widget>[],
    this.floatingActionButton,
  });

  final String title;
  final Widget body;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        automaticallyImplyLeading: onBack == null,
        leading: onBack == null
            ? null
            : IconButton(
                tooltip: 'Back',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
        actions: actions,
      ),
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}

class AppSpacing {
  const AppSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;

  /// Room a scrollable must leave at its bottom so a floating action button
  /// does not cover its last item.
  ///
  /// The workspace FAB is 56dp tall with a 16dp margin; the extra 16dp keeps
  /// the last row clear of it rather than flush against it.
  static const fabClearance = 88.0;
}

class AppRadius {
  const AppRadius._();

  static const sm = 10.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const pill = 999.0;
}
