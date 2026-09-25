import 'package:flutter/material.dart';

import 'profile_screen.dart';

/// Compatibility route kept for older navigation/tests. Account information
/// now lives inside Settings > Profile so there is only one user-facing
/// account surface.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) => const ProfileScreen();
}
