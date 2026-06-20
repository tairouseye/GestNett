import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/employe.dart';
import '../../providers/rh_provider.dart';

class RhDashboardScreen extends ConsumerWidget {
  const RhDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(rhStatsProvider);
    return Scaffold(
      backgroundColor: AppColors.g50,
      appBar: AppBar(
        title: const Text('Tableau de bord RH'),
        backgroundColor: AppColors.g700,
        foregroundColor: Colors.white,
      ),
      body: stats.when(
        data: (s) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(rhStatsProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Effectifs
              Row(children: [
                _Kpi('Effectif total', '${s.total}', Icons.people_alt_outlined, AppColors.g700),
                const SizedBox(width: 8),
                _Kpi('Actifs', '${s.actifs}', Icons.badge_outlined, AppColors.g600),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                _Kpi('Masse salariale', Formatters.fcfa(s.masseSalariale),
                    Icons.payments_outlined, AppColors.blue),
              ]),
              const SizedBox(height: 16),

              // Répartition par catégorie
              const Text('Répartition par catégorie',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              Row(children: [
                _Kpi('🏛️ Gestion', '${s.gestion}', Icons.account_balance_outlined,
                    const Color(0xFF7C3AED)),
                const SizedBox(width: 8),
                _Kpi('🧭 Supervision', '${s.supervision}', Icons.supervisor_account_outlined,
                    AppColors.blue),
                const SizedBox(width: 8),
                _Kpi('🛠️ Terrain', '${s.terrain}', Icons.handyman_outlined, AppColors.g600),
              ]),
              const SizedBox(height: 16),

              // Alertes RH
              _Section(
                titre: '🔴 Visites médicales en retard',
                color: AppColors.red,
                employes: s.visitesEnRetard,
                vide: 'Aucune visite en retard',
                onTap: (id) => context.push('/employes/$id'),
              ),
              _Section(
                titre: '⚠️ Employés à suivre',
                color: AppColors.red,
                employes: s.aSuivre,
                vide: 'Aucun employé à suivre',
                onTap: (id) => context.push('/employes/$id'),
              ),
              _Section(
                titre: '⭐ Employés à valoriser',
                color: AppColors.g600,
                employes: s.aValoriser,
                vide: 'Aucun employé à valoriser',
                onTap: (id) => context.push('/employes/$id'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _Kpi(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.s100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: 6),
              Text(value,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(label, style: const TextStyle(fontSize: 10, color: AppColors.s400)),
            ],
          ),
        ),
      );
}

class _Section extends StatelessWidget {
  final String titre;
  final Color color;
  final List<Employe> employes;
  final String vide;
  final void Function(String id) onTap;
  const _Section({
    required this.titre,
    required this.color,
    required this.employes,
    required this.vide,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(titre,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: color)),
              ),
              Text('${employes.length}',
                  style: TextStyle(fontWeight: FontWeight.w800, color: color)),
            ]),
            if (employes.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(vide, style: const TextStyle(fontSize: 12, color: AppColors.s400)),
              )
            else
              ...employes.map((e) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    onTap: () => onTap(e.id),
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.g100,
                      backgroundImage: (e.photoUrl != null && e.photoUrl!.isNotEmpty)
                          ? NetworkImage(e.photoUrl!)
                          : null,
                      child: (e.photoUrl != null && e.photoUrl!.isNotEmpty)
                          ? null
                          : Text(e.nom.isNotEmpty ? e.nom[0].toUpperCase() : '?',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(e.nomComplet, style: const TextStyle(fontSize: 13)),
                    subtitle: Text(e.poste ?? '—', style: const TextStyle(fontSize: 11)),
                    trailing: const Icon(Icons.chevron_right, size: 16, color: AppColors.s300),
                  )),
          ],
        ),
      ),
    );
  }
}
