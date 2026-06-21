import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../models/employe.dart';
import '../../models/evaluation.dart';
import '../../services/evaluation_service.dart';

class EvaluationFormScreen extends StatefulWidget {
  final Employe employe;
  final EvaluationType type;
  final List<Affectation> affectationsActives;
  const EvaluationFormScreen({
    super.key,
    required this.employe,
    required this.type,
    required this.affectationsActives,
  });

  @override
  State<EvaluationFormScreen> createState() => _EvaluationFormScreenState();
}

class _EvaluationFormScreenState extends State<EvaluationFormScreen> {
  final Map<String, bool> _reponses = {};
  String? _marketId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Pré-sélectionne le marché si une seule affectation en cours.
    if (widget.affectationsActives.length == 1) {
      _marketId = widget.affectationsActives.first.marketId;
    }
  }

  List<EvalCritere> get _criteres => EvaluationCriteres.forType(widget.type);
  double get _score => EvaluationCriteres.score(widget.type, _reponses);

  Future<void> _envoyerWhatsApp() async {
    final msg = EvaluationCriteres.messageClient(widget.employe.nomComplet);
    await launchUrl(
      Uri.parse('https://wa.me/?text=${Uri.encodeComponent(msg)}'),
      mode: LaunchMode.platformDefault,
    );
  }

  Future<void> _save() async {
    // #4 : une évaluation superviseur doit être rattachée à un marché
    // (sinon le rappel « visite terrain » ne peut pas se résoudre).
    if (widget.type == EvaluationType.superviseur &&
        widget.affectationsActives.isNotEmpty &&
        _marketId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sélectionnez le marché concerné par cette évaluation.'),
          backgroundColor: AppColors.orange,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await EvaluationService().add(Evaluation(
        id: '',
        employeId: widget.employe.id,
        marketId: _marketId,
        type: widget.type,
        date: DateTime.now(),
        reponses: _reponses,
        score: _score,
        createdAt: DateTime.now(),
      ));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: AppColors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isClient = widget.type == EvaluationType.client;
    final scoreColor = _score < kNoteFaibleSeuil ? AppColors.red : AppColors.g600;
    return Scaffold(
      backgroundColor: AppColors.g50,
      appBar: AppBar(
        title: Text('Évaluation ${widget.type.label.toLowerCase()}'),
        backgroundColor: AppColors.g700,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(widget.employe.nomComplet,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          // Marché concerné
          if (widget.affectationsActives.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButtonFormField<String?>(
                  value: _marketId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Marché concerné',
                    border: InputBorder.none,
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Non précisé')),
                    ...widget.affectationsActives.map((a) => DropdownMenuItem(
                          value: a.marketId,
                          child: Text(a.marketNumero ?? a.marketId),
                        )),
                  ],
                  onChanged: (v) => setState(() => _marketId = v),
                ),
              ),
            ),

          if (isClient) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _envoyerWhatsApp,
              icon: const Icon(Icons.chat_outlined, size: 18),
              label: const Text('Envoyer les questions au client (WhatsApp)'),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.g700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Cochez ci-dessous selon les réponses du client.',
              style: TextStyle(fontSize: 12, color: AppColors.s400),
            ),
          ],
          const SizedBox(height: 8),

          // Critères (cases à cocher pondérées)
          Card(
            child: Column(
              children: _criteres.map((c) {
                return CheckboxListTile(
                  value: _reponses[c.key] ?? false,
                  onChanged: (v) => setState(() => _reponses[c.key] = v ?? false),
                  title: Text(c.label, style: const TextStyle(fontSize: 14)),
                  subtitle: Text('Poids : ${c.poids}',
                      style: const TextStyle(fontSize: 11, color: AppColors.s400)),
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: AppColors.g600,
                  dense: true,
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // Score en direct
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scoreColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scoreColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Score de cette évaluation',
                    style: TextStyle(fontSize: 13, color: AppColors.s500)),
                Text('${_score.toStringAsFixed(1)} / 20',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold, color: scoreColor)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.g700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Enregistrement...' : 'Enregistrer l\'évaluation'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
