import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/company_settings.dart';
import '../../models/employe.dart';
import '../../models/market.dart';
import '../../services/company_settings_service.dart';
import '../../services/employe_service.dart';
import '../../services/market_service.dart';
import '../../services/pdf_service.dart';

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

  Future<void> _marquerVisite() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    await EmployeService().marquerVisiteMedicale(widget.employeId, picked);
    await _load();
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
                      _VisiteMedicaleCard(
                        employe: _employe!,
                        onMarquer: _marquerVisite,
                      ),
                      const SizedBox(height: 12),
                      _FichePaieCard(
                        employe: _employe!,
                        affectations: _affectations,
                      ),
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

class _VisiteMedicaleCard extends StatelessWidget {
  final Employe employe;
  final VoidCallback onMarquer;
  const _VisiteMedicaleCard({required this.employe, required this.onMarquer});

  @override
  Widget build(BuildContext context) {
    final faite = employe.visiteMedicaleFaite;
    final enRetard = employe.visiteMedicaleEnRetard;
    final color = faite
        ? AppColors.g600
        : enRetard
            ? AppColors.red
            : AppColors.orange;
    final String texte;
    if (faite) {
      texte = 'Effectuée le ${DateFormat('dd/MM/yyyy').format(employe.visiteMedicaleLe!)}';
    } else if (enRetard) {
      texte = 'En retard — était à faire avant le '
          '${DateFormat('dd/MM/yyyy').format(employe.visiteMedicaleEcheance)}';
    } else {
      texte = 'À effectuer avant le '
          '${DateFormat('dd/MM/yyyy').format(employe.visiteMedicaleEcheance)}';
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              faite ? Icons.verified_outlined : Icons.medical_services_outlined,
              color: color,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Visite médicale de démarrage',
                      style: TextStyle(fontSize: 12, color: AppColors.s400)),
                  const SizedBox(height: 2),
                  Text(texte,
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600, color: color)),
                ],
              ),
            ),
            TextButton(
              onPressed: onMarquer,
              child: Text(faite ? 'Modifier' : 'Marquer effectuée',
                  style: const TextStyle(fontSize: 12)),
            ),
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
          if (employe.categorie != null)
            _row('Catégorie', employe.categorie!.label, icon: Icons.groups_outlined),
          if (employe.matricule != null)
            _row('Matricule', employe.matricule!, icon: Icons.badge_outlined),
          if (employe.superviseurNom != null)
            _row('Superviseur (N+1)', employe.superviseurNom!, icon: Icons.person_pin_outlined),
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
            if (employe.partSalariale > 0)
              _finRow('Part salariale', employe.partSalariale, isDeduction: true),
            if (employe.salaireMensuel > 0) ...[
              const Divider(height: 10),
              _finRow('Net à payer', employe.netAPayer, isBold: true),
            ],
            if (employe.partPatronale > 0 || employe.fraisGestion > 0) ...[
              const Divider(height: 10),
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

  Widget _finRow(String label, double montant,
      {bool isDeduction = false, bool isBold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(label,
              style: TextStyle(
                  color: isDeduction ? AppColors.red : AppColors.s500,
                  fontSize: 12,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal))),
          Text(
            isDeduction
                ? '- ${Formatters.fcfa(montant)}'
                : Formatters.fcfa(montant),
            style: TextStyle(
                fontSize: isBold ? 13 : 12,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                color: isDeduction ? AppColors.red
                    : isBold ? AppColors.g700
                    : null),
          ),
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

// ── Fiche de paie ──────────────────────────────────────────────────────────────

class _FichePaieCard extends StatefulWidget {
  final Employe employe;
  final List<Affectation> affectations;
  const _FichePaieCard({required this.employe, required this.affectations});

  @override
  State<_FichePaieCard> createState() => _FichePaieCardState();
}

class _FichePaieCardState extends State<_FichePaieCard> {
  bool _busy = false;
  CompanySettings? _settings;
  DateTime _period = DateTime(DateTime.now().year, DateTime.now().month);

  static const _moisFr = [
    '', 'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
  ];

  @override
  void initState() {
    super.initState();
    CompanySettingsService.getMySettings().then((s) {
      if (mounted) setState(() => _settings = s);
    });
  }

  Future<void> _withBusy(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try { await action(); } finally { if (mounted) setState(() => _busy = false); }
  }

  String? get _marketNumero {
    final active = widget.affectations.where((a) => a.enCours).toList();
    return active.isNotEmpty ? active.first.marketNumero : null;
  }

  Future<void> _selectPeriodAndGenerate() async {
    // Sélecteur mois/année
    int selectedMonth = _period.month;
    int selectedYear  = _period.year;

    final now   = DateTime.now();
    final years = List.generate(5, (i) => now.year - i);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Sélectionner la période'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: selectedMonth,
                decoration: const InputDecoration(labelText: 'Mois'),
                items: List.generate(12, (i) => DropdownMenuItem(
                  value: i + 1,
                  child: Text(_moisFr[i + 1]),
                )),
                onChanged: (v) => setSt(() => selectedMonth = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: selectedYear,
                decoration: const InputDecoration(labelText: 'Année'),
                items: years.map((y) => DropdownMenuItem(
                  value: y, child: Text(y.toString()),
                )).toList(),
                onChanged: (v) => setSt(() => selectedYear = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Générer'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _period = DateTime(selectedYear, selectedMonth));
    await _withBusy(_generateAndShare);
  }

  Future<void> _generateAndShare() async {
    try {
      final bytes = await PdfService.generateFichePaie(
        widget.employe,
        _period,
        settings: _settings,
        marketNumero: _marketNumero,
      );
      if (!mounted) return;
      final filename =
          'fiche-paie-${widget.employe.matricule ?? widget.employe.nom}-'
          '${_period.year}-${_period.month.toString().padLeft(2, '0')}.pdf';
      await Printing.sharePdf(bytes: bytes, filename: filename);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: AppColors.red),
        );
      }
    }
  }

  Future<void> _shareWhatsApp() async {
    await _withBusy(() async {
      final name = _settings?.companyName.isNotEmpty == true
          ? _settings!.companyName : 'GesPro';
      final tel = _settings?.telephone;
      final msg = 'Bonjour,\n\nVeuillez trouver votre fiche de paie $name.\n\n'
          '👤 ${widget.employe.nomComplet}\n'
          '📅 ${_moisFr[_period.month]} ${_period.year}\n'
          '💰 Net à payer : ${Formatters.fcfa(widget.employe.netAPayer)}\n\n'
          'Cordialement,\n$name'
          '${tel != null && tel.isNotEmpty ? '\n📞 $tel' : ''}';
      final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(msg)}');
      if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.platformDefault);
    });
  }

  Future<void> _shareEmail() async {
    await _withBusy(() async {
      final name    = _settings?.companyName.isNotEmpty == true ? _settings!.companyName : 'GesPro';
      final subject = Uri.encodeComponent(
          'Fiche de paie $name – ${_moisFr[_period.month]} ${_period.year}');
      final body = Uri.encodeComponent(
          'Bonjour,\n\nVeuillez trouver votre fiche de paie.\n\n'
          'Employé : ${widget.employe.nomComplet}\n'
          'Période : ${_moisFr[_period.month]} ${_period.year}\n'
          'Net à payer : ${Formatters.fcfa(widget.employe.netAPayer)}\n\n'
          'Cordialement,\n$name');
      final uri = Uri.parse('mailto:?subject=$subject&body=$body');
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.receipt_outlined, size: 16, color: AppColors.g700),
            SizedBox(width: 6),
            Text('Fiche de paie',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                    color: AppColors.g700)),
          ]),
          const SizedBox(height: 12),
          // Bouton principal
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.g700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _busy ? null : _selectPeriodAndGenerate,
              icon: _busy
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: Text(_busy ? 'Génération...' : 'Générer la fiche de paie'),
            ),
          ),
          const SizedBox(height: 8),
          // Partage rapide
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _shareWhatsApp,
                icon: const Icon(Icons.chat_outlined, size: 16),
                label: const Text('WhatsApp', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF25D366),
                  side: const BorderSide(color: Color(0xFF25D366)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _shareEmail,
                icon: const Icon(Icons.email_outlined, size: 16),
                label: const Text('Email', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.g600),
              ),
            ),
          ]),
          if (!kIsWeb)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'PDF : ${_moisFr[_period.month]} ${_period.year}',
                style: const TextStyle(fontSize: 10, color: AppColors.s400),
              ),
            ),
        ]),
      ),
    );
  }
}
