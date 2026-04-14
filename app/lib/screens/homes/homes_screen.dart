import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_theme.dart';
import '../../providers/homes_provider.dart';
import '../../widgets/async_value_widget.dart';

class HomesScreen extends ConsumerWidget {
  const HomesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final homes = ref.watch(homesProvider);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: Text('My Homes', style: TextStyle(color: c.textPrimary)),
        backgroundColor: c.bg,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(homesProvider.future),
        child: AsyncValueWidget(
          value: homes,
          data: (homeList) => homeList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.home_outlined,
                          size: 64, color: c.textSecondary),
                      const SizedBox(height: 12),
                      Text('No homes yet',
                          style: TextStyle(color: c.textSecondary)),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: () => context.push('/homes/create'),
                        icon: const Icon(Icons.add),
                        label: const Text('Create Home'),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: homeList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final home = homeList[i];
                    return ListTile(
                      tileColor: c.surface,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      leading: const Icon(Icons.home, color: AppColors.primary),
                      title: Text(home.name,
                          style: TextStyle(color: c.textPrimary)),
                      subtitle: home.address != null
                          ? Text(home.address!,
                              style: TextStyle(color: c.textSecondary))
                          : null,
                      trailing: Icon(Icons.chevron_right,
                          color: c.textSecondary),
                      onTap: () => context.push('/homes/${home.id}'),
                    );
                  },
                ),
        ),
      ),
      floatingActionButton: homes.valueOrNull?.isNotEmpty == true
          ? FloatingActionButton(
              onPressed: () => context.push('/homes/create'),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
