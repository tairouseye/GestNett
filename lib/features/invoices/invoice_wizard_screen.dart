import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/company_settings.dart';
import '../../services/company_settings_service.dart';
import '../../services/invoice_service.dart';
import '../../services/pdf_service.dart';
import '../../models/invoice.dart';
import 'invoice_wizard_data.dart';

class InvoiceWizardScreen extends StatefulWidget {
  const InvoiceWizardScreen({super.key});

  @override
  State<InvoiceWizardScreen> createState() => _InvoiceWizardScreenState();
}

class _InvoiceWizardScreenState extends State<InvoiceWizardScreen> {
  final _data = InvoiceWizardData();
  final _pageCtrl = PageController();
  int _step = 0;

  // Étapes
  static const _stepTitles = [
    'Client',
    'Prestations',
    'Réduction',
    'TVA & Récap',
    'Facture prête',
  ];

  void _next() {
    if (_step < 4) {
      setState(() => _step++);
      _pageCtrl.animateToPage(
        _step,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prev() {
    if (_step > 0) {
      setState(() => _step--);
      _pageCtrl.animateToPage(
        _step,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  bool get _canGoNext => switch (_step) {
    0 => _data.clientId != null && _data.marketId != null,
    1 => _data.prestations.isNotEmpty &&
        _data.prestations.every(
            (p) => p.designation.trim().isNotEmpty && p.montant > 0),
    _ => true,
  };

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.g900,
      body: SafeArea(
        child: Column(
          children: [
            // ── App Bar ──────────────────────────────────────────
            _WizardAppBar(
              step: _step,
              totalSteps: _stepTitles.length,
              stepTitle: _stepTitles[_step],
              onBack: _step == 0 ? () => context.pop() : _prev,
            ),

            // ── Steps content ────────────────────────────────────
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24)),
                ),
                child: PageView(
                  controller: _pageCtrl,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _StepClient(data: _data, onChange: () => setState(() {})),
                    _StepPrestations(
                        data: _data, onChange: () => setState(() {})),
                    _StepReduction(
                        data: _data, onChange: () => setState(() {})),
                    _StepRecap(data: _data, onChange: () => setState(() {})),
                    _StepFinish(data: _data),
                  ],
                ),
              ),
            ),

            // ── Navigation buttons ───────────────────────────────
            if (_step < 4)
              Container(
                color: AppColors.background,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _canGoNext ? _next : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.g600,
                      disabledBackgroundColor: AppColors.s100,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _step == 3 ? 'Générer la facture' : 'Suivant',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// APP BAR DU WIZARD
// ─────────────────────────────────────────────────────────────────────────────
class _WizardAppBar extends StatelessWidget {
  final int step;
  final int totalSteps;
  final String stepTitle;
  final VoidCallback onBack;

  const _WizardAppBar({
    required this.step,
    required this.totalSteps,
    required this.stepTitle,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.g900,
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 16),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: AppColors.white, size: 18),
                onPressed: onBack,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nouvelle Facture',
                      style: TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16),
                    ),
                    Text(
                      'Étape ${step + 1} / $totalSteps — $stepTitle',
                      style: const TextStyle(
                          color: AppColors.g300, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: step == 4
                      ? AppColors.g100.withAlpha(50)
                      : AppColors.gold.withAlpha(40),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: step == 4
                        ? AppColors.g400.withAlpha(80)
                        : AppColors.gold.withAlpha(80),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (step < 4)
                      const _BlinkDot(color: AppColors.gold),
                    if (step < 4) const SizedBox(width: 5),
                    Text(
                      step < 4 ? 'En cours' : 'Prête ✓',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: step < 4 ? AppColors.gold : AppColors.g300,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Barre de progression
          Row(
            children: List.generate(totalSteps, (i) {
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i < totalSteps - 1 ? 3 : 0),
                  height: 3,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: i < step
                        ? AppColors.g400
                        : i == step
                            ? AppColors.g300
                            : AppColors.white.withAlpha(30),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _BlinkDot extends StatefulWidget {
  final Color color;
  const _BlinkDot({required this.color});

  @override
  State<_BlinkDot> createState() => _BlinkDotState();
}

class _BlinkDotState extends State<_BlinkDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 1, end: 0.2).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _anim,
    child: Container(
      width: 5, height: 5,
      decoration: BoxDecoration(
          color: widget.color, shape: BoxShape.circle),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// ÉTAPE 1 : CLIENT
// ─────────────────────────────────────────────────────────────────────────────
class _StepClient extends StatefulWidget {
  final InvoiceWizardData data;
  final VoidCallback onChange;
  const _StepClient({required this.data, required this.onChange});

  @override
  State<_StepClient> createState() => _StepClientState();
}

class _StepClientState extends State<_StepClient> {
  late final TextEditingController _dateCtrl;
  List<dynamic> _clients = [];
  List<dynamic> _markets = [];
  String? _errorClients;
  String get _uid => Supabase.instance.client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _dateCtrl = TextEditingController(
        text: DateFormat('dd MMMM yyyy', 'fr_FR').format(widget.data.date));
    _loadClients();
    if (widget.data.clientId != null) _loadMarkets(widget.data.clientId!);
  }

  Future<void> _loadClients() async {
    try {
      final clients = await Supabase.instance.client
          .from('clients')
          .select('id, nom, adresse')
          .eq('created_by', _uid)
          .order('nom');
      if (mounted) setState(() => _clients = clients as List);
    } catch (e) {
      if (mounted) setState(() => _errorClients = 'Erreur chargement clients');
    }
  }

  Future<void> _loadMarkets(String clientId) async {
    try {
      final markets = await Supabase.instance.client
          .from('markets')
          .select('id, numero, description')
          .eq('client_id', clientId)
          .eq('created_by', _uid)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _markets = markets as List;
          if (widget.data.marketId != null &&
              !_markets.any((m) => m['id'] == widget.data.marketId)) {
            widget.data.marketId = null;
            widget.data.marketNumero = null;
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorClients = 'Erreur chargement marchés');
    }
  }

  void _selectClient(Map client) {
    widget.data.clientNom = client['nom'] as String;
    widget.data.clientAdresse = client['adresse'] as String? ?? '';
    widget.data.clientId = client['id'] as String;
    widget.data.marketId = null;
    widget.data.marketNumero = null;
    _loadMarkets(client['id'] as String);
    widget.onChange();
  }

  void _selectMarket(Map market) {
    widget.data.marketId = market['id'] as String;
    widget.data.marketNumero = market['numero'] as String?;
    widget.onChange();
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: widget.data.date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('fr', 'FR'),
    );
    if (d != null) {
      widget.data.date = d;
      _dateCtrl.text = DateFormat('dd MMMM yyyy', 'fr_FR').format(d);
      widget.onChange();
    }
  }

  Widget _dropdown({
    required List<dynamic> items,
    required String? value,
    required String hint,
    required String Function(dynamic) label,
    required String Function(dynamic) id,
    required ValueChanged<dynamic> onSelect,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.g300),
      ),
      child: DropdownButtonHideUnderline(
        child: ButtonTheme(
          alignedDropdown: true,
          child: DropdownButton<String>(
            isExpanded: true,
            hint: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(hint, style: const TextStyle(color: AppColors.s400)),
            ),
            value: value,
            items: items.map<DropdownMenuItem<String>>((item) {
              return DropdownMenuItem<String>(
                value: id(item),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(label(item), overflow: TextOverflow.ellipsis),
                ),
              );
            }).toList(),
            onChanged: (v) {
              if (v == null) return;
              final item = items.firstWhere((i) => id(i) == v);
              onSelect(item);
              setState(() {});
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Client ────────────────────────────────────────────────
          _StepQuestion(icon: '👤', question: 'Client *'),
          const SizedBox(height: 10),
          if (_clients.isEmpty)
            _InfoBox(
              icon: Icons.info_outline,
              color: AppColors.orange,
              text: 'Aucun client trouvé. Créez d\'abord un client dans l\'onglet Clients.',
            )
          else
            _dropdown(
              items: _clients,
              value: widget.data.clientId,
              hint: '— Sélectionner un client —',
              label: (c) => c['nom'] as String,
              id: (c) => c['id'] as String,
              onSelect: (c) => _selectClient(c as Map),
            ),

          const SizedBox(height: 20),

          // ── Marché ────────────────────────────────────────────────
          _StepQuestion(icon: '🤝', question: 'Marché *'),
          const SizedBox(height: 10),
          if (widget.data.clientId == null)
            const _InfoBox(
              icon: Icons.info_outline,
              color: AppColors.s400,
              text: 'Sélectionnez d\'abord un client pour voir ses marchés.',
            )
          else if (_markets.isEmpty)
            _InfoBox(
              icon: Icons.warning_amber_outlined,
              color: AppColors.orange,
              text: 'Aucun marché pour ce client. Créez-en un dans l\'onglet Marchés.',
            )
          else
            _dropdown(
              items: _markets,
              value: widget.data.marketId,
              hint: '— Sélectionner un marché —',
              label: (m) {
                final num = m['numero'] as String? ?? '';
                final desc = m['description'] as String? ?? '';
                return desc.isNotEmpty ? '$num – $desc' : num;
              },
              id: (m) => m['id'] as String,
              onSelect: (m) => _selectMarket(m as Map),
            ),

          const SizedBox(height: 20),

          // ── Date ──────────────────────────────────────────────────
          _StepQuestion(icon: '📅', question: 'Date de la facture'),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _pickDate,
            child: AbsorbPointer(
              child: _WizardField(
                controller: _dateCtrl,
                label: 'Date',
                icon: Icons.calendar_today_outlined,
                onChanged: (_) {},
              ),
            ),
          ),

          // ── Indicateur de validation ──────────────────────────────
          const SizedBox(height: 20),
          if (widget.data.clientId != null && widget.data.marketId != null)
            _InfoBox(
              icon: Icons.check_circle_outline,
              color: AppColors.g600,
              text: '${widget.data.clientNom}  ·  ${widget.data.marketNumero ?? 'Marché sélectionné'}\nAppuyez sur "Suivant" pour continuer.',
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ÉTAPE 2 : PRESTATIONS
// ─────────────────────────────────────────────────────────────────────────────
class _StepPrestations extends StatefulWidget {
  final InvoiceWizardData data;
  final VoidCallback onChange;
  const _StepPrestations({required this.data, required this.onChange});

  @override
  State<_StepPrestations> createState() => _StepPrestationsState();
}

class _StepPrestationsState extends State<_StepPrestations> {
  final List<TextEditingController> _descCtrl = [];
  final List<TextEditingController> _mntCtrl  = [];

  static const _suggestions = [
    'Nettoyage bureaux – Mai 2026',
    'Paiement salaire ménagère',
    'Entretien locaux commerciaux',
    'Nettoyage post-chantier',
    'Placement personnel',
  ];

  @override
  void initState() {
    super.initState();
    _syncControllers();
  }

  void _syncControllers() {
    // S'assurer qu'il y a au moins une ligne
    if (widget.data.prestations.isEmpty) {
      widget.data.prestations
          .add(PrestationLine(designation: '', montant: 0));
    }
    // Créer les controllers manquants
    while (_descCtrl.length < widget.data.prestations.length) {
      final i = _descCtrl.length;
      _descCtrl.add(TextEditingController(
          text: widget.data.prestations[i].designation));
      _mntCtrl.add(TextEditingController(
          text: widget.data.prestations[i].montant > 0
              ? widget.data.prestations[i].montant.round().toString()
              : ''));
    }
  }

  void _addLine() {
    setState(() {
      widget.data.prestations
          .add(PrestationLine(designation: '', montant: 0));
      _descCtrl.add(TextEditingController());
      _mntCtrl.add(TextEditingController());
    });
  }

  void _removeLine(int index) {
    if (widget.data.prestations.length <= 1) return;
    setState(() {
      widget.data.prestations.removeAt(index);
      _descCtrl[index].dispose();
      _mntCtrl[index].dispose();
      _descCtrl.removeAt(index);
      _mntCtrl.removeAt(index);
      widget.onChange();
    });
  }

  @override
  void dispose() {
    for (final c in _descCtrl) c.dispose();
    for (final c in _mntCtrl)  c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _syncControllers();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepQuestion(
            icon: '🧹',
            question: 'Quelle(s) prestation(s) faut-il facturer ?',
          ),
          const SizedBox(height: 12),

          // Suggestions rapides
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _suggestions
                .map((s) => _QuickChip(
                  label: s,
                  onTap: () {
                    if (_descCtrl.isNotEmpty) {
                      _descCtrl.first.text = s;
                      widget.data.prestations.first =
                          widget.data.prestations.first
                              .copyWith(designation: s);
                      widget.onChange();
                      setState(() {});
                    }
                  },
                ))
                .toList(),
          ),
          const SizedBox(height: 16),

          // Lignes de prestation
          ...List.generate(widget.data.prestations.length, (i) {
            return _PrestationCard(
              index: i,
              descCtrl: _descCtrl[i],
              mntCtrl: _mntCtrl[i],
              canRemove: widget.data.prestations.length > 1,
              onDescChanged: (v) {
                widget.data.prestations[i] =
                    widget.data.prestations[i].copyWith(designation: v);
                widget.onChange();
              },
              onMntChanged: (v) {
                final n = double.tryParse(
                    v.replaceAll(' ', '').replaceAll(',', '')) ??
                    0;
                widget.data.prestations[i] =
                    widget.data.prestations[i].copyWith(montant: n);
                widget.onChange();
              },
              onRemove: () => _removeLine(i),
            );
          }),

          const SizedBox(height: 12),

          // Bouton ajouter une ligne
          OutlinedButton.icon(
            onPressed: _addLine,
            icon: const Icon(Icons.add_circle_outline, size: 18),
            label: const Text('Ajouter une prestation'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.g600,
              side: const BorderSide(color: AppColors.g400),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),

          // Sous-total live
          if (widget.data.sousTotal > 0) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.g50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.g300),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Sous-total HT',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.g700)),
                  Text(
                    Formatters.fcfa(widget.data.sousTotal),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.g700),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PrestationCard extends StatelessWidget {
  final int index;
  final TextEditingController descCtrl;
  final TextEditingController mntCtrl;
  final bool canRemove;
  final ValueChanged<String> onDescChanged;
  final ValueChanged<String> onMntChanged;
  final VoidCallback onRemove;

  const _PrestationCard({
    required this.index,
    required this.descCtrl,
    required this.mntCtrl,
    required this.canRemove,
    required this.onDescChanged,
    required this.onMntChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.s100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 6,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  color: AppColors.g100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.g700),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Prestation ${index + 1}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.s700),
                ),
              ),
              if (canRemove)
                GestureDetector(
                  onTap: onRemove,
                  child: const Icon(Icons.close,
                      size: 18, color: AppColors.s300),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: descCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Description *',
              hintText: 'Ex: Paiement salaire mois de Mai pour la ménagère',
              prefixIcon: Icon(Icons.edit_outlined, size: 18),
            ),
            onChanged: onDescChanged,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: mntCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Montant (FCFA) *',
              prefixIcon: Icon(Icons.attach_money, size: 18),
              suffixText: 'FCFA',
            ),
            onChanged: onMntChanged,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ÉTAPE 3 : RÉDUCTION
// ─────────────────────────────────────────────────────────────────────────────
class _StepReduction extends StatefulWidget {
  final InvoiceWizardData data;
  final VoidCallback onChange;
  const _StepReduction({required this.data, required this.onChange});

  @override
  State<_StepReduction> createState() => _StepReductionState();
}

class _StepReductionState extends State<_StepReduction> {
  late final TextEditingController _ctrl;

  static const _options = [0.0, 5.0, 10.0, 15.0, 20.0];

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: widget.data.reductionPct > 0
            ? widget.data.reductionPct.toStringAsFixed(0)
            : '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sousTotal = widget.data.sousTotal;
    final reduction = widget.data.montantReduction;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepQuestion(
            icon: '🏷️',
            question:
                'Y a-t-il une réduction à appliquer ?',
          ),
          const SizedBox(height: 12),

          // Boutons de sélection rapide
          Row(
            children: _options
                .map((pct) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _PercentBtn(
                      label: pct == 0 ? 'Aucune' : '${pct.toInt()}%',
                      selected: widget.data.reductionPct == pct,
                      onTap: () {
                        widget.data.reductionPct = pct;
                        _ctrl.text = pct > 0 ? pct.toStringAsFixed(0) : '';
                        widget.onChange();
                        setState(() {});
                      },
                    ),
                  ),
                ))
                .toList(),
          ),
          const SizedBox(height: 16),

          _WizardField(
            controller: _ctrl,
            label: 'Réduction en %',
            icon: Icons.percent,
            keyboardType: TextInputType.number,
            suffix: '%',
            onChanged: (v) {
              final pct =
                  double.tryParse(v.replaceAll(',', '.')) ?? 0;
              widget.data.reductionPct = pct.clamp(0, 100);
              widget.onChange();
              setState(() {});
            },
          ),

          if (sousTotal > 0 && reduction > 0) ...[
            const SizedBox(height: 16),
            _InfoBox(
              icon: Icons.savings_outlined,
              color: AppColors.orange,
              text:
                  'Réduction de ${widget.data.reductionPct.toStringAsFixed(0)}% → '
                  '− ${Formatters.fcfa(reduction)}\n'
                  'Net HT = ${Formatters.fcfa(widget.data.netHT)}',
            ),
          ],
        ],
      ),
    );
  }
}

class _PercentBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PercentBtn(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: selected ? AppColors.g600 : AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: selected ? AppColors.g600 : AppColors.s200),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: AppColors.g600.withAlpha(60),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                )
              ]
            : [],
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.white : AppColors.s700,
          ),
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// ÉTAPE 4 : TVA & RÉCAPITULATIF
// ─────────────────────────────────────────────────────────────────────────────
class _StepRecap extends StatefulWidget {
  final InvoiceWizardData data;
  final VoidCallback onChange;
  const _StepRecap({required this.data, required this.onChange});

