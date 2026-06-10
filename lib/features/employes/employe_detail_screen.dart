import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/employe.dart';
import '../../models/market.dart';
import '../../services/employe_service.dart';
import '../../services/market_service.dart';

class EmployeDetailScreen extends StatefulWidget {
  final String employeId;
  const EmployeDetailScreen({super.key, required this.employeId});

  @override
  State<EmployeDetailScreen> createState() => _EmployeDetailScreenState();
}

class _EmployeDetailScreenState extends State<EmployeDetailScreen> {
  Employe? _employe;
  List<Affectation> _affectations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      EmployeService().getById(widget.employeId),
      EmployeService().getByEmploye(widget.employeId),
    ]);
    if (mounted) setState(() {
      _employe      = results[0] as Employe?;
      _affectations = results[1] as List<Affectation>;
      _loading      = false;
    });
  }

  Future<void> _affecter() async {
    final markets = await MarketService().getActive();
    if (!mounted) return;

    final assignedIds = _affectations.where((a) => a.enCours).map((a) => a.marketId).toSet();
    final disponibles = markets.where((m) => !assignedIds.contains(m.id)).toList();

    if (disponibles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun marché actif disponible')),
      );
      return;
    }

    Market? selected;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Affecter à un marché'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(shrinkWrap: true, children: disponibles.map((m) =>
            ListTile(
              title: Text(m.numero),
              subtitle: Text(m.clientNom ?? ''),
              onTap: () { selected = m; Navigator.pop(ctx); },
            ),
          ).toList()),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler'))],
      ),
    );

    if (selected == null) return;
    try {
      await EmployeService().affecter(
        employeId: widget.employeId,
        marketId:  selected!.id,
        dateDebut: DateTime.now(),
      );
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: AppColors.red),
      );
    }
  }

  Future<void> _terminer(Affectation a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terminer l\'affectation ?'),
        content: Text('Retirer ${_employe?.nomComplet} du marché ${a.marketNumero} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Terminer'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await EmployeService().terminerAffectation(a.id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.g50,
      appBar: AppBar(
        title: Text(_employe?.nomComplet ?? 'Employé'),
        backgroundColor: AppColors.g700,
        foregroundColor: Colors.white,
        actions: [
          if (_employe != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                await context.push('/employes/${widget.employeId}/edit');
                _load();
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _employe == null
              ? const Center(child: Text('Employé introuvable'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _InfoCard(employe: _employe!),
                      const SizedBox(height: 12),
                      _AffectationsCard(
                        affectations: _affectations,
                        onAffecter: _affecter,
                        onTerminer: _terminer,
                      ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final Employe employe;
  const _InfoCard({required this.employe});

  @override
  Widget build(BuildContext context) {
    final actif = employe.statut == EmployeStatut.actif;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: actif ? AppColors.g100 : AppColors.s100,
              child: Text(employe.nom[0].toUpperCase(),
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                      color: actif ? AppColors.g700 : AppColors.s400)),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(employe.nomComplet,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              if (employe.poste != null)
                Text(employe.poste!, style: const TextStyle(color: AppColors.s500, fontSize: 13)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (actif ? AppColors.g600 : AppColors.s400).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(employe.statut.label,
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: actif ? AppColors.g600 : AppColors.s400)),
            ),
          ]),
          const Divider(height: 20),
          if (employe.matricule != null)
            _row('Matricule', employe.matricule!, icon: Icons.badge_outlined),
          if (employe.telephone != null)
            _row('Téléphone', employe.telephone!, icon: Icons.phone_outlined),
          if (employe.dateEmbauche != null)
            _row('Date d\'embauche', DateFormat('dd/MM/yyyy').format(employe.dateEmbauche!),
                icon: Icons.calendar_today_outlined),
          if (employe.notes != null)
            _row('Notes', employe.notes!, icon: Icons.notes_outlined),
          if (employe.salaireMensuel > 0 || employe.partPatronale > 0 || employe.fraisGestion > 0) ...[
            const Divider(height: 20),
            if (employe.salaireMensuel > 0)
              _finRow('Salaire brut', employe.salaireMensuel),
            if (employe.partPatronale > 0)
              _finRow('Part patronale', employe.partPatronale),
            if (employe.fraisGestion > 0)
              _finRow(
                employe.fraisGestionType == 'pct'
                    ? 'Frais gestion (${employe.fraisGestionPct.toStringAsFixed(0)}%)'
                    : 'Frais gestion',
                employe.fraisGestion,
              ),
            const Divider(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                const Expanded(child: Text('Coût total / mois',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                Text(Formatters.fcfa(employe.coutTotal),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.g700)),
              ]),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _row(String label, String value, {IconData? icon}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      if (icon != null) ...[
        Icon(icon, size: 14, color: AppColors.s400),
        const SizedBox(width: 6),
      ],
      SizedBox(width: 110, child: Text(label,
          style: const TextStyle(color: AppColors.s400, fontSize: 12))),
      Expanded(child: Text(value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
    ]),
  );

  Widget _finRow(String label, double montant) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Expanded(child: Text(label,
          style: const TextStyle(color: AppColors.s500, fontSize: 12))),
      Text(Formatters.fcfa(montant),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
    ]),
  );
}

class _AffectationsCard extends StatelessWidget {
  final List<Affectation> affectations;
  final VoidCallback onAffecter;
  final void Function(Affectation) onTerminer;
  const _AffectationsCard({required this.affectations, required this.onAffecter, required this.onTerminer});

  @override
  Widget build(BuildContext context) {
    final enCours   = affectations.where((a) => a.enCours).toList();
    final terminees = affectations.where((a) => !a.enCours).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: Text('Marchés assignés',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
            TextButton.icon(
              onPressed: onAffecter,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Affecter', style: TextStyle(fontSize: 12)),
            ),
          ]),
          const SizedBox(height: 8),

          if (enCours.isEmpty && terminees.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Aucune affectation', style: TextStyle(color: AppColors.s400, fontSize: 13)),
            ),

          ...enCours.map((a) => _AffectationTile(
            affectation: a,
            enCours: true,
            onTerminer: () => onTerminer(a),
          )),

          if (terminees.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Terminées', style: TextStyle(fontSize: 11, color: AppColors.s400)),
            const SizedBox(height: 4),
            ...terminees.map((a) => _AffectationTile(affectation: a, enCours: false)),
          ],
        ]),
      ),
    );
  }
}

class _AffectationTile extends StatelessWidget {
  final Affectation affectation;
  final bool enCours;
  final VoidCallback? onTerminer;
  const _AffectationTile({required this.affectation, required this.enCours, this.onTerminer});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.handshake_outlined,
          color: enCours ? AppColors.g600 : AppColors.s300, size: 20),
      title: Text(affectation.marketNumero ?? 'Marché',
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: enCours ? Colors.black87 : AppColors.s400)),
      subtitle: Text(
        enCours
            ? 'Depuis ${fmt.format(affectation.dateDebut)}'
            : '${fmt.format(affectation.dateDebut)} → ${fmt.format(affectation.dateFin!)}',
        style: const TextStyle(fontSize: 11),
      ),
      trailing: enCours && onTerminer != null
          ? IconButton(
              icon: const Icon(Icons.logout, size: 18, color: AppColors.red),
              tooltip: 'Terminer l\'affectation',
              onPressed: onTerminer,
            )
          : null,
    );
  }
}
