class DaybookEntry {
  DateTime? date;
  String particulars;
  bool isIncome;
  double amount;
  bool invalid;
  String? error;
  String? categoryId;
  String? categoryName;
  String? productId;
  String? productName;

  DaybookEntry({
    this.date,
    this.particulars = '',
    this.isIncome = false,
    this.amount = 0,
    this.invalid = false,
    this.error,
    this.categoryId,
    this.categoryName,
    this.productId,
    this.productName,
  });

  bool get isValid =>
      !invalid &&
      date != null &&
      amount > 0 &&
      particulars.trim().isNotEmpty &&
      (isIncome
          ? (productId?.isNotEmpty ?? false)
          : (categoryId?.isNotEmpty ?? false));
}

class ParsedDaybook {
  final List<DaybookEntry> entries;
  const ParsedDaybook(this.entries);

  int get invalidCount => entries.where((e) => e.invalid).length;
}

class DaybookParser {
  static const _months = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'sept': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };

  static ParsedDaybook parse(String text) {
    final cleaned = text.replaceAll('\r\n', '\n').trim();
    if (cleaned.isEmpty) return const ParsedDaybook([]);

    final lines = cleaned
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    String separator = '\t';
    Map<String, int>? columns;

    for (final line in lines.take(3)) {
      if (_isHeaderLine(line)) {
        separator = line.contains('\t')
            ? '\t'
            : line.contains('|')
                ? '|'
                : '  ';
        columns = _mapHeader(line, separator);
        break;
      }
      if (line.contains('\t')) separator = '\t';
    }

    final entries = <DaybookEntry>[];
    for (final line in lines) {
      if (_isHeaderLine(line)) continue;
      if (_extractDate(line) == null) continue;

      final entry = separator == '  '
          ? _parseSpaced(line)
          : _parseColumns(line, separator, columns);
      if (entry != null) entries.add(entry);
    }
    return ParsedDaybook(entries);
  }

  static bool _isHeaderLine(String line) {
    final l = line.toLowerCase();
    return l.contains('particular') ||
        (l.contains('date') &&
            (l.contains('income') ||
                l.contains('expenditure') ||
                l.contains('expense')));
  }

  static Map<String, int>? _mapHeader(String line, String sep) {
    final cells = sep == '  '
        ? line.split(RegExp(r'\s{2,}'))
        : line.split(sep).map((c) => c.trim()).toList();
    final map = <String, int>{};
    for (var i = 0; i < cells.length; i++) {
      final h = cells[i].toLowerCase();
      if (!map.containsKey('date') && h.contains('date')) {
        map['date'] = i;
      } else if (!map.containsKey('particulars') &&
          (h.contains('particular') ||
              h.contains('detail') ||
              h.contains('descri') ||
              h.contains('narration'))) {
        map['particulars'] = i;
      } else if (!map.containsKey('income') &&
          (h.contains('income') || h.contains('receipt'))) {
        map['income'] = i;
      } else if (!map.containsKey('expenditure') &&
          (h.contains('expenditure') ||
              h.contains('expense') ||
              h.contains('payment') ||
              h.contains('disburse'))) {
        map['expenditure'] = i;
      }
    }
    if (map.containsKey('income') || map.containsKey('expenditure')) return map;
    return null;
  }

  static DaybookEntry? _parseColumns(
      String line, String sep, Map<String, int>? columns) {
    final cells = line.split(sep).map((c) => c.trim()).toList();
    if (cells.length < 3) return _parseSpaced(line);

    DateTime? date;
    String particulars = '';
    String incomeRaw = '';
    String expenseRaw = '';

    if (columns != null) {
      date = columns['date'] != null && columns['date']! < cells.length
          ? _extractDate(cells[columns['date']!])
          : _extractDate(cells.first);
      particulars =
          columns['particulars'] != null && columns['particulars']! < cells.length
              ? cells[columns['particulars']!]
              : '';
      incomeRaw = columns['income'] != null && columns['income']! < cells.length
          ? cells[columns['income']!]
          : '';
      expenseRaw = columns['expenditure'] != null &&
              columns['expenditure']! < cells.length
          ? cells[columns['expenditure']!]
          : '';
    } else {
      date = _extractDate(cells.first);
      if (cells.length >= 4) {
        particulars = cells[1];
        incomeRaw = cells[2];
        expenseRaw = cells[3];
      } else if (cells.length == 3) {
        particulars = cells[1];
        incomeRaw = cells[2];
      }
    }

    if (date == null) return null;
    if (particulars.trim().isEmpty) {
      particulars = cells.length >= 3
          ? cells[cells.length - (incomeRaw.isNotEmpty || expenseRaw.isNotEmpty ? 3 : 1)]
          : cells.skip(1).join(' ');
    }

    return _buildEntry(
      date: date,
      particulars: particulars,
      incomeRaw: incomeRaw,
      expenseRaw: expenseRaw,
    );
  }

  static DaybookEntry? _parseSpaced(String line) {
    final match = _dateMatch(line);
    if (match == null) return null;
    final date = match.date;
    final rest = line.substring(match.end).trim();
    if (rest.isEmpty) return null;

    final tokens = rest.split(RegExp(r'\s+'));
    var dashIndex = -1;
    for (var i = 0; i < tokens.length; i++) {
      if (_isDash(tokens[i])) {
        dashIndex = i;
        break;
      }
    }

    if (dashIndex >= 0) {
      final particulars = tokens.take(dashIndex).join(' ');
      final after = tokens.skip(dashIndex + 1).join(' ');
      final amount = _parseAmount(after);
      if (amount == null) {
        return DaybookEntry(
          date: date,
          particulars: particulars,
          amount: 0,
          invalid: true,
          error: 'Could not read expenditure amount',
        );
      }
      return DaybookEntry(
        date: date,
        particulars: particulars,
        isIncome: false,
        amount: amount,
      );
    }

    final amount = _parseAmount(tokens.last);
    if (amount == null) {
      return DaybookEntry(
        date: date,
        particulars: rest,
        amount: 0,
        invalid: true,
        error: 'Could not read amount',
      );
    }
    final particulars =
        tokens.length > 1 ? tokens.take(tokens.length - 1).join(' ') : rest;
    return DaybookEntry(
      date: date,
      particulars: particulars,
      isIncome: true,
      amount: amount,
    );
  }

  static DaybookEntry _buildEntry({
    required DateTime date,
    required String particulars,
    required String incomeRaw,
    required String expenseRaw,
  }) {
    final income = _parseAmount(incomeRaw);
    final expense = _parseAmount(expenseRaw);

    final incomeBad = _isNonEmpty(incomeRaw) && income == null;
    final expenseBad = _isNonEmpty(expenseRaw) && expense == null;

    if (incomeBad || expenseBad) {
      return DaybookEntry(
        date: date,
        particulars: particulars,
        amount: 0,
        invalid: true,
        error: 'Amount cell is not a plain number — edit or delete',
      );
    }

    final inc = income ?? 0;
    final exp = expense ?? 0;

    if (inc > 0 && exp > 0) {
      return DaybookEntry(
        date: date,
        particulars: particulars,
        amount: 0,
        invalid: true,
        error: 'Amount in both Income and Expenditure — edit or delete',
      );
    }
    if (inc > 0) {
      return DaybookEntry(
          date: date, particulars: particulars, isIncome: true, amount: inc);
    }
    if (exp > 0) {
      return DaybookEntry(
          date: date, particulars: particulars, isIncome: false, amount: exp);
    }
    return DaybookEntry(
      date: date,
      particulars: particulars,
      amount: 0,
      invalid: true,
      error: 'No amount found — edit or delete',
    );
  }

  static bool _isNonEmpty(String raw) {
    final s = raw.trim();
    return s.isNotEmpty && !_isDash(s);
  }

  static bool _isDash(String s) {
    final t = s.trim();
    return t == '—' || t == '–' || t == '-' || t == '―';
  }

  static double? _parseAmount(String raw) {
    final s = raw.trim();
    if (s.isEmpty || _isDash(s)) return null;
    if (s.contains(RegExp(r'[a-zA-Z]'))) return null;

    final cleaned = s.replaceAll(RegExp(r'[₹$,\s]'), '');
    if (cleaned.isEmpty) return null;
    if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(cleaned)) return null;
    final n = double.tryParse(cleaned);
    if (n == null || n < 0) return null;
    return n;
  }

  static ({DateTime date, int end})? _dateMatch(String text) {
    final mmm =
        RegExp(r'^(\d{1,2})-([A-Za-z]{3,4})-(\d{4})').firstMatch(text.trim());
    if (mmm != null) {
      final day = int.tryParse(mmm.group(1)!) ?? 0;
      final mon = _months[mmm.group(2)!.toLowerCase()];
      final year = int.tryParse(mmm.group(3)!) ?? 0;
      if (mon != null && day >= 1 && day <= 31) {
        return (
          date: DateTime(year, mon, day),
          end: mmm.group(0)!.length + (text.length - text.trimLeft().length),
        );
      }
    }

    final iso =
        RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(text.trim());
    if (iso != null) {
      final y = int.tryParse(iso.group(1)!);
      final mo = int.tryParse(iso.group(2)!);
      final d = int.tryParse(iso.group(3)!);
      if (y != null && mo != null && d != null && mo >= 1 && mo <= 12) {
        return (
          date: DateTime(y, mo, d),
          end: iso.group(0)!.length + (text.length - text.trimLeft().length),
        );
      }
    }

    final dmy =
        RegExp(r'^(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})').firstMatch(text.trim());
    if (dmy != null) {
      var day = int.tryParse(dmy.group(1)!) ?? 0;
      var month = int.tryParse(dmy.group(2)!) ?? 0;
      var year = int.tryParse(dmy.group(3)!) ?? 0;
      if (year < 100) year += 2000;
      if (month > 12 && day <= 12) {
        final t = day;
        day = month;
        month = t;
      }
      if (day >= 1 && day <= 31 && month >= 1 && month <= 12) {
        return (
          date: DateTime(year, month, day),
          end: dmy.group(0)!.length + (text.length - text.trimLeft().length),
        );
      }
    }
    return null;
  }

  static DateTime? _extractDate(String text) => _dateMatch(text)?.date;
}
