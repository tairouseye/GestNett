import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/recurrence.dart';
import '../../services/recurrence_service.dart';
import '../../providers/recurrences_provider.dart';

class RecurrencesScreen extends ConsumerWidget {
  const RecurrencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recurrences = ref.watch(recurrencesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Factures récurrentes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/recurrences/new');
          ref.invalidate(recurrencesProvider);
        },
        icon: const Icon(Icons.add),
        label: const Text('Récurrence'),
      ),
      body: recurrences.when(
        data: (list) {
          if (list.isEmpty) return const _EmptyState();
          return RefreshIndicator(
            color: AppColors.g500,
            onRefresh: () async => ref.invalidate(recurrencesProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _RecurrenceTile(
                rec: list[i],
                onChanged: () => ref.invalidate(recurrencesProvider),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
      ),
    );
  }
}

class _RecurrenceTile extends StatelessWidget {
  final Recurrence rec;
  final VoidCallback onChanged;
  const _RecurrenceTile({required this.rec, required this.onChanged});

  Future<void> _toggle(BuildContext context, bool v) async {
    try {
      await RecurrenceService().setActif(rec.id, v);
      onChanged();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la récurrence ?'),
        content: const Text(
            'Les factures déjà générées sont conservées. Seule la planification est supprimée.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await RecurrenceService().delete(rec.id);
      onChanged();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final retard = rec.estEchue;
    return InkWell(
      onTap: () async {
        await context.push('/recurrences/${rec.id}/edit');
        onChanged();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.s100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    rec.clientNom ?? rec.marketNumero ?? 'Récurrence',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
                Switch.adaptive(
                  value: rec.actif,
                  activeColor: AppColors.g500,
                  onChanged: (v) => _toggle(context, v),
                ),
              ],
            ),
            if (rec.marketNumero != null)
              Text(rec.marketNumero!,
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.s400,
                      fontFamily: 'monospace')),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.attach_money, size: 14, color: AppColors.s400),
                const SizedBox(width: 4),
                Text(
                  Formatters.fcfa(rec.totalTtc),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.g700),
                ),
                const SizedBox(width: 4),
                Text('TTC · ${rec.frequence.label.toLowerCase()}',
                    style: const TextStyle(fontSize: 11, color: AppColors.s400)),
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline,
                      size: 20, color: AppColors.s400),
                  onPressed: () => _delete(context),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  retard && rec.actif
                      ? Icons.event_available
                      : Icons.event_outlined,
                  size: 14,
                  color: retard && rec.actif ? AppColors.orange : AppColors.s400,
                ),
                const SizedBox(width: 4),
                Text(
                  retard && rec.actif
                      ? 'À générer (${Formatters.dateShort(rec.prochaineDate)})'
                      : 'Prochaine : ${Formatters.dateShort(rec.prochaineDate)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: retard && rec.actif ? AppColors.orange : AppColors.s500,
                    fontWeight: retard && rec.actif
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
                if (!rec.actif) ...[
                  const SizedBox(width: 8),
                  const _Tag(label: 'Inactive', color: AppColors.s400),
                ],
                if (rec.typeFacture == 'proforma') ...[
                  const SizedBox(width: 8),
                  const _Tag(label: 'Proforma', color: AppColors.blue),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 9, fontWeight: FontWeight.w700, color: color)),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.autorenew, size: 64, color: AppColors.s200),
            const SizedBox(height: 12),
            const Text('Aucune facture récurrente',
                style: TextStyle(color: AppColors.s400, fontSize: 16)),
            const SizedBox(height: 4),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Planifie la facturation automatique des contrats mensuels. '
                'Les factures dues sont créées à l\'ouverture de l\'app.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.s300, fontSize: 12),
              ),
            ),
          ],
        ),
      );
}