  @override
  State<_StepRecap> createState() => _StepRecapState();
}

class _StepRecapState extends State<_StepRecap> {
  @override
  Widget build(BuildContext context) {
    final d = widget.data;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepQuestion(
            icon: '📊',
            question: 'Récapitulatif avant génération',
          ),
          const SizedBox(height: 16),

          // Toggle TVA
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.s100),
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_outlined,
                    color: AppColors.s400, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Appliquer la TVA',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                      Text('18% sur le montant net HT',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: d.applyTva,
                  activeColor: AppColors.g600,
                  onChanged: (v) {
                    setState(() => d.applyTva = v);
                    widget.onChange();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Carte récapitulatif
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.s100),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(12),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                )
              ],
            ),
            child: Column(
              children: [
                _RecapHeader(clientNom: d.clientNom, date: d.date),
                const Divider(height: 20),
                _RecapLine('Client', d.clientNom, bold: false),
                if (d.clientAdresse.isNotEmpty)
                  _RecapLine('Adresse', d.clientAdresse, bold: false),
                const Divider(height: 12),

                // Lignes prestations
                ...d.prestations.map((p) => _RecapLine(
                  p.designation.isNotEmpty ? p.designation : 'Prestation',
                  Formatters.fcfa(p.montant),
                  small: true,
                )),

                if (d.prestations.length > 1) ...[
                  const Divider(height: 8),
                  _RecapLine('Sous-total HT',
                      Formatters.fcfa(d.sousTotal)),
                ],

                if (d.reductionPct > 0) ...[
                  _RecapLine(
                    'Réduction (${d.reductionPct.toStringAsFixed(0)}%)',
                    '− ${Formatters.fcfa(d.montantReduction)}',
                    color: AppColors.red,
                  ),
                  _RecapLine('Net HT', Formatters.fcfa(d.netHT)),
                ],

                if (d.applyTva)
                  _RecapLine(
                    'TVA (18%)',
                    Formatters.fcfa(d.montantTva),
                  ),

                const Divider(height: 12),
                _RecapLine(
                  'TOTAL TTC',
                  Formatters.fcfa(d.totalTTC),
                  bold: true,
                  large: true,
                  color: AppColors.g700,
                ),
                const SizedBox(height: 8),

                // Montant en lettres
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.g50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.g300),
                  ),
                  child: Text(
                    d.totalEnLettres,
                    style: const TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: AppColors.g700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecapHeader extends StatelessWidget {
  final String clientNom;
  final DateTime date;
  const _RecapHeader({required this.clientNom, required this.date});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(clientNom.isNotEmpty ? clientNom : '—',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15)),
              Text(
                DateFormat('dd MMMM yyyy', 'fr_FR').format(date),
                style: const TextStyle(
                    fontSize: 11, color: AppColors.s400),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.g50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text('FACTURE',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: AppColors.g700)),
        ),
      ],
    );
  }
}

