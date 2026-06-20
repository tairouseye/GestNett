import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/employe.dart';
import '../services/employe_service.dart';

class RhStats {
  final int total;
  final int actifs;
  final int gestion;
  final int supervision;
  final int terrain;
  final double masseSalariale; // coût total mensuel des actifs
  final List<Employe> aSuivre;
  final List<Employe> aValoriser;
  final List<Employe> visitesEnRetard;

  const RhStats({
    required this.total,
    required this.actifs,
    required this.gestion,
    required this.supervision,
    required this.terrain,
    required this.masseSalariale,
    required this.aSuivre,
    required this.aValoriser,
    required this.visitesEnRetard,
  });
}

final rhStatsProvider = FutureProvider<RhStats>((ref) async {
  final employes = await EmployeService().getAll();
  final actifs = employes.where((e) => e.statut == EmployeStatut.actif).toList();
  return RhStats(
    total: employes.length,
    actifs: actifs.length,
    gestion:     employes.where((e) => e.categorie == EmployeCategorie.gestion).length,
    supervision: employes.where((e) => e.categorie == EmployeCategorie.supervision).length,
    terrain:     employes.where((e) => e.categorie == EmployeCategorie.terrain).length,
    masseSalariale: actifs.fold<double>(0, (s, e) => s + e.coutTotal),
    aSuivre:    employes.where((e) => e.aSuivre).toList(),
    aValoriser: employes.where((e) => e.aValoriser).toList(),
    visitesEnRetard:
        actifs.where((e) => e.visiteMedicaleEnRetard).toList(),
  );
});
