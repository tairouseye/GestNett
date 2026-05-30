import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static final _cfaFmt = NumberFormat('#,##0', 'fr_FR');
  static final _dateFmt = DateFormat('dd MMM yyyy', 'fr_FR');
  static final _dateShort = DateFormat('dd/MM/yyyy');

  static String fcfa(num value) => '${_cfaFmt.format(value.round())} FCFA';

  static String date(DateTime d) => _dateFmt.format(d);

  static String dateShort(DateTime d) => _dateShort.format(d);

  static String? dateOrNull(DateTime? d) => d == null ? null : date(d);

  // Convertit un nombre en lettres (FCFA)
  static String montantEnLettres(num valeur) {
    final texte = _nombreEnLettres(valeur.round());
    if (texte.isEmpty) return 'Zéro franc CFA.';
    return '${texte[0].toUpperCase()}${texte.substring(1)} francs CFA.';
  }

  static String _nombreEnLettres(int n) {
    if (n == 0) return 'zéro';
    if (n < 0) return 'moins ${_nombreEnLettres(-n)}';

    const u = ['', 'un', 'deux', 'trois', 'quatre', 'cinq', 'six', 'sept',
      'huit', 'neuf', 'dix', 'onze', 'douze', 'treize', 'quatorze', 'quinze',
      'seize', 'dix-sept', 'dix-huit', 'dix-neuf'];
    const d = ['', '', 'vingt', 'trente', 'quarante', 'cinquante', 'soixante',
      'soixante', 'quatre-vingt', 'quatre-vingt'];

    final buf = StringBuffer();

    if (n >= 1000000) {
      buf.write('${_nombreEnLettres(n ~/ 1000000)} million');
      if (n ~/ 1000000 > 1) buf.write('s');
      buf.write(' ');
      n %= 1000000;
    }
    if (n >= 1000) {
      final m = n ~/ 1000;
      if (m > 1) buf.write('${_nombreEnLettres(m)} ');
      buf.write('mille ');
      n %= 1000;
    }
    if (n >= 100) {
      final c = n ~/ 100;
      if (c > 1) buf.write('${u[c]} ');
      buf.write('cent');
      if (c > 1 && n % 100 == 0) buf.write('s');
      buf.write(' ');
      n %= 100;
    }
    if (n >= 20) {
      final di = n ~/ 10;
      final un = n % 10;
      if (di == 7 || di == 9) {
        buf.write('${d[di]}-${un < 10 && (10 + un) < u.length ? u[10 + un] : u[un]}');
      } else {
        buf.write(d[di]);
        if (un > 0) buf.write('-${u[un]}');
        if (di == 8 && un == 0) buf.write('s');
      }
    } else if (n > 0) {
      buf.write(u[n]);
    }

    return buf.toString().trim();
  }

  static String numeroFacture(int seq) =>
      'FAC-${DateTime.now().year}-${seq.toString().padLeft(3, '0')}';

  static String numeroMarche(int seq) =>
      'MRK-${DateTime.now().year}-${seq.toString().padLeft(3, '0')}';
}
