import 'models/ocr_sale_row.dart';

class ParsedTableResult {
  final List<OcrSaleRow> rows;
  final DateTime? date;

  const ParsedTableResult({required this.rows, this.date});
}

class PastedTableParser {
  static ParsedTableResult parse(String text) {
    final cleaned = text.replaceAll('\r\n', '\n').trim();
    if (cleaned.isEmpty) {
      return const ParsedTableResult(rows: []);
    }

    final date = _extractDate(cleaned);
    final lines = cleaned
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final tableLines = <String>[];
    for (final line in lines) {
      if (_isTableLine(line)) tableLines.add(line);
    }

    if (tableLines.length < 2) {
      return ParsedTableResult(rows: _parseDelimitedLines(lines), date: date);
    }

    final cellsPerLine = tableLines.map(_splitCells).toList();
    var headerIndex = -1;
    Map<String, int>? columns;

    for (var i = 0; i < cellsPerLine.length; i++) {
      final map = _mapHeader(cellsPerLine[i]);
      if (map != null && map.length >= 3) {
        headerIndex = i;
        columns = map;
        break;
      }
    }

    final rows = <OcrSaleRow>[];
    String lastTime = '';

    final start = headerIndex >= 0 ? headerIndex + 1 : 0;
    for (var i = start; i < cellsPerLine.length; i++) {
      final cells = cellsPerLine[i];
      if (_isSeparatorRow(cells)) continue;

      final OcrSaleRow? row = columns != null
          ? _rowFromMapped(cells, columns, lastTime)
          : _rowFromPositional(cells, lastTime);
      if (row == null) continue;
      if (row.time.isNotEmpty) lastTime = row.time;
      rows.add(row);
    }

    return ParsedTableResult(rows: rows, date: date);
  }

  static bool _isTableLine(String line) {
    if (line.startsWith('|') && line.contains('|', 1)) return true;
    if (line.split('\t').length >= 4) return true;
    if (line.split(';').length >= 4 && !line.contains(',')) return true;
    return false;
  }

  static List<String> _splitCells(String line) {
    List<String> cells;
    if (line.contains('|')) {
      cells = line
          .split('|')
          .map((c) => c
              .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ')
              .trim())
          .toList();
      if (cells.isNotEmpty && cells.first.isEmpty) cells.removeAt(0);
      if (cells.isNotEmpty && cells.last.isEmpty) cells.removeLast();
    } else if (line.contains('\t')) {
      cells = line.split('\t').map((c) => c.trim()).toList();
    } else {
      cells = line.split(RegExp(r'\s{2,}')).map((c) => c.trim()).toList();
    }
    return cells;
  }

  static bool _isSeparatorRow(List<String> cells) {
    return cells.every((c) => c.isEmpty || RegExp(r'^[-: ]+$').hasMatch(c));
  }

  static Map<String, int>? _mapHeader(List<String> cells) {
    final map = <String, int>{};
    for (var i = 0; i < cells.length; i++) {
      final h = cells[i].toLowerCase().replaceAll(RegExp(r'[^a-z ]'), '').trim();
      if (h.isEmpty) continue;
      if (!map.containsKey('time') && h.contains('time')) {
        map['time'] = i;
      } else if (!map.containsKey('product') &&
          (h.contains('product') ||
              h.contains('detail') ||
              h.contains('item') ||
              h.contains('descri') ||
              h.contains('particular'))) {
        map['product'] = i;
      } else if (!map.containsKey('qty') &&
          (h.contains('qty') ||
              h.contains('quant') ||
              h == 'no' ||
              h.contains('count'))) {
        map['qty'] = i;
      } else if (!map.containsKey('amount') &&
          (h.contains('amount') ||
              h.contains('cash') ||
              h.contains('total') ||
              h.contains('price') ||
              h.contains('money') ||
              h.contains('credit') ||
              h.contains('rs') ||
              h.contains('rupee'))) {
        map['amount'] = i;
      } else if (!map.containsKey('paid') &&
          (h.contains('paid') ||
              h.contains('status') ||
              h.contains('payment') ||
              h.contains('settled') ||
              h.contains('unpaid'))) {
        map['paid'] = i;
      } else if (!map.containsKey('customer') &&
          (h.contains('customer') ||
              h.contains('party') ||
              h.contains('name') ||
              h.contains('client'))) {
        map['customer'] = i;
      }
    }
    if (map.containsKey('product') &&
        map.containsKey('qty') &&
        map.containsKey('amount')) {
      return map;
    }
    return null;
  }

  static OcrSaleRow? _rowFromMapped(
    List<String> cells,
    Map<String, int> columns,
    String lastTime,
  ) {
    String cell(String key) {
      final idx = columns[key];
      if (idx == null || idx >= cells.length) return '';
      return cells[idx].trim();
    }

    var time = cell('time');
    if (!RegExp(r'^\d{1,2}:\d{2}').hasMatch(time)) {
      time = RegExp(r'\d{1,2}:\d{2}').firstMatch(time)?.group(0) ?? '';
    }
    if (time.isEmpty) time = lastTime;

    final product = cell('product').replaceAll(RegExp(r'\*+$'), '').trim();
    final quantity = _parseNumber(cell('qty'));
    var amount = _parseNumber(cell('amount'));
    if (amount <= 0) {
      for (final c in cells) {
        amount = _parseNumber(c);
        if (amount > 0) break;
      }
    }

    final paidCell = cell('paid');
    final customer = _cleanCustomer(cell('customer'));
    final paid = _isPaid(paidCell) ||
        (_isPaid(customer) && !_looksLikeCredit(paidCell));

    if (_isHeaderProduct(product) || _isTotalRow(product, customer)) {
      return null;
    }
    if (product.isEmpty || quantity <= 0 || amount <= 0) return null;

    return OcrSaleRow(
      time: time,
      productText: product,
      quantity: quantity,
      amount: amount,
      paid: paid && !_looksLikeCredit(paidCell),
      customerText: _stripPaidWords(customer),
    );
  }

