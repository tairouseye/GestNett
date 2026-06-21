import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../models/reminder.dart';
import '../../providers/reminders_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminders = ref.watch(remindersProvider);

    return Scaffold(
      backgroundColor: AppColors.g50,
      appBar: AppBar(title: const Text('Notifications')),
      body: reminders.when(
        data: (list) => list.isEmpty
            ? const _EmptyState()
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(remindersProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _ReminderTile(
                    reminder: list[i],
                    onTap: () {
                      final t = list[i].target;
                      if (t != null) context.go(t);
                    },
                  ),
                ),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
      ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  final Reminder reminder;
  final VoidCallback onTap;
  const _ReminderTile({required this.reminder, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = reminder.type == ReminderType.valorisation
        ? AppColors.g600
        : switch (reminder.severite) {
            ReminderSeverite.danger  => AppColors.red,
            ReminderSeverite.warning => AppColors.orange,
            ReminderSeverite.info    => AppColors.blue,
          };
    final icon = switch (reminder.type) {
      ReminderType.visiteMedicale => Icons.medical_services_outlined,
      ReminderType.visiteTerrain  => Icons.assignment_outlined,
      ReminderType.suiviQualite   => Icons.warning_amber_outlined,
      ReminderType.valorisation   => Icons.star_outline,
      ReminderType.echeanceMarche => Icons.event_busy_outlined,
    };
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(reminder.titre,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        subtitle: Text(reminder.sousTitre,
            style: TextStyle(fontSize: 12, color: color)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.s300),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: AppColors.g400),
            SizedBox(height: 12),
            Text('Aucune notification', style: TextStyle(color: AppColors.s400)),
            SizedBox(height: 4),
            Text('Tout est à jour 🎉',
                style: TextStyle(color: AppColors.s300, fontSize: 12)),
          ],
        ),
      );
}
