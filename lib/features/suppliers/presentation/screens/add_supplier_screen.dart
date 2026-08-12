import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/business_helper.dart';

class AddSupplierScreen extends StatefulWidget {
  final String? supplierId;
  const AddSupplierScreen({super.key, this.supplierId});

  @override
  State<AddSupplierScreen> createState() => _AddSupplierScreenState();
}

class _AddSupplierScreenState extends State<AddSupplierScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _whatsapp = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _pincode = TextEditingController();
  final _gst = TextEditingController();
  final _openingBalance = TextEditingController(text: '0');
  final _notes = TextEditingController();
  bool _isLoading = false;
  bool _isSaving = false;

  bool get isEditing => widget.supplierId != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) _loadSupplier();
  }

  Future<void> _loadSupplier() async {
    setState(() => _isLoading = true);
    try {
      final data = await Supabase.instance.client.from('suppliers').select().eq('id', widget.supplierId!).single();
      if (mounted) {
        setState(() {
          _name.text = data['name'] ?? '';
          _phone.text = data['phone'] ?? '';
          _whatsapp.text = data['whatsapp_phone'] ?? '';
          _email.text = data['email'] ?? '';
          _address.text = data['address'] ?? '';
          _city.text = data['city'] ?? '';
          _state.text = data['state'] ?? '';
          _pincode.text = data['pincode'] ?? '';
          _gst.text = data['gst_number'] ?? '';
          _openingBalance.text = (data['opening_balance'] as num?)?.toString() ?? '0';
          _notes.text = data['notes'] ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final bizId = await BusinessHelper.getOrCreateBusinessId();
      final data = {
        'business_id': bizId,
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'whatsapp_phone': _whatsapp.text.trim().isEmpty ? null : _whatsapp.text.trim(),
        'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
        'address': _address.text.trim().isEmpty ? null : _address.text.trim(),
        'city': _city.text.trim().isEmpty ? null : _city.text.trim(),
        'state': _state.text.trim().isEmpty ? null : _state.text.trim(),
        'pincode': _pincode.text.trim().isEmpty ? null : _pincode.text.trim(),
        'gst_number': _gst.text.trim().isEmpty ? null : _gst.text.trim(),
        'opening_balance': double.tryParse(_openingBalance.text) ?? 0,
        'current_balance': double.tryParse(_openingBalance.text) ?? 0,
        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      };
      if (isEditing) {
        await Supabase.instance.client.from('suppliers').update(data).eq('id', widget.supplierId!);
      } else {
        await Supabase.instance.client.from('suppliers').insert(data);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEditing ? 'Supplier updated!' : 'Supplier added!'),
          backgroundColor: Colors.green,
        ));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _whatsapp, _email, _address, _city, _state, _pincode, _gst, _openingBalance, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit Supplier' : 'Add Supplier')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _section('Contact', [
                    _field('Supplier Name *', _name, required: true),
                    _field('Phone *', _phone, type: TextInputType.phone, required: true),
                    _field('WhatsApp', _whatsapp, type: TextInputType.phone),
                    _field('Email', _email, type: TextInputType.emailAddress),
                  ]),
                  _section('Address', [
                    _field('Address', _address, maxLines: 2),
                    Row(children: [
                      Expanded(child: _field('City', _city)),
                      const SizedBox(width: 12),
                      Expanded(child: _field('State', _state)),
                    ]),
                    _field('Pincode', _pincode, type: TextInputType.number),
                  ]),
                  _section('Business', [
                    _field('GST Number', _gst),
                    _field('Opening Balance', _openingBalance, type: TextInputType.number, prefix: '₹ '),
                    _field('Notes', _notes, maxLines: 2),
                  ]),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_circle),
                      label: Text(_isSaving ? 'Saving...' : (isEditing ? 'Update Supplier' : 'Add Supplier')),
                      style: ElevatedButton.styleFrom(backgroundColor: cs.primary, foregroundColor: cs.onPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {TextInputType? type, int maxLines = 1, String? prefix, bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        keyboardType: type,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true, prefixText: prefix),
        validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null,
      ),
    );
  }
}
