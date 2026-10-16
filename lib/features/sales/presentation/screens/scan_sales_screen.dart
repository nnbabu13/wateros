import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/business_helper.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../data/models/ocr_sale_row.dart';
import '../../data/pasted_table_parser.dart';
import '../../data/sale_save_helper.dart';

enum _ScanStep { pick, extracting, review }

enum _InputMode { photo, paste }

class ScanSalesScreen extends ConsumerStatefulWidget {
  const ScanSalesScreen({super.key});

  @override
  ConsumerState<ScanSalesScreen> createState() => _ScanSalesScreenState();
}

class _ScanSalesScreenState extends ConsumerState<ScanSalesScreen> {
  final _picker = ImagePicker();
  final _pasteController = TextEditingController();

  _ScanStep _step = _ScanStep.pick;
  _InputMode _inputMode = _InputMode.photo;
  XFile? _image;
  Uint8List? _imageBytes;
  String? _extractError;
  List<OcrSaleRow> _rows = [];
  DateTime _invoiceDate = DateTime.now();
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _allProducts = [];
  bool _isLoadingData = true;
  bool _isImporting = false;
  int _importCurrent = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _pasteController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoadingData = false);
        return;
      }

      final businessId = await BusinessHelper.getOrCreateBusinessId();

      final customersFuture = Supabase.instance.client
          .from('customers')
          .select('id, name, phone, current_balance')
          .eq('business_id', businessId)
          .eq('is_active', true)
          .order('name');

      final productsFuture = Supabase.instance.client
          .from('products')
          .select('id, name, sku, selling_price, purchase_price, gst_rate, current_stock, unit, product_type')
          .eq('business_id', businessId)
          .eq('is_active', true)
          .order('name');

      final results = await Future.wait([customersFuture, productsFuture]);

      if (mounted) {
        final allProducts = List<Map<String, dynamic>>.from(results[1]);
        setState(() {
          _customers = List<Map<String, dynamic>>.from(results[0]);
          _allProducts =
              allProducts.where((p) => p['product_type'] == 'finished_product').toList();
          _isLoadingData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingData = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load data: $e')),
        );
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 60,
        maxWidth: 1600,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      setState(() {
        _image = picked;
        _imageBytes = bytes;
        _extractError = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  Future<void> _extract() async {
    final image = _image;
    final bytes = _imageBytes;
    if (image == null || bytes == null) return;

    setState(() {
      _step = _ScanStep.extracting;
      _extractError = null;
    });

    try {
      final base64Image = base64Encode(bytes);
      final mimeType =
          (image.mimeType != null && image.mimeType!.isNotEmpty)
              ? image.mimeType!
              : 'image/jpeg';

      final response = await Supabase.instance.client.functions.invoke(
        'extract-sales',
        body: {
          'image_base64': base64Image,
          'mime_type': mimeType,
        },
      );

      if (response.status >= 400) {
        var msg = 'Could not read the image. Please try again.';
        final data = response.data;
        if (data is Map && data['error'] != null) {
          msg = data['error'].toString();
          final detail = data['detail'];
          if (detail != null && detail.toString().trim().isNotEmpty) {
            msg = '$msg\n${detail.toString()}';
          }
        }
        throw Exception(msg);
      }

      dynamic data = response.data;
      if (data is String) {
        data = jsonDecode(data);
      }
      if (data is! Map) {
        throw Exception('Unexpected response from the scanner.');
      }

      final dateStr = data['date'] as String? ?? '';
      final parsed = <OcrSaleRow>[];
      final rawRows = data['rows'];
      if (rawRows is List) {
        for (final r in rawRows) {
          if (r is! Map) continue;
          parsed.add(OcrSaleRow(
            time: (r['time'] as String?) ?? '',
            productText: (r['product'] as String?) ?? '',
            quantity: (r['quantity'] as num?)?.toDouble() ?? 0,
            amount: (r['amount'] as num?)?.toDouble() ?? 0,
            paid: r['paid'] == true,
            customerText: (r['customer'] as String?) ?? '',
          ));
        }
      }

      if (!mounted) return;

      if (parsed.isEmpty) {
        setState(() {
          _step = _ScanStep.pick;
          _extractError =
              'No sales rows found in this image. Try a clearer, well-lit photo of the register page.';
        });
        return;
      }

      DateTime date = DateTime.now();
      final parsedDate = DateTime.tryParse(dateStr);
      if (parsedDate != null) date = parsedDate;

      setState(() {
        _invoiceDate = date;
        _rows = parsed;
        _matchRows();
        _step = _ScanStep.review;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _step = _ScanStep.pick;
        _extractError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _parsePastedText() {
    final text = _pasteController.text;
    if (text.trim().isEmpty) {
      setState(() {
        _extractError =
            'Paste the table from ChatGPT first, then tap Parse entries.';
      });
      return;
    }

    final result = PastedTableParser.parse(text);
    if (result.rows.isEmpty) {
      setState(() {
        _extractError =
            'No sale rows found in the pasted text. Ask ChatGPT for a markdown table with columns like Time, Product, Qty, Amount, Paid, Customer.';
      });
      return;
    }

    setState(() {
      _rows = result.rows;
      if (result.date != null) _invoiceDate = result.date!;
      _extractError = null;
      _step = _ScanStep.review;
    });
    _matchRows();
  }

  String _normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '').trim();

  Map<String, dynamic>? _matchProduct(String text) {
    final n = _normalize(text);
    if (n.isEmpty) return null;
    for (final p in _allProducts) {
      if (_normalize(p['name'] as String? ?? '') == n) return p;
    }
    for (final p in _allProducts) {
      final pn = _normalize(p['name'] as String? ?? '');
      if (pn.isEmpty) continue;
      if (pn.contains(n) || n.contains(pn)) return p;
    }
    return null;
  }

  Map<String, dynamic>? _matchCustomer(String text) {
    final n = _normalize(text);
    if (n.isEmpty) return null;
    for (final c in _customers) {
      if (_normalize(c['name'] as String? ?? '') == n) return c;
    }
    for (final c in _customers) {
      final cn = _normalize(c['name'] as String? ?? '');
      if (cn.isEmpty) continue;
      if (cn.contains(n) || n.contains(cn)) return c;
    }
    return null;
  }

  void _matchRows() {
    for (final row in _rows) {
      final p = _matchProduct(row.productText);
      if (p != null) {
        row.productId = p['id'] as String;
        row.productName = p['name'] as String;
        row.unitPrice = (p['selling_price'] as num?)?.toDouble() ?? 0;
        row.gstRate = 0;
      }
      final c = _matchCustomer(row.customerText);
      if (c != null) row.customerId = c['id'] as String;
    }
  }

  double get _paidTotal =>
      _rows.where((r) => r.paid).fold(0, (s, r) => s + r.amount);
  double get _creditTotal =>
      _rows.where((r) => !r.paid).fold(0, (s, r) => s + r.amount);
  int get _paidCount => _rows.where((r) => r.paid).length;
  int get _creditCount => _rows.where((r) => !r.paid).length;
  bool get _allRowsValid => _rows.isNotEmpty && _rows.every((r) => r.isValid);

  void _addRow() {
    setState(() => _rows.add(OcrSaleRow(paid: true)));
    _editRow(_rows.length - 1);
  }

  void _removeRow(int index) {
    setState(() => _rows.removeAt(index));
  }

  void _showFullImage() {
    final bytes = _imageBytes;
    if (bytes == null) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: InteractiveViewer(
          child: Image.memory(bytes, fit: BoxFit.contain),
        ),
      ),
    );
  }

  void _showProductPicker(int rowIndex) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ProductPickerSheet(
        products: _allProducts,
        onSelect: (product) {
          Navigator.pop(ctx);
          setState(() {
            _rows[rowIndex].productId = product['id'] as String;
            _rows[rowIndex].productName = product['name'] as String;
            _rows[rowIndex].unitPrice =
                (product['selling_price'] as num?)?.toDouble() ?? 0;
            _rows[rowIndex].gstRate = 0;
          });
        },
      ),
    );
  }

  Future<void> _editRow(int index) async {
    final row = _rows[index];
    var productId = row.productId;
    var productName = row.productName;
    var quantityText = row.quantity.toString();
    var amountText = row.amount > 0 ? row.amount.toStringAsFixed(0) : '';
    var paid = row.paid;
    var timeText = row.time;
    var customerText = row.customerText;
    String? customerId = row.customerId;

    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: StatefulBuilder(
          builder: (ctx, setSheetState) {
            final cs = Theme.of(ctx).colorScheme;
            return SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Edit Entry',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: productId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Product *',
                        border: OutlineInputBorder(),
                      ),
                      items: _allProducts
                          .map((p) => DropdownMenuItem(
                                value: p['id'] as String,
                                child: Text(
                                  p['name'] as String,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Select a product' : null,
                      onChanged: (v) {
                        setSheetState(() {
                          productId = v;
                          final match = _allProducts.where((p) => p['id'] == v);
                          productName = match.isNotEmpty
                              ? (match.first['name'] as String)
                              : '';
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: customerText,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Customer name',
                        hintText: 'Leave empty for Walk-in',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) {
                        customerText = v;
                        customerId = null;
                      },
                    ),
                    if (customerId == null &&
                        customerText.trim().isNotEmpty &&
                        _matchCustomer(customerText)?['id'] != null) ...[
                      const SizedBox(height: 8),
                      _MatchingChip(
                        text:
                            'Will link to existing customer ${_matchCustomer(customerText)!['name']}',
                        color: cs.primary,
                        icon: Icons.link,
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: quantityText,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d*')),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Quantity *',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) {
                              final d = double.tryParse(v ?? '');
                              if (d == null || d <= 0) return 'Invalid qty';
                              return null;
                            },
                            onChanged: (v) => quantityText = v,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            initialValue: amountText,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d*')),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Amount *',
                              prefixText: '₹ ',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) {
                              final d = double.tryParse(v ?? '');
                              if (d == null || d <= 0) return 'Invalid amount';
                              return null;
                            },
                            onChanged: (v) => amountText = v,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: timeText,
                      decoration: const InputDecoration(
                        labelText: 'Time (optional)',
                        hintText: 'e.g. 11:00',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => timeText = v,
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      value: paid,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Paid (cash received)'),
                      subtitle:
                          const Text('If off, the sale is on credit (unpaid)'),
                      onChanged: (v) => setSheetState(() => paid = v),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          if (!(formKey.currentState?.validate() ?? false)) {
                            return;
                          }
                          setState(() {
                            row.productId = productId;
                            row.productName = productName;
                            row.quantity =
                                double.tryParse(quantityText) ?? row.quantity;
                            row.amount =
                                double.tryParse(amountText) ?? row.amount;
                            row.paid = paid;
                            row.time = timeText.trim();
                            row.customerText = customerText.trim();
                            row.customerId = customerId;
                            row.gstRate = 0;
                          });
                          Navigator.pop(ctx);
                        },
                        child: const Text('Save Entry'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<String> _resolveCustomerId(OcrSaleRow row, String businessId) async {
    if (row.customerId != null && row.customerId!.isNotEmpty) {
      return row.customerId!;
    }

    final name = row.customerText.trim();
    if (name.isEmpty) {
      var walkIn = await Supabase.instance.client
          .from('customers')
          .select('id')
          .eq('business_id', businessId)
          .eq('name', 'Walk-in')
          .eq('is_active', true)
          .maybeSingle();
      if (walkIn == null) {
        walkIn = await Supabase.instance.client
            .from('customers')
            .insert({
              'business_id': businessId,
              'name': 'Walk-in',
              'phone': '0000000000',
              'is_active': true,
            })
            .select('id')
            .single();
      }
      return walkIn['id'] as String;
    }

    final existing = await Supabase.instance.client
        .from('customers')
        .select('id')
        .eq('business_id', businessId)
        .eq('name', name)
        .eq('is_active', true)
        .maybeSingle();
    if (existing != null) return existing['id'] as String;

    final created = await Supabase.instance.client
        .from('customers')
        .insert({
          'business_id': businessId,
          'name': name,
          'phone': '0000000000',
          'is_active': true,
        })
        .select('id')
        .single();
    return created['id'] as String;
  }

  Future<void> _importRows() async {
    if (!_allRowsValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fix incomplete entries before importing'),
        ),
      );
      return;
    }

    final cs = Theme.of(context).colorScheme;
    final confirm = await ConfirmDialog.show(
      context: context,
      title: 'Import ${_rows.length} sales?',
      message:
          '$_paidCount paid in cash (₹ ${_paidTotal.toStringAsFixed(0)}) and '
          '$_creditCount on credit (₹ ${_creditTotal.toStringAsFixed(0)}). '
          'Stock and customer balances will be updated.',
      confirmText: 'Import',
      confirmColor: cs.primary,
      cancelText: 'Cancel',
    );
    if (!confirm) return;

    setState(() {
      _isImporting = true;
      _importCurrent = 0;
    });

    final failures = <String>[];
    var success = 0;

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final businessId = await BusinessHelper.getOrCreateBusinessId();

      for (var i = 0; i < _rows.length; i++) {
        final row = _rows[i];
        if (mounted) setState(() => _importCurrent = i + 1);
        try {
          final customerId = await _resolveCustomerId(row, businessId);
          final unitPrice = row.amount / row.quantity;
          final notes = row.time.isNotEmpty
              ? 'Time ${row.time} - Scanned from register'
              : 'Scanned from register';

          await SaleSaveHelper.createSale(
            businessId: businessId,
            customerId: customerId,
            invoiceDate: _invoiceDate,
            items: [
              SaleLineInput(
                productId: row.productId!,
                productName: (row.productName == null ||
                        row.productName!.isEmpty)
                    ? row.productText
                    : row.productName!,
                quantity: row.quantity,
                unitPrice: unitPrice,
                discountPercent: 0,
                gstRate: 0,
              ),
            ],
            payments: row.paid
                ? [SalePaymentInput(mode: 'cash', amount: row.amount)]
                : const [],
            notes: notes,
          );
          success++;
        } catch (e) {
          final label = row.customerText.isNotEmpty
              ? row.customerText
              : (row.productName ?? row.productText);
          failures.add('$label: ${e.toString().replaceFirst('Exception: ', '')}');
        }
      }
    } catch (e) {
      failures.add(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }

    if (!mounted) return;

    if (success > 0) {
      if (failures.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imported $success sales successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Imported $success of ${_rows.length}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${failures.length} entries failed and were skipped:',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  ...failures.map((f) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('• $f',
                            style: TextStyle(
                                fontSize: 13, color: cs.error)),
                      )),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        if (mounted) Navigator.of(context).pop(true);
      }
    } else {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Import failed'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: failures
                  .map((f) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('• $f',
                            style: TextStyle(fontSize: 13, color: cs.error)),
                      ))
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(switch (_step) {
          _ScanStep.pick => 'Scan Register',
          _ScanStep.extracting => 'Reading Page...',
          _ScanStep.review => 'Review Entries',
        }),
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : switch (_step) {
              _ScanStep.pick => _buildPickBody(cs),
              _ScanStep.extracting => _buildExtractingBody(cs),
              _ScanStep.review => _buildReviewBody(cs),
            },
      bottomNavigationBar: _step == _ScanStep.review && _rows.isNotEmpty
          ? _buildImportBar(cs)
          : null,
    );
  }

  Widget _buildPickBody(ColorScheme cs) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_extractError != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: cs.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: cs.error, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _extractError!,
                    style: TextStyle(color: cs.error, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        SegmentedButton<_InputMode>(
          segments: const [
            ButtonSegment(
              value: _InputMode.photo,
              icon: Icon(Icons.camera_alt_outlined),
              label: Text('Photo'),
            ),
            ButtonSegment(
              value: _InputMode.paste,
              icon: Icon(Icons.content_paste_outlined),
              label: Text('Paste table'),
            ),
          ],
          selected: {_inputMode},
          onSelectionChanged: (s) => setState(() {
            _inputMode = s.first;
            _extractError = null;
          }),
        ),
        const SizedBox(height: 16),
        if (_inputMode == _InputMode.paste) _buildPasteSection(cs) else _buildPhotoSection(cs),
      ],
    );
  }

  Widget _buildPasteSection(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(Icons.chat_outlined, size: 48, color: cs.primary),
                const SizedBox(height: 12),
                const Text(
                  'Ask ChatGPT to convert your register photo into a table.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  'Example prompt: "Convert this sales register photo into a markdown table with columns Time, Product, Qty, Amount, Paid, Customer"',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _pasteController,
          maxLines: 10,
          minLines: 6,
          decoration: const InputDecoration(
            hintText:
                'Paste the table here...\n\n| Time | Product | Qty | Amount | Paid | Customer |\n| 10:30 | Bags | 50 | 1900 | Yes | Durga rao |',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _parsePastedText,
            icon: const Icon(Icons.table_chart_outlined),
            label: const Text('Parse entries'),
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoSection(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(Icons.document_scanner_outlined,
                    size: 48, color: cs.primary),
                const SizedBox(height: 12),
                const Text(
                  'Photograph a handwritten register page and the AI will read the sales rows for you.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  'You can review and correct every entry before importing.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_imageBytes != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              _imageBytes!,
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: _showFullImage,
              icon: const Icon(Icons.zoom_out_map, size: 18),
              label: const Text('View full image'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _extract,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Extract Sales with AI'),
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Retake'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Gallery'),
                ),
              ),
            ],
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Camera'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Gallery'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildExtractingBody(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              'Reading register page...',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'This may take a moment.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            if (_imageBytes != null) ...[
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  _imageBytes!,
                  height: 160,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReviewBody(ColorScheme cs) {
    return Column(
      children: [
        Card(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: ListTile(
            leading: _imageBytes != null
                ? GestureDetector(
                    onTap: _showFullImage,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        _imageBytes!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                : const Icon(Icons.receipt_long),
            title: const Text('Register date'),
            subtitle: Text(DateFormat('dd MMM yyyy').format(_invoiceDate)),
            trailing: const Icon(Icons.edit_calendar, size: 20),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _invoiceDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 1)),
              );
              if (picked != null) setState(() => _invoiceDate = picked);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                '${_rows.length} entries found',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                'Paid: $_paidCount  ·  Credit: $_creditCount',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: _rows.length + 1,
            itemBuilder: (context, index) {
              if (index == _rows.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton.icon(
                    onPressed: _addRow,
                    icon: const Icon(Icons.add),
                    label: const Text('Add missed row'),
                  ),
                );
              }
              return _buildRowCard(_rows[index], index, cs);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRowCard(OcrSaleRow row, int index, ColorScheme cs) {
    final productLabel = row.productName != null && row.productName!.isNotEmpty
        ? row.productName!
        : row.productText;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _editRow(index),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (row.time.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(row.time,
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w500)),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: row.needsProductMatch
                        ? InkWell(
                            onTap: () => _showProductPicker(index),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: cs.error.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.warning_amber_rounded,
                                      size: 16, color: cs.error),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      'Select product (${row.productText})',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: cs.error),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Text(
                            productLabel,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    tooltip: 'Edit',
                    onPressed: () => _editRow(index),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        size: 20, color: cs.error),
                    tooltip: 'Remove',
                    onPressed: () => _removeRow(index),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    '${_formatQty(row.quantity)} × ₹ ${row.amount.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 13),
                  ),
                  if (row.unitPrice > 0 &&
                      row.quantity > 0) ...[
                    const SizedBox(width: 6),
                    Text(
                      '(@ ₹ ${(row.amount / row.quantity).toStringAsFixed(2)})',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: (row.paid ? Colors.green : Colors.orange)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      row.paid ? 'Paid' : 'Credit',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: row.paid
                            ? Colors.green.shade700
                            : Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _customerChip(_customerDisplayLabel(row), cs,
                  isNew: row.isNewCustomer),
            ],
          ),
        ),
      ),
    );
  }

  String _formatQty(double q) =>
      q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toString();

  String _customerDisplayLabel(OcrSaleRow row) {
    if (row.customerId != null) {
      for (final c in _customers) {
        if (c['id'] == row.customerId) return c['name'] as String;
      }
      return row.customerText.isNotEmpty ? row.customerText : 'Customer';
    }
    if (row.customerText.trim().isEmpty) return 'Walk-in';
    return row.customerText;
  }

  Widget _customerChip(String name, ColorScheme cs, {required bool isNew}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (isNew ? Colors.orange : cs.primary).withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isNew ? Icons.person_add_alt_1 : Icons.person,
            size: 14,
            color: isNew ? Colors.orange.shade800 : cs.primary,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              isNew ? '$name (new)' : name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isNew ? Colors.orange.shade800 : cs.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportBar(ColorScheme cs) {
    final invalidCount = _rows.where((r) => !r.isValid).length;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: cs.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isImporting) ...[
              LinearProgressIndicator(
                value: _importCurrent / _rows.length,
              ),
              const SizedBox(height: 8),
              Text('Importing $_importCurrent of ${_rows.length}...'),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '₹ ${_paidTotal.toStringAsFixed(0)} paid  ·  '
                      '₹ ${_creditTotal.toStringAsFixed(0)} credit',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ),
                  if (invalidCount > 0)
                    Text(
                      '$invalidCount incomplete',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: cs.error),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _allRowsValid ? _importRows : null,
                  icon: const Icon(Icons.check_circle),
                  label: Text('Import ${_rows.length} sales'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MatchingChip extends StatelessWidget {
  final String text;
  final Color color;
  final IconData icon;

  const _MatchingChip({
    required this.text,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: color))),
        ],
      ),
    );
  }
}

class _ProductPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> products;
  final Function(Map<String, dynamic>) onSelect;

  const _ProductPickerSheet({
    required this.products,
    required this.onSelect,
  });

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.products.where((p) {
      final name = (p['name'] as String? ?? '').toLowerCase();
      final sku = (p['sku'] as String? ?? '').toLowerCase();
      final q = _search.toLowerCase();
      return name.contains(q) || sku.contains(q);
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollController) {
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search products...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: (val) => setState(() => _search = val),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: filtered.length,
                itemBuilder: (ctx, index) {
                  final product = filtered[index];
                  final stock =
                      (product['current_stock'] as num?)?.toDouble() ?? 0;
                  final price =
                      (product['selling_price'] as num?)?.toDouble() ?? 0;
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        (product['name'] as String)[0].toUpperCase(),
                      ),
                    ),
                    title: Text(product['name'] as String),
                    subtitle: Text(
                      '₹ ${price.toStringAsFixed(2)} | Stock: ${stock.toStringAsFixed(0)}',
                    ),
                    onTap: () => widget.onSelect(product),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
