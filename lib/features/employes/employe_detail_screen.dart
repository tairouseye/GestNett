import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/company_settings.dart';
import '../../models/employe.dart';
import '../../models/employe_document.dart';
import '../../models/evaluation.dart';
import '../../models/market.dart';
import '../../services/company_settings_service.dart';
import '../../services/employe_service.dart';
import '../../services/employe_document_service.dart';
import '../../services/evaluation_service.dart';
import '../../services/market_service.dart';
import '../../services/pdf_service.dart';
import '../../services/storage_service.dart';
import 'evaluation_form_screen.dart';

class EmployeDetailScreen extends StatefulWidget {
  final String employeId;
  const EmployeDetailScreen({super.key, required this.employeId});

  @override
  State<EmployeDetailScreen> createState() => _EmployeDetailScreenState();
}

class _EmployeDetailScreenState extends State<EmployeDetailScreen> {
  Employe? _employe;
  List<Affectation> _affectations = [];
  List<Evaluation> _evaluations = [];
  List<Employe> _equipe = [];
  List<EmployeDocument> _documents = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final employe     = await EmployeService().getById(widget.employeId);
      final affectations = await EmployeService().getByEmploye(widget.employeId);
      // Les évaluations sont optionnelles : une erreur ici ne doit pas bloquer la fiche.
      List<Evaluation> evaluations = [];
      try {
        evaluations = await EvaluationService().getByEmploye(widget.employeId);
      } catch (_) {/* table évaluations indisponible : on ignore */}
      // Équipe (N-1) si l'employé encadre.
      List<Employe> equipe = [];
      if (employe?.categorie == EmployeCategorie.gestion ||
          employe?.categorie == EmployeCategorie.supervision) {
        equipe = await EmployeService().getBySuperviseur(widget.employeId);
      }
      // Documents (optionnels : table peut ne pas exister avant migration 010).
      List<EmployeDocument> documents = [];
      try {
        documents = await EmployeDocumentService().getByEmploye(widget.employeId);
      } catch (_) {/* table documents indisponible : on ignore */}
      if (mounted) setState(() {
        _employe      = employe;
        _affectations = affectations;
        _evaluations  = evaluations;
        _equipe       = equipe;
        _documents    = documents;
        _loading      = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _evaluer(EvaluationType type) async {
    final actives = _affectations.where((a) => a.enCours).toList();
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EvaluationFormScreen(
          employe: _employe!,
          type: type,
          affectationsActives: actives,
        ),
      ),
    );
    if (ok == true) await _load();
  }

  Future<void> _editPlanAction() async {
    final ctrl = TextEditingController(text: _employe?.planAction ?? '');
    final texte = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Plan d\'action'),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Mesures à prendre suite à la note faible...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (texte == null) return;
    await EmployeService().updatePlanAction(widget.employeId, texte);
    await _load();
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

  Future<void> _addDocument() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.single.bytes == null) return;
    final file = result.files.single;
    if (!mounted) return;

    // Choix du type
    String? type = 'autre';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Type de document'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: EmployeDocument.types.entries
                .map((e) => RadioListTile<String>(
                      dense: true,
                      value: e.key,
                      groupValue: type,
                      title: Text(e.value, style: const TextStyle(fontSize: 13)),
                      onChanged: (v) => setLocal(() => type = v),
                    ))
                .toList(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ajouter')),
          ],
        ),
      ),
    );
    if (ok != true) return;

    try {
      final url = await StorageService.uploadEmployeDoc(
          file.bytes!, widget.employeId, file.extension ?? 'bin');
      await EmployeDocumentService().add(EmployeDocument(
        id: '',
        employeId: widget.employeId,
        nom: file.name,
        type: type,
        url: url,
        createdAt: DateTime.now(),
      ));
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur document : $e'), backgroundColor: AppColors.red),
        );
      }
    }
  }

  Future<void> _deleteDocument(EmployeDocument doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ?'),
        content: Text('Supprimer le document « ${doc.nom} » ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await EmployeDocumentService().delete(doc.id);
    await _load();
  }

  Future<void> _affecter() async {
    // Pré-requis : visite médicale validée avant toute affectation.
    if (_employe != null && !_employe!.visiteMedicaleFaite) {
      final marquer = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Visite médicale requise'),
          content: const Text(
            'Cet employé ne peut pas être affecté à un marché tant que sa '
            'visite médicale de démarrage n\'est pas validée.\n\n'
            'Voulez-vous enregistrer la date de la visite maintenant ?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Plus tard')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Saisir la visite')),
          ],
        ),
      );
      if (marquer == true) await _marquerVisite();
      return;
    }

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
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.red, size: 48),
                        const SizedBox(height: 12),
                        Text('Erreur de chargement\n$_error',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.red)),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
                      ],
                    ),
                  ),
                )
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
                      const SizedBox(height: 12),
                      _EvaluationsCard(
                        employe: _employe!,
                        evaluations: _evaluations,
                        onEvaluer: _evaluer,
                        onEditPlan: _editPlanAction,
                      ),
                      if (_equipe.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _EquipeCard(
                          equipe: _equipe,
                          onTap: (id) async {
                            await context.push('/employes/$id');
                            _load();
                          },
                        ),
                      ],
                      const SizedBox(height: 12),
                      _DocumentsCard(
                        documents: _documents,
                        onAdd: _addDocument,
                        onOpen: (d) => launchUrl(Uri.parse(d.url),
                            mode: LaunchMode.platformDefault),
                        onDelete: _deleteDocument,
                      ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
    );
  }
}

