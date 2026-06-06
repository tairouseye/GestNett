import '../../core/utils/formatters.dart';

class PrestationLine {
  String designation;
  double montant;

  PrestationLine({required this.designation, required this.montant});

  PrestationLine copyWith({String? designation, double? montant}) =>
      PrestationLine(
        designation: designation ?? this.designation,
        montant: montant ?? this.montant,
      );
}

class InvoiceWizardData {
  String clientNom;
  String clientAdresse;
  String? clientId;    // ID Supabase du client sélectionné
  String? marketId;    // Marché associé (obligatoire)
  String? marketNumero; // Numéro du marché pour affichage
  List<PrestationLine> prestations;
  double reductionPct;
  bool applyTva;
  DateTime date;
  String numero;

  InvoiceWizardData({
    this.clientNom = '',
    this.clientAdresse = '',
    this.clientId,
    this.marketId,
    this.marketNumero,
    List<PrestationLine>? prestations,
    this.reductionPct = 0,
    this.applyTva = false,
    DateTime? date,
    String? numero,
  })  : prestations = prestations ?? [PrestationLine(designation: '', montant: 0)],
        date = date ?? DateTime.now(),
        numero = numero ?? _generateNumero();

  static String _generateNumero() {
    final year = DateTime.now().year;
    final seq = DateTime.now().millisecondsSinceEpoch % 1000;
    return 'FAC-$year-${seq.toString().padLeft(3, '0')}';
  }

  // ─── Calculs ───────────────────────────────────────────────────────────────

  double get sousTotal =>
      prestations.fold(0.0, (sum, p) => sum + p.montant);

  double get montantReduction => sousTotal * reductionPct / 100;

  double get netHT => sousTotal - montantReduction;

  double get montantTva => applyTva ? netHT * 0.18 : 0;

  double get totalTTC => netHT + montantTva;

  // ─── Montant en lettres (sur le total TTC) ─────────────────────────────────
  String get totalEnLettres => Formatters.montantEnLettres(totalTTC);

  bool get isValid =>
      clientNom.trim().isNotEmpty &&
      clientId != null &&
      marketId != null &&
      prestations.isNotEmpty &&
      prestations.every((p) => p.designation.trim().isNotEmpty && p.montant > 0);
}
