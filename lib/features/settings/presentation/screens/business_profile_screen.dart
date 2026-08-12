import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/business_helper.dart';

class BusinessProfileScreen extends StatefulWidget {
  const BusinessProfileScreen({super.key});

  @override
  State<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _ownerName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _pincode = TextEditingController();
  final _gst = TextEditingController();
  final _pan = TextEditingController();
  final _currency = TextEditingController(text: 'INR');
  final _currencySymbol = TextEditingController(text: '₹');
  bool _isLoading = true;
  bool _isSaving = false;
  String? _businessId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final bizId = await BusinessHelper.getOrCreateBusinessId();
      _businessId = bizId;
      final data = await Supabase.instance.client.from('businesses').select().eq('id', bizId).single();
      if (mounted) {
        setState(() {
          _name.text = data['name'] ?? '';
          _ownerName.text = data['owner_name'] ?? '';
          _phone.text = data['phone'] ?? '';
          _email.text = data['email'] ?? '';
          _address.text = data['address'] ?? '';
          _city.text = data['city'] ?? '';
          _state.text = data['state'] ?? '';
          _pincode.text = data['pincode'] ?? '';
          _gst.text = data['gst_number'] ?? '';
          _pan.text = data['pan_number'] ?? '';
          _currency.text = data['currency'] ?? 'INR';
          _currencySymbol.text = data['currency_symbol'] ?? '₹';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _businessId == null) return;
    setState(() => _isSaving = true);
    try {
      await Supabase.instance.client.from('businesses').update({
        'name': _name.text.trim(),
        'owner_name': _ownerName.text.trim(),
        'phone': _phone.text.trim(),
        'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
        'address': _address.text.trim().isEmpty ? null : _address.text.trim(),
        'city': _city.text.trim().isEmpty ? null : _city.text.trim(),
        'state': _state.text.trim().isEmpty ? null : _state.text.trim(),
        'pincode': _pincode.text.trim().isEmpty ? null : _pincode.text.trim(),
        'gst_number': _gst.text.trim().isEmpty ? null : _gst.text.trim(),
        'pan_number': _pan.text.trim().isEmpty ? null : _pan.text.trim(),
        'currency': _currency.text.trim().isEmpty ? 'INR' : _currency.text.trim(),
        'currency_symbol': _currencySymbol.text.trim().isEmpty ? '₹' : _currencySymbol.text.trim(),
      }).eq('id', _businessId!);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Business profile updated!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _ownerName, _phone, _email, _address, _city, _state, _pincode, _gst, _pan, _currency, _currencySymbol]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Business Profile'), actions: [IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh))]),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Business Info', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          _field('Business Name *', _name, required: true),
                          _field('Owner Name *', _ownerName, required: true),
                          _field('Phone *', _phone, type: TextInputType.phone, required: true),
                          _field('Email', _email, type: TextInputType.emailAddress),
                        ],
                      ),
                    ),
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Address', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          _field('Address', _address, maxLines: 2),
                          Row(children: [
                            Expanded(child: _field('City', _city)),
                            const SizedBox(width: 12),
                            Expanded(child: _field('State', _state)),
                          ]),
                          _field('Pincode', _pincode, type: TextInputType.number),
                        ],
                      ),
                    ),
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tax & Currency', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          _field('GST Number', _gst),
                          _field('PAN Number', _pan),
                          Row(children: [
                            Expanded(child: _field('Currency', _currency)),
                            const SizedBox(width: 12),
                            Expanded(child: _field('Symbol', _currencySymbol)),
                          ]),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
                      label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                      style: ElevatedButton.styleFrom(backgroundColor: cs.primary, foregroundColor: cs.onPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {TextInputType? type, int maxLines = 1, bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl, keyboardType: type, maxLines: maxLines,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
        validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null,
      ),
    );
  }
}
