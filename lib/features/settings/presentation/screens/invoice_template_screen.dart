import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/business_helper.dart';

class InvoiceTemplateScreen extends StatefulWidget {
  const InvoiceTemplateScreen({super.key});

  @override
  State<InvoiceTemplateScreen> createState() => _InvoiceTemplateScreenState();
}

class _InvoiceTemplateScreenState extends State<InvoiceTemplateScreen> {
  final _prefix = TextEditingController(text: 'INV');
  final _terms = TextEditingController(text: 'Thank you for your business!');
  final _footer = TextEditingController(text: 'This is a computer-generated invoice.');
  final _bankDetails = TextEditingController(text: '');
  final _logoUrl = TextEditingController(text: '');
  bool _showGst = true;
  bool _showBankDetails = true;
  bool _showSignature = true;
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

      // Load invoice prefix from businesses table
      final bizFuture = Supabase.instance.client
          .from('businesses')
          .select('invoice_prefix, logo_url')
          .eq('id', bizId)
          .single();

      // Load invoice template settings from app_settings
      final settingsFuture = Supabase.instance.client
          .from('app_settings')
          .select('setting_value')
          .eq('business_id', bizId)
          .eq('setting_key', 'invoice_template')
          .maybeSingle();

      final results = await Future.wait([bizFuture, settingsFuture]);
      final biz = results[0] as Map<String, dynamic>;
      final settings = results[1] as Map<String, dynamic>?;

      if (mounted) {
        setState(() {
          _prefix.text = biz['invoice_prefix'] ?? 'INV';
          _logoUrl.text = biz['logo_url'] ?? '';

          if (settings != null) {
            final val = settings['setting_value'] as Map<String, dynamic>;
            _terms.text = val['terms'] as String? ?? 'Thank you for your business!';
            _footer.text = val['footer'] as String? ?? 'This is a computer-generated invoice.';
            _bankDetails.text = val['bank_details'] as String? ?? '';
            _showGst = val['show_gst'] as bool? ?? true;
            _showBankDetails = val['show_bank_details'] as bool? ?? true;
            _showSignature = val['show_signature'] as bool? ?? true;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (_businessId == null) return;
    setState(() => _isSaving = true);
    try {
      // Save invoice prefix to businesses table
      await Supabase.instance.client.from('businesses').update({
        'invoice_prefix': _prefix.text.trim().isEmpty ? 'INV' : _prefix.text.trim(),
        'logo_url': _logoUrl.text.trim().isEmpty ? null : _logoUrl.text.trim(),
      }).eq('id', _businessId!);

      // Save template settings to app_settings
      final settingsData = {
        'terms': _terms.text.trim(),
        'footer': _footer.text.trim(),
        'bank_details': _bankDetails.text.trim(),
        'show_gst': _showGst,
        'show_bank_details': _showBankDetails,
        'show_signature': _showSignature,
      };

      await Supabase.instance.client.from('app_settings').upsert({
        'business_id': _businessId,
        'setting_key': 'invoice_template',
        'setting_value': settingsData,
      }, onConflict: 'business_id,setting_key');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice template saved!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _prefix.dispose();
    _terms.dispose();
    _footer.dispose();
    _bankDetails.dispose();
    _logoUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Invoice Template')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Invoice Settings', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        _field('Invoice Prefix', _prefix),
                        Text('Invoices will be numbered as ${_prefix.text}-001, ${_prefix.text}-002, etc.',
                            style: TextStyle(fontSize: 12, color: cs.outline)),
                        const SizedBox(height: 12),
                        _field('Logo URL (optional)', _logoUrl),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Content', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        _field('Terms & Conditions', _terms),
                        _field('Footer Text', _footer),
                        _field('Bank Details (for payment)', _bankDetails),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Visibility', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        SwitchListTile(title: const Text('Show GST Details'), value: _showGst, onChanged: (v) => setState(() => _showGst = v), dense: true, contentPadding: EdgeInsets.zero),
                        SwitchListTile(title: const Text('Show Bank Details'), value: _showBankDetails, onChanged: (v) => setState(() => _showBankDetails = v), dense: true, contentPadding: EdgeInsets.zero),
                        SwitchListTile(title: const Text('Show Signature Line'), value: _showSignature, onChanged: (v) => setState(() => _showSignature = v), dense: true, contentPadding: EdgeInsets.zero),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Invoice Preview', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: cs.outline.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(child: Text('${_prefix.text}-001', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                              const Divider(height: 24),
                              const Text('Business Name', style: TextStyle(fontWeight: FontWeight.w600)),
                              const Text('Phone, Email', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              const Divider(height: 24),
                              if (_showGst) ...[
                                const Text('GST: 09XXXXX1234X1Z5', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                const SizedBox(height: 8),
                              ],
                              const Text('Subtotal: ₹1,000.00', style: TextStyle(fontSize: 13)),
                              if (_showGst) const Text('GST (18%): ₹180.00', style: TextStyle(fontSize: 13)),
                              const Divider(),
                              const Text('Total: ₹1,180.00', style: TextStyle(fontWeight: FontWeight.w700)),
                              if (_showBankDetails && _bankDetails.text.isNotEmpty) ...[
                                const Divider(height: 24),
                                Text(_bankDetails.text, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                              ],
                              if (_showSignature) ...[
                                const SizedBox(height: 24),
                                Align(alignment: Alignment.centerRight, child: Column(children: [
                                  Container(width: 120, height: 1, color: Colors.grey),
                                  const Text('Authorized Signatory', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                ])),
                              ],
                              if (_terms.text.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                Center(child: Text(_terms.text, style: const TextStyle(fontSize: 11, color: Colors.grey))),
                              ],
                              if (_footer.text.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Center(child: Text(_footer.text, style: const TextStyle(fontSize: 10, color: Colors.grey))),
                              ],
                            ],
                          ),
                        ),
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
                    label: Text(_isSaving ? 'Saving...' : 'Save Template'),
                    style: ElevatedButton.styleFrom(backgroundColor: cs.primary, foregroundColor: cs.onPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _field(String label, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(controller: ctrl, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true)),
    );
  }
}
