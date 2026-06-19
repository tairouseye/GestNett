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
  EmployeCategorie? _filtre; // null = tous

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

  double get _coutTotalMensuel =>
      _employes.where((e) => e.statut == EmployeStatut.actif)
               .fold(0.0, (s, e) => s + e.coutTotal);

  @override
  Widget build(BuildContext context) {
    final filtered = _employes
        .where((e) => _filtre == null || e.categorie == _filtre)
        .toList();
    final actifs   = filtered.where((e) => e.statut == EmployeStatut.actif).toList();
    final inactifs = filtered.where((e) => e.statut == EmployeStatut.inactif).toList();

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
                    total: _coutTotalMensuel,
                    nbActifs: _employes.where((e) => e.statut == EmployeStatut.actif).length,
                    nbTotal: _employes.length,
                  ),
                  const SizedBox(height: 12),

                  // ── Filtre par catégorie ─────────────────────────────
                  if (_employes.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      children: [
                        _FilterChip(
                          label: 'Tous',
                          selected: _filtre == null,
                          onTap: () => setState(() => _filtre = null),
                        ),
                        _FilterChip(
                          label: '🏛️ Gestion',
                          selected: _filtre == EmployeCategorie.gestion,
                          onTap: () => setState(() => _filtre = EmployeCategorie.gestion),
                        ),
                        _FilterChip(
                          label: '🧭 Supervision',
                          selected: _filtre == EmployeCategorie.supervision,
                          onTap: () => setState(() => _filtre = EmployeCategorie.supervision),
                        ),
                        _FilterChip(
                          label: '🛠️ Terrain',
                          selected: _filtre == EmployeCategorie.terrain,
                          onTap: () => setState(() => _filtre = EmployeCategorie.terrain),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),

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
          const Text('Coût total mensuel', style: TextStyle(color: AppColors.s400, fontSize: 12)),
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(label, style: const TextStyle(fontSize: 12)),
    selected: selected,
    onSelected: (_) => onTap(),
    selectedColor: AppColors.g600,
    labelStyle: TextStyle(color: selected ? Colors.white : AppColors.s500),
    backgroundColor: AppColors.white,
    side: BorderSide(color: selected ? AppColors.g600 : AppColors.s100),
  );
}

/// Petit badge coloré pour la catégorie d'un employé.
class CategorieBadge extends StatelessWidget {
  final EmployeCategorie categorie;
  const CategorieBadge({super.key, required this.categorie});

  @override
  Widget build(BuildContext context) {
    final color = switch (categorie) {
      EmployeCategorie.gestion     => const Color(0xFF7C3AED), // violet
      EmployeCategorie.supervision => AppColors.blue,
      EmployeCategorie.terrain     => AppColors.g600,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        categorie.label,
        style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
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
        isThreeLine: employe.matricule != null,
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
        title: Row(
          children: [
            Expanded(
              child: Text(employe.nomComplet,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            ),
            if (employe.aSuivre)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.red),
              ),
            if (employe.aValoriser)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.star_rounded, size: 16, color: AppColors.gold),
              ),
            if (employe.categorie != null) CategorieBadge(categorie: employe.categorie!),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(employe.poste ?? 'Poste non défini',
                style: const TextStyle(fontSize: 12, color: AppColors.s400)),
            if (employe.matricule != null)
              Text(employe.matricule!,
                  style: const TextStyle(fontSize: 10, color: AppColors.s300)),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(Formatters.fcfa(employe.coutTotal),
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
