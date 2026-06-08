import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/logout_button.dart';
import '../../core/utils/formatters.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats   = ref.watch(dashboardStatsProvider);
    final monthly = ref.watch(monthlyEncaissementsProvider);
    final profile = ref.watch(currentProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('GesPro', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(width: 6),
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (_, snap) => snap.hasData
                      ? Text('v${snap.data!.version}',
                          style: const TextStyle(fontSize: 10, color: AppColors.g400, fontWeight: FontWeight.w500))
                      : const SizedBox.shrink(),
                ),
              ],
            ),
            profile.when(
              data: (p) => Text(
                p != null ? 'Bonjour, ${p.nom}' : 'GesPro',
                style: const TextStyle(fontSize: 11, color: AppColors.g300),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.go('/notifications'),
          ),
          const LogoutButton(),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.g500,
        onRefresh: () async {
          ref.invalidate(dashboardStatsProvider);
          ref.invalidate(monthlyEncaissementsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // KPIs grid
            stats.when(
              data: (s) => _KpiGrid(stats: s),
              loading: () => _KpiGridShimmer(),
              error: (e, _) => _ErrorCard(message: e.toString()),
            ),

            const SizedBox(height: 20),

            // Graphique encaissements
            _SectionTitle(
              title: 'Encaissements — 6 derniers mois',
              trailing: TextButton(
                onPressed: () => context.go('/invoices'),
                child: const Text('Voir tout'),
              ),
            ),
            const SizedBox(height: 8),
            monthly.when(
              data: (data) => _EncaissementsChart(data: data),
              loading: () => _ChartShimmer(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 20),

            // Accès rapides
            _SectionTitle(title: 'Accès rapide'),
            const SizedBox(height: 10),
            _QuickActions(),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// KPI Grid
// ─────────────────────────────────────────
class _KpiGrid extends StatelessWidget {
  final DashboardStats stats;
  const _KpiGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.5,
      children: [
        _KpiCard(
          label: 'Marchés actifs',
          value: stats.marchesActifs.toString(),
          icon: Icons.handshake,
          color: AppColors.g600,
          unit: 'contrats',
        ),
        _KpiCard(
          label: 'Factures',
          value: stats.nombreFactures.toString(),
          icon: Icons.receipt_long,
          color: AppColors.blue,
          unit: 'créées',
        ),
        _KpiCard(
          label: 'Total facturé',
          value: Formatters.fcfa(stats.totalFacture),
          icon: Icons.payments_outlined,
          color: AppColors.blue,
        ),
        _KpiCard(
          label: 'Encaissé',
          value: Formatters.fcfa(stats.totalEncaisse),
          icon: Icons.account_balance_wallet_outlined,
          color: AppColors.g500,
        ),
        _KpiCard(
          label: 'Dépenses',
          value: Formatters.fcfa(stats.totalDepenses),
          icon: Icons.trending_down,
          color: AppColors.orange,
        ),
        _KpiCard(
          label: 'Bénéfice estimé',
          value: Formatters.fcfa(stats.beneficeEstime),
          icon: Icons.trending_up,
          color: stats.beneficeEstime >= 0 ? AppColors.g600 : AppColors.red,
          fullWidth: true,
        ),
        _KpiCard(
          label: 'Clients en retard',
          value: stats.clientsEnRetard.toString(),
          icon: Icons.warning_amber_outlined,
          color: AppColors.red,
          unit: 'factures',
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? unit;
  final bool fullWidth;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.unit,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.s100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const Spacer(),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: value.length > 10 ? 12 : 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.s900,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                unit ?? label,
                style: const TextStyle(fontSize: 10, color: AppColors.s400),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// Graphique
// ─────────────────────────────────────────
class _EncaissementsChart extends StatelessWidget {
  final List<MonthlyData> data;
  const _EncaissementsChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final maxY = data.map((d) => d.montant).fold(0.0, (a, b) => a > b ? a : b);
    final topY = maxY == 0 ? 100000.0 : maxY * 1.2;

    return Container(
      height: 180,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.s100),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => const FlLine(
              color: AppColors.s100, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, _) {
                  final idx = val.toInt();
                  if (idx < 0 || idx >= data.length) return const SizedBox.shrink();
                  return Text(data[idx].mois,
                      style: const TextStyle(fontSize: 9, color: AppColors.s400));
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0, maxX: (data.length - 1).toDouble(),
          minY: 0, maxY: topY,
          lineBarsData: [
            LineChartBarData(
              spots: data.asMap().entries
                  .map((e) => FlSpot(e.key.toDouble(), e.value.montant))
                  .toList(),
              isCurved: true,
              color: AppColors.g500,
              barWidth: 2.5,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.g500.withOpacity(0.08),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Accès rapides
// ─────────────────────────────────────────
class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _QuickBtn(
          label: 'Nouveau client',
          icon: Icons.person_add_outlined,
          color: AppColors.g600,
          onTap: () => context.go('/clients/new'),
        ),
        const SizedBox(width: 10),
        _QuickBtn(
          label: 'Nouveau marché',
          icon: Icons.add_business_outlined,
          color: AppColors.blue,
          onTap: () => context.go('/markets/new'),
        ),
        const SizedBox(width: 10),
        _QuickBtn(
          label: 'Nouvelle facture',
          icon: Icons.note_add_outlined,
          color: AppColors.orange,
          onTap: () => context.go('/invoices/new'),
        ),
      ],
    );
  }
}

class _QuickBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _QuickBtn({
    required this.label, required this.icon,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Helpers UI
// ─────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const _SectionTitle({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const Spacer(),
      if (trailing != null) trailing!,
    ],
  );
}

class _KpiGridShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
    baseColor: AppColors.s100,
    highlightColor: AppColors.s50,
    child: GridView.count(
      crossAxisCount: 2, shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.5,
      children: List.generate(6, (_) => Container(
        decoration: BoxDecoration(
          color: AppColors.white, borderRadius: BorderRadius.circular(14))),
      ),
    ),
  );
}

class _ChartShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
    baseColor: AppColors.s100,
    highlightColor: AppColors.s50,
    child: Container(
      height: 180,
      decoration: BoxDecoration(
        color: AppColors.white, borderRadius: BorderRadius.circular(14)),
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.red.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text('Erreur : $message',
        style: const TextStyle(color: AppColors.red)),
  );
}