class _RecapLine extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final bool large;
  final bool small;
  final Color? color;

  const _RecapLine(
    this.label,
    this.value, {
    this.bold = false,
    this.large = false,
    this.small = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: small ? 11 : large ? 14 : 13,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              color: color ?? AppColors.s700,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: small ? 11 : large ? 15 : 13,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: color ?? (bold ? AppColors.s900 : AppColors.s700),
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// ÉTAPE 5 : FACTURE PRÊTE
// ─────────────────────────────────────────────────────────────────────────────
class _StepFinish extends StatefulWidget {
  final InvoiceWizardData data;
  const _StepFinish({required this.data});

  @override
  State<_StepFinish> createState() => _StepFinishState();
}

class _StepFinishState extends State<_StepFinish> {
  Uint8List? _pdfBytes;
  bool _generating = true;
  String? _error;
  CompanySettings? _settings;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  String? _savedInvoiceId;

  Future<void> _generate() async {
    setState(() { _generating = true; _error = null; });
    try {
      _settings = await CompanySettingsService.getMySettings();
      final bytes = await PdfService.generateInvoice(widget.data, settings: _settings);
      if (!mounted) return;
      setState(() { _pdfBytes = bytes; _generating = false; });
      // Sauvegarder en DB — clientId et marketId sont garantis par le wizard
      await _saveToDatabase(bytes);
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _generating = false; });
    }
  }

  Future<void> _saveToDatabase(Uint8List bytes) async {
    final d = widget.data;
    if (d.clientId == null || d.marketId == null) {
      setState(() => _error = 'Client ou marché manquant — impossible de sauvegarder.');
      return;
    }
    // 1. Créer la facture en DB
    final invoice = await InvoiceService().create(Invoice(
      id: '',
      numero: '',
      clientId: d.clientId!,
      marketId: d.marketId,
      date: d.date,
      montantHt: d.netHT,
      tvaPct: d.applyTva ? 18.0 : 0.0,
      totalTtc: d.totalTTC,
      statut: InvoiceStatut.emise,
      createdAt: DateTime.now(),
    ));
    _savedInvoiceId = invoice.id;
    if (mounted) setState(() => widget.data.numero = invoice.numero);
  }

  Future<void> _preview() async {
    if (_pdfBytes == null) return;
    await Printing.layoutPdf(onLayout: (_) async => _pdfBytes!);
  }

  Future<void> _shareWhatsApp() async {
    if (_pdfBytes == null) return;
    final d = widget.data;
    final name = _settings?.companyName.isNotEmpty == true
        ? _settings!.companyName : 'GesPro';
    final msg =
        'Bonjour,\n\nVeuillez trouver ci-joint votre facture $name.\n\n'
        '📄 Facture N° : ${d.numero}\n'
        '📅 Date : ${DateFormat('dd MMMM yyyy', 'fr_FR').format(d.date)}\n'
        '👤 Client : ${d.clientNom}\n'
        '💰 Total TTC : ${Formatters.fcfa(d.totalTTC)}\n\n'
        'Cordialement,\n$name'
        '${_settings?.telephone != null ? '\n📞 ${_settings!.telephone}' : ''}';

    if (kIsWeb) {
      // Étape 1 : télécharger le PDF sur l'appareil
      await Printing.sharePdf(
        bytes: _pdfBytes!,
        filename: '${d.numero}.pdf',
      );
      // Étape 2 : informer l'utilisateur puis ouvrir WhatsApp
      if (mounted) {
        await showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('📎 PDF téléchargé'),
            content: const Text(
              'Le PDF vient d\'être téléchargé sur votre appareil.\n\n'
              'WhatsApp va s\'ouvrir avec le message pré-rempli.\n\n'
              'Attachez le PDF téléchargé à votre message avant d\'envoyer.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  await launchUrl(
                    Uri.parse('https://wa.me/?text=${Uri.encodeComponent(msg)}'),
                    mode: LaunchMode.platformDefault,
                  );
                },
                child: const Text('Ouvrir WhatsApp'),
              ),
            ],
          ),
        );
      }
    } else {
      // Sur mobile/desktop : partage natif avec le fichier
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${d.numero}.pdf');
      await file.writeAsBytes(_pdfBytes!);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        text: msg,
      );
    }
  }

  Future<void> _shareEmail() async {
    final d = widget.data;
    final companyName = _settings?.companyName.isNotEmpty == true
        ? _settings!.companyName : 'GesPro';
    final subject = Uri.encodeComponent('Facture $companyName – ${d.numero}');
    final body = Uri.encodeComponent(
      'Bonjour,\n\nVeuillez trouver ci-joint votre facture $companyName.\n\n'
      'N° ${d.numero}\nTotal TTC : ${Formatters.fcfa(d.totalTTC)}\n\n'
      'Cordialement,\n$companyName',
    );
    final uri = Uri.parse('mailto:?subject=$subject&body=$body');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          if (_generating) ...[
            const SizedBox(height: 40),
            const CircularProgressIndicator(color: AppColors.g500),
            const SizedBox(height: 20),
            const Text('Génération du PDF en cours…',
                style: TextStyle(color: AppColors.s400)),
          ] else if (_error != null) ...[
            _InfoBox(
              icon: Icons.error_outline,
              color: AppColors.red,
              text: 'Erreur : $_error',
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _generate,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ] else ...[
            // Bannière succès
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.g700, AppColors.g500],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.g600.withAlpha(80),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Row(
                children: [
                  const Text('🎉', style: TextStyle(fontSize: 32)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Facture ${widget.data.numero} prête !',
                          style: const TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Total TTC : ${Formatters.fcfa(widget.data.totalTTC)}',
                          style: const TextStyle(
                              color: AppColors.g100, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Aperçu miniature
            if (_pdfBytes != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 200,
                  color: AppColors.s50,
                  child: PdfPreview(
                    build: (_) async => _pdfBytes!,
                    canChangeOrientation: false,
                    canChangePageFormat: false,
                    canDebug: false,
                    allowPrinting: false,
                    allowSharing: false,
                    maxPageWidth: 300,
                    pdfPreviewPageDecoration: const BoxDecoration(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Boutons d'action
            _ActionButton(
              icon: Icons.visibility_outlined,
              label: 'Aperçu / Imprimer',
              color: AppColors.s700,
              bg: AppColors.s50,
              onTap: _preview,
            ),
            const SizedBox(height: 10),
            _ActionButton(
              icon: Icons.chat_outlined,
              label: 'Partager sur WhatsApp',
              color: AppColors.white,
              bg: const Color(0xFF25D366),
              onTap: _shareWhatsApp,
            ),
            const SizedBox(height: 10),
            _ActionButton(
              icon: Icons.email_outlined,
              label: 'Envoyer par e-mail',
              color: AppColors.white,
              bg: AppColors.blue,
              onTap: _shareEmail,
            ),
            const SizedBox(height: 10),
            _ActionButton(
              icon: Icons.add_circle_outline,
              label: 'Nouvelle facture',
              color: AppColors.g700,
              bg: AppColors.g50,
              border: AppColors.g300,
              onTap: () => context.go('/invoices/new'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bg;
  final Color? border;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.bg,
    this.border,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: border != null
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: border!),
                )
              : null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
            ],
          ),
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS COMMUNS
// ─────────────────────────────────────────────────────────────────────────────
class _StepQuestion extends StatelessWidget {
  final String icon;
  final String question;
  const _StepQuestion({required this.icon, required this.question});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            question,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.s900,
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _QuickChip(
      {required this.label, this.selected = false, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? AppColors.g600 : AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: selected ? AppColors.g600 : AppColors.s200),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: selected ? AppColors.white : AppColors.s700,
        ),
      ),
    ),
  );
}

class _WizardField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData? icon;
  final String? suffix;
  final TextInputType keyboardType;
  final ValueChanged<String> onChanged;

  const _WizardField({
    required this.controller,
    required this.label,
    this.icon,
    this.suffix,
    this.keyboardType = TextInputType.text,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: keyboardType,
    onChanged: onChanged,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon, size: 20) : null,
      suffixText: suffix,
    ),
  );
}

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _InfoBox(
      {required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withAlpha(20),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withAlpha(60)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );
}
