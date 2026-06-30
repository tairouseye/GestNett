import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:gespro/models/invoice.dart';
import 'package:gespro/models/recurrence.dart';
import 'package:gespro/services/recurrence_service.dart';
import 'package:gespro/core/utils/formatters.dart';

final _d = DateTime(2026, 1, 1);

void main() {
  setUpAll(() async {
    // Formats fr_FR utilisés par Formatters.
    await initializeDateFormatting('fr_FR', null);
  });

  group('Invoice — calculs financiers', () {
    test('montantTva = montantHt * tva / 100', () {
      final inv = Invoice(
        id: '1', numero: 'X', clientId: 'c',
        date: _d, montantHt: 100000, tvaPct: 18, totalTtc: 118000,
        statut: InvoiceStatut.emise, createdAt: _d,
      );
      expect(inv.montantTva, closeTo(18000, 0.001));
    });

    test('echeance = date + 30 jours quand dateEcheance absente', () {
      final inv = Invoice(
        id: '1', numero: 'X', clientId: 'c',
        date: DateTime(2026, 6, 1), montantHt: 0, totalTtc: 0,
        statut: InvoiceStatut.emise, createdAt: DateTime(2026, 6, 1),
      );
      expect(inv.echeance, DateTime(2026, 7, 1));
    });

    test('echeance = dateEcheance quand fournie', () {
      final inv = Invoice(
        id: '1', numero: 'X', clientId: 'c',
        date: DateTime(2026, 6, 1), montantHt: 0, totalTtc: 0,
        statut: InvoiceStatut.emise,
        dateEcheance: DateTime(2026, 6, 15),
        createdAt: DateTime(2026, 6, 1),
      );
      expect(inv.echeance, DateTime(2026, 6, 15));
    });

    test('isProforma selon typeFacture', () {
      Invoice mk(String t) => Invoice(
            id: '1', numero: 'X', clientId: 'c', date: _d,
            montantHt: 0, totalTtc: 0, statut: InvoiceStatut.emise,
            typeFacture: t, createdAt: _d,
          );
      expect(mk('proforma').isProforma, isTrue);
      expect(mk('definitive').isProforma, isFalse);
    });

    test('toInsertMap arrondit les montants a l entier', () {
      final inv = Invoice(
        id: '', numero: 'X', clientId: 'c', date: _d,
        montantHt: 99999.6, totalTtc: 117999.4,
        statut: InvoiceStatut.emise, createdAt: _d,
      );
      final m = inv.toInsertMap();
      expect(m['montant_ht'], 100000);
      expect(m['total_ttc'], 117999);
    });
  });

  group('InvoiceStatut — sérialisation', () {
    test('value / fromValue round-trip pour tous les statuts', () {
      for (final s in InvoiceStatut.values) {
        expect(InvoiceStatutExt.fromValue(s.value), s,
            reason: 'round-trip ${s.value}');
      }
    });

    test('payee_partiel est bien géré (régression contrainte CHECK)', () {
      expect(InvoiceStatut.payeePartiel.value, 'payee_partiel');
      expect(InvoiceStatutExt.fromValue('payee_partiel'),
          InvoiceStatut.payeePartiel);
    });

    test('valeur inconnue → brouillon par défaut', () {
      expect(InvoiceStatutExt.fromValue('???'), InvoiceStatut.brouillon);
    });
  });

  group('Recurrence — totalTtc & fréquences', () {
    test('totalTtc applique la TVA', () {
      final r = Recurrence(
        id: '1', marketId: 'm', clientId: 'c',
        montantHt: 200000, tvaPct: 18,
        prochaineDate: _d, createdAt: _d,
      );
      expect(r.totalTtc, closeTo(236000, 0.001));
    });

    test('mois par fréquence', () {
      expect(Frequence.mensuelle.mois, 1);
      expect(Frequence.trimestrielle.mois, 3);
      expect(Frequence.annuelle.mois, 12);
    });

    test('Frequence.fromValue défaut mensuelle', () {
      expect(FrequenceExt.fromValue('annuelle'), Frequence.annuelle);
      expect(FrequenceExt.fromValue('inconnu'), Frequence.mensuelle);
    });
  });

  group('RecurrenceService.addMonths — bornage du jour', () {
    test('mensuel simple', () {
      expect(RecurrenceService.addMonths(DateTime(2026, 1, 15), 1, 15),
          DateTime(2026, 2, 15));
    });

    test('passage d annee (décembre +1)', () {
      expect(RecurrenceService.addMonths(DateTime(2026, 12, 10), 1, 10),
          DateTime(2027, 1, 10));
    });

    test('trimestriel', () {
      expect(RecurrenceService.addMonths(DateTime(2026, 1, 5), 3, 5),
          DateTime(2026, 4, 5));
    });

    test('annuel', () {
      expect(RecurrenceService.addMonths(DateTime(2026, 3, 1), 12, 1),
          DateTime(2027, 3, 1));
    });

    test('jour borné au dernier jour du mois cible (31 vers 28 février)', () {
      expect(RecurrenceService.addMonths(DateTime(2026, 1, 31), 1, 31),
          DateTime(2026, 2, 28));
    });

    test('février bissextile (31 vers 29)', () {
      expect(RecurrenceService.addMonths(DateTime(2028, 1, 31), 1, 31),
          DateTime(2028, 2, 29));
    });
  });

  group('Formatters', () {
    test('fcfa formate avec séparateur de milliers et arrondi', () {
      // intl fr_FR utilise des espaces insécables : on normalise tout espace
      // Unicode en espace ASCII avant comparaison.
      final s = Formatters.fcfa(1234567.4).replaceAll(RegExp(r'\s'), ' ');
      expect(s, '1 234 567 FCFA');
    });

    test('montantEnLettres — exemples', () {
      // Note : le code écrit toujours « francs » au pluriel (le cas singulier
      // « Zéro franc » est inatteignable car _nombreEnLettres(0) = 'zéro').
      expect(Formatters.montantEnLettres(0), 'Zéro francs CFA.');
      expect(Formatters.montantEnLettres(21), startsWith('Vingt'));
    });
  });
}
