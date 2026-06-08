import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/logout_button.dart';
import '../../core/utils/formatters.dart';
import '../../models/employe.dart';
import '../../services/employe_service.dart';

class EmployesListScreen extends StatefulWidget {
  const EmployesListScreen({super.key});

  @override
  State<EmployesListScreen> createState() => _EmployesListScreenState();
}

class _EmployesListScreenState extends State<EmployesListScreen> {
  List<Employe> _employes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await EmployeService().getAll();
    if (mounted) setState(() { _employes = list; _loading = false; });
  }

  double get _masseSalariale =>
      _employes.where((e) => e.statut == EmployeStatut.actif)
               .fold(0.0, (s, e) => s + e.salaireMensuel);

  @override
  Widget build(BuildContext context) {
    final actifs   = _employes.where((e) => e.statut == EmployeStatut.actif).toList();
    final inactifs = _employes.where((e) => e.statut == EmployeStatut.inactif).toList();

    return Scaffold(
      backgroundColor: AppColors.g50,
      appBar: AppBar(
        title: const Text('Personnel'),
        backgroundColor: AppColors.g700,
        foregroundColor: Colors.white,
        actions: const [LogoutButton()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/employes/new');
          _load();
        },
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Ajouter'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── KPI masse salariale ──────────────────────────────
                  _MasseSalarialeCard(
                    total: _masseSalariale,
                    nbActifs: actifs.length,
                    nbTotal: _employes.length,
                  ),
                  const SizedBox(height: 16),

                  if (_employes.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Column(children: [
                          const Icon(Icons.people_outline, size: 64, color: AppColors.s200),
                          const SizedBox(height: 12),
                          const Text('Aucun employé', style: TextStyle(color: AppColors.s400, fontSize: 15)),
                          const SizedBox(height: 4),
                          const Text('Appuyez sur + pour ajouter', style: TextStyle(color: AppColors.s300, fontSize: 12)),
                        ]),
                      ),
                    ),

                  // ── Employés actifs ──────────────────────────────────
                  if (actifs.isNotEmpty) ...[
                    _SectionLabel('Actifs (${actifs.length})'),
                    const SizedBox(height: 8),
                    ...actifs.map((e) => _EmployeCard(employe: e, onTap: () async {
                      await context.push('/employes/${e.id}');
                      _load();
                    })),
                  ],

                  // ── Employés inactifs ────────────────────────────────
                  if (inactifs.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _SectionLabel('Inactifs (${inactifs.length})'),
                    const SizedBox(height: 8),
                    ...inactifs.map((e) => _EmployeCard(employe: e, onTap: () async {
                      await context.push('/employes/${e.id}');
                      _load();
                    })),
                  ],
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }
}

class _MasseSalarialeCard extends StatelessWidget {
  final double total;
  final int nbActifs, nbTotal;
  const _MasseSalarialeCard({required this.total, required this.nbActifs, required this.nbTotal});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.g100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.people_alt_outlined, color: AppColors.g700, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Masse salariale mensuelle', style: TextStyle(color: AppColors.s400, fontSize: 12)),
          const SizedBox(height: 2),
          Text(Formatters.fcfa(total),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.g700)),
          const SizedBox(height: 2),
          Text('$nbActifs actif${nbActifs > 1 ? 's' : ''} sur $nbTotal employé${nbTotal > 1 ? 's' : ''}',
              style: const TextStyle(fontSize: 11, color: AppColors.s400)),
        ])),
      ]),
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.s500)),
  );
}

class _EmployeCard extends StatelessWidget {
  final Employe employe;
  final VoidCallback onTap;
  const _EmployeCard({required this.employe, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final actif = employe.statut == EmployeStatut.actif;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: actif ? AppColors.g100 : AppColors.s100,
          child: Text(
            employe.nom.isNotEmpty ? employe.nom[0].toUpperCase() : '?',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: actif ? AppColors.g700 : AppColors.s400,
            ),
          ),
        ),
        title: Text(employe.nomComplet,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(employe.poste ?? 'Poste non défini',
            style: const TextStyle(fontSize: 12, color: AppColors.s400)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(Formatters.fcfa(employe.salaireMensuel),
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: actif ? AppColors.g700 : AppColors.s400)),
            Text('/mois', style: const TextStyle(fontSize: 10, color: AppColors.s300)),
          ],
        ),
      ),
    );
  }
}