class _DocumentsCard extends StatelessWidget {
  final List<EmployeDocument> documents;
  final VoidCallback onAdd;
  final void Function(EmployeDocument) onOpen;
  final void Function(EmployeDocument) onDelete;
  const _DocumentsCard({
    required this.documents,
    required this.onAdd,
    required this.onOpen,
    required this.onDelete,
  });

  IconData _iconFor(String nom) {
    final n = nom.toLowerCase();
    if (n.endsWith('.pdf')) return Icons.picture_as_pdf_outlined;
    if (n.endsWith('.png') || n.endsWith('.jpg') || n.endsWith('.jpeg')) {
      return Icons.image_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Documents (${documents.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                TextButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.upload_file_outlined, size: 16),
                  label: const Text('Ajouter', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            if (documents.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Aucun document (CNI, contrat, certificat médical...)',
                    style: TextStyle(fontSize: 12, color: AppColors.s400)),
              )
            else
              ...documents.map((d) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    onTap: () => onOpen(d),
                    leading: Icon(_iconFor(d.nom), color: AppColors.g600),
                    title: Text(d.nom,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(d.typeLabel, style: const TextStyle(fontSize: 11)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.red),
                      onPressed: () => onDelete(d),
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}

class _EquipeCard extends StatelessWidget {
  final List<Employe> equipe;
  final void Function(String id) onTap;
  const _EquipeCard({required this.equipe, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mon équipe (${equipe.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            ...equipe.map((e) {
              final actif = e.statut == EmployeStatut.actif;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                onTap: () => onTap(e.id),
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.g100,
                  backgroundImage: (e.photoUrl != null && e.photoUrl!.isNotEmpty)
                      ? NetworkImage(e.photoUrl!)
                      : null,
                  child: (e.photoUrl != null && e.photoUrl!.isNotEmpty)
                      ? null
                      : Text(e.nom.isNotEmpty ? e.nom[0].toUpperCase() : '?',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.g700)),
                ),
                title: Text(e.nomComplet,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: Text(e.poste ?? '—', style: const TextStyle(fontSize: 11)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (e.aSuivre)
                      const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.red),
                    if (e.aValoriser)
                      const Icon(Icons.star_rounded, size: 14, color: AppColors.gold),
                    if (!actif)
                      const Text('Inactif', style: TextStyle(fontSize: 9, color: AppColors.s400)),
                    const Icon(Icons.chevron_right, size: 16, color: AppColors.s300),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _EvaluationsCard extends StatelessWidget {
  final Employe employe;
  final List<Evaluation> evaluations;
  final void Function(EvaluationType) onEvaluer;
  final VoidCallback onEditPlan;
  const _EvaluationsCard({
    required this.employe,
    required this.evaluations,
    required this.onEvaluer,
    required this.onEditPlan,
  });

  double? _latest(EvaluationType t) {
    for (final e in evaluations) {
      if (e.type == t) return e.score; // triées date desc
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final sup = _latest(EvaluationType.superviseur);
    final cli = _latest(EvaluationType.client);
    final bothEvals = sup != null && cli != null;
    final note = noteFinale(scoreSuperviseur: sup, scoreClient: cli);
    final faible = note != null && note < kNoteFaibleSeuil;
    final noteColor = note == null
        ? AppColors.s400
        : faible
            ? AppColors.red
            : AppColors.g600;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Évaluations',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                if (employe.aSuivre)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('⚠️ À suivre',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.red)),
                  ),
                if (employe.aValoriser)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('⭐ À valoriser',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF8A6D00))),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Note finale pondérée
            Row(
              children: [
                Expanded(
                  child: _scoreBox('Superviseur (40%)', sup),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _scoreBox('Client (60%)', cli),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: noteColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: noteColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Note finale pondérée',
                      style: TextStyle(fontSize: 13, color: AppColors.s500)),
                  Text(note == null ? '—' : '${note.toStringAsFixed(1)} / 20',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: noteColor)),
                ],
              ),
            ),

            // Évaluation partielle : on attend les deux avis avant de décider l'action.
            if (!bothEvals && note != null) ...[
              const SizedBox(height: 8),
              Text(
                'Évaluation partielle — en attente de '
                '${sup == null ? 'l\'évaluation superviseur' : 'l\'évaluation client'} '
                'avant de déterminer le niveau et l\'action.',
                style: const TextStyle(fontSize: 12, color: AppColors.s400, fontStyle: FontStyle.italic),
              ),
            ],

            // Niveau de performance + action recommandée (seulement si les 2 évals)
            if (niveauFromNote(note) case final niv? when bothEvals) ...[
              const SizedBox(height: 8),
              Builder(builder: (_) {
                final c = _niveauColor(niv);
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: c.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${niv.emoji}  Niveau : ${niv.label}',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c)),
                      const SizedBox(height: 4),
                      Text(niv.action,
                          style: const TextStyle(fontSize: 12, color: AppColors.s500)),
                    ],
                  ),
                );
              }),
            ],

            // Plan d'action si à suivre
            if (employe.aSuivre) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.orange.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Plan d\'action (N+1)',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.orange)),
                        ),
                        TextButton(
                          onPressed: onEditPlan,
                          child: Text(employe.planAction == null ? 'Définir' : 'Modifier',
                              style: const TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    Text(
                      employe.planAction ?? 'Aucun plan défini.',
                      style: const TextStyle(fontSize: 12, color: AppColors.s500),
                    ),
                  ],
                ),
              ),
            ],

            const Divider(height: 24),

            // Boutons d'évaluation
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => onEvaluer(EvaluationType.superviseur),
                    icon: const Icon(Icons.assignment_outlined, size: 16),
                    label: const Text('Superviseur', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => onEvaluer(EvaluationType.client),
                    icon: const Icon(Icons.person_outline, size: 16),
                    label: const Text('Client', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),

            // Historique
            if (evaluations.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Historique',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.s500)),
              const SizedBox(height: 4),
              ...evaluations.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Icon(
                          e.type == EvaluationType.client ? Icons.person_outline : Icons.assignment_outlined,
                          size: 14, color: AppColors.s400,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${e.type.label}'
                            '${e.marketNumero != null ? ' · ${e.marketNumero}' : ''}'
                            ' · ${DateFormat('dd/MM/yyyy').format(e.date)}',
                            style: const TextStyle(fontSize: 11, color: AppColors.s500),
                          ),
                        ),
                        Text('${e.score.toStringAsFixed(1)}/20',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: e.score < kNoteFaibleSeuil ? AppColors.red : AppColors.g600)),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Color _niveauColor(NiveauPerformance niv) => switch (niv) {
        NiveauPerformance.faible     => AppColors.red,
        NiveauPerformance.aAmeliorer => AppColors.orange,
        NiveauPerformance.bien       => AppColors.g600,
        NiveauPerformance.excellent  => AppColors.gold,
      };

  Widget _scoreBox(String label, double? score) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.s50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: AppColors.s400)),
            const SizedBox(height: 2),
            Text(score == null ? '—' : '${score.toStringAsFixed(1)}/20',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      );
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
              backgroundImage: (employe.photoUrl != null && employe.photoUrl!.isNotEmpty)
                  ? NetworkImage(employe.photoUrl!)
                  : null,
              child: (employe.photoUrl != null && employe.photoUrl!.isNotEmpty)
                  ? null
                  : Text(employe.nom[0].toUpperCase(),
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
            InkWell(
              onTap: employe.superviseurId != null
                  ? () => context.push('/employes/${employe.superviseurId}')
                  : null,
              child: _row('Superviseur (N+1)', employe.superviseurNom!,
                  icon: Icons.person_pin_outlined),
            ),
          if (employe.telephone != null)
            _row('Téléphone', employe.telephone!, icon: Icons.phone_outlined),
          if (employe.adresse != null)
            _row('Adresse', employe.adresse!, icon: Icons.location_on_outlined),
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
