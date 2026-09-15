import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/widgets/components.dart';
import '../../domain/entities/app_user.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider) ?? const AppUser(id: '', email: '');
    return PageScaffold(
      title: 'Account',
      onBack: () => Navigator.maybePop(context),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          AccountSection(
            user: user,
            onSignOut: () async {
              await ref.read(authRepositoryProvider).signOut();
              if (context.mounted) Navigator.maybePop(context);
            },
          ),
        ],
      ),
    );
  }
}