  static OcrSaleRow? _rowFromPositional(List<String> cells, String lastTime) {
    if (cells.length < 4) return null;
    if (_isSeparatorRow(cells)) return null;

    var time = '';
    var product = '';
    var qty = 0.0;
    var amount = 0.0;
    var paidRaw = '';
    var customer = '';

    final timeMatch = RegExp(r'^\d{1,2}:\d{2}').firstMatch(cells[0]);
    var idx = 0;
    if (timeMatch != null) {
      time = timeMatch.group(0)!;
      idx = 1;
    } else {
      time = lastTime;
    }

    product = cells[idx].trim();
    if (idx + 1 < cells.length) qty = _parseNumber(cells[idx + 1]);
    if (idx + 2 < cells.length) amount = _parseNumber(cells[idx + 2]);

    final rest = cells.skip(idx + 3).toList();
    if (rest.isNotEmpty) {
      paidRaw = rest.first;
      if (rest.length > 1) {
        customer = rest.sublist(1).join(' ');
      } else {
        customer = rest.first;
        paidRaw = _looksLikeCredit(customer) || _isPaid(customer)
            ? customer
            : '';
        if (!_isPaid(paidRaw) && !_looksLikeCredit(paidRaw)) {
          customer = rest.first;
          paidRaw = '';
        }
      }
    }

    if (_isHeaderProduct(product) || _isTotalRow(product, customer)) {
      return null;
    }
    if (product.isEmpty || qty <= 0 || amount <= 0) return null;

    final paid = _isPaid(paidRaw) && !_looksLikeCredit(paidRaw);

    return OcrSaleRow(
      time: time,
      productText: product,
      quantity: qty,
      amount: amount,
      paid: paid,
      customerText: _stripPaidWords(_cleanCustomer(customer)),
    );
  }

  static List<OcrSaleRow> _parseDelimitedLines(List<String> lines) {
    final rows = <OcrSaleRow>[];
    String lastTime = '';
    for (final line in lines) {
      if (!_isTableLine(line)) continue;
      final cells = _splitCells(line);
      if (_isSeparatorRow(cells)) continue;
      final header = _mapHeader(cells);
      if (header != null) continue;
      final row = _rowFromPositional(cells, lastTime);
      if (row == null) continue;
      if (row.time.isNotEmpty) lastTime = row.time;
      rows.add(row);
    }
    return rows;
  }

  static DateTime? _extractDate(String text) {
    final m = RegExp(r'(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})').firstMatch(text);
    if (m == null) return null;
    var day = int.tryParse(m.group(1)!) ?? 0;
    var month = int.tryParse(m.group(2)!) ?? 0;
    var year = int.tryParse(m.group(3)!) ?? 0;
    if (year < 100) year += 2000;
    if (month > 12 && day <= 12) {
      final t = day;
      day = month;
      month = t;
    }
    if (day < 1 || day > 31 || month < 1 || month > 12) return null;
    try {
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  static double _parseNumber(String raw) {
    final cleaned = raw
        .replaceAll(RegExp(r'[₹$,\s]'), '')
        .replaceAll(RegExp(r'[^\d.\-]'), '');
    if (cleaned.isEmpty || cleaned == '-' || cleaned == '.') return 0;
    final n = double.tryParse(cleaned);
    if (n == null) return 0;
    return n < 0 ? 0 : n;
  }

  static bool _isPaid(String cell) {
    final c = cell.toLowerCase().trim();
    if (c.isEmpty) return false;
    if (c.contains('unpaid') || c.contains('credit') || c.contains('due')) {
      return false;
    }
    return c.contains('paid') ||
        c.contains('received') ||
        c == 'yes' ||
        c == 'y' ||
        c == 'cash';
  }

  static bool _looksLikeCredit(String cell) {
    final c = cell.toLowerCase();
    return c.contains('credit') || c.contains('unpaid') || c.contains('due');
  }

  static String _cleanCustomer(String raw) {
    var s = raw.trim();
    s = s.replaceAll(RegExp(r'\*+$'), '').trim();
    return s;
  }

  static String _stripPaidWords(String customer) {
    return customer
        .replaceAll(RegExp(r'\b(paid|unpaid|credit|cash)\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
  }

  static bool _isHeaderProduct(String product) {
    final p = product.toLowerCase();
    return p == 'product' ||
        p == 'details' ||
        p == 'item' ||
        p == 'particulars' ||
        p == 'description';
  }

  static bool _isTotalRow(String product, String customer) {
    final joined = '$product $customer'.toLowerCase();
    return joined.contains('total') ||
        joined.contains('carry') ||
        RegExp(r'^\d+\s*(bags?|pcs|nos)$').hasMatch(product.toLowerCase().trim());
  }
}
