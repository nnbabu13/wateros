import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/business_helper.dart';

class AddCustomerScreen extends StatefulWidget {
  final String? customerId;

  const AddCustomerScreen({super.key, this.customerId});

  @override
  State<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _openingBalanceController = TextEditingController(text: '0');
  final _creditLimitController = TextEditingController(text: '0');
  final _gstController = TextEditingController();
  final _notesController = TextEditingController();

  bool get isEditing => widget.customerId != null;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (isEditing) _loadCustomer();
  }

  Future<void> _loadCustomer() async {
    try {
      final data = await Supabase.instance.client
          .from('customers')
          .select()
          .eq('id', widget.customerId!)
          .single();

      if (mounted) {
        setState(() {
          _nameController.text = data['name'] as String? ?? '';
          _phoneController.text = data['phone'] as String? ?? '';
          _whatsappController.text = data['whatsapp_phone'] as String? ?? '';
          _emailController.text = data['email'] as String? ?? '';
          _addressController.text = data['address'] as String? ?? '';
          _cityController.text = data['city'] as String? ?? '';
          _stateController.text = data['state'] as String? ?? '';
          _pincodeController.text = data['pincode'] as String? ?? '';
          _openingBalanceController.text =
              (data['opening_balance'] as num?)?.toString() ?? '0';
          _creditLimitController.text =
              (data['credit_limit'] as num?)?.toString() ?? '0';
          _gstController.text = data['gst_number'] as String? ?? '';
          _notesController.text = data['notes'] as String? ?? '';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load customer: $e')),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final businessId = await BusinessHelper.getOrCreateBusinessId();

      final data = {
        'business_id': businessId,
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'whatsapp_phone':
            _whatsappController.text.isEmpty ? null : _whatsappController.text.trim(),
        'email': _emailController.text.isEmpty ? null : _emailController.text.trim(),
        'address': _addressController.text.isEmpty ? null : _addressController.text.trim(),
        'city': _cityController.text.isEmpty ? null : _cityController.text.trim(),
        'state': _stateController.text.isEmpty ? null : _stateController.text.trim(),
        'pincode': _pincodeController.text.isEmpty ? null : _pincodeController.text.trim(),
        'opening_balance': double.tryParse(_openingBalanceController.text) ?? 0,
        'current_balance': double.tryParse(_openingBalanceController.text) ?? 0,
        'credit_limit': double.tryParse(_creditLimitController.text) ?? 0,
        'gst_number': _gstController.text.isEmpty ? null : _gstController.text.trim(),
        'notes': _notesController.text.isEmpty ? null : _notesController.text.trim(),
        'is_active': true,
      };

      if (isEditing) {
        await Supabase.instance.client
            .from('customers')
            .update(data)
            .eq('id', widget.customerId!);
      } else {
        await Supabase.instance.client.from('customers').insert(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? 'Customer updated!' : 'Customer added!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _openingBalanceController.dispose();
    _creditLimitController.dispose();
    _gstController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Customer' : 'Add Customer'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name *',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone *',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a phone number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _whatsappController,
              decoration: const InputDecoration(
                labelText: 'WhatsApp',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Address',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cityController,
                    decoration: const InputDecoration(
                      labelText: 'City',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _stateController,
                    decoration: const InputDecoration(
                      labelText: 'State',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _pincodeController,
                    decoration: const InputDecoration(
                      labelText: 'Pincode',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _gstController,
                    decoration: const InputDecoration(
                      labelText: 'GST Number',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _openingBalanceController,
                    decoration: const InputDecoration(
                      labelText: 'Opening Balance',
                      border: OutlineInputBorder(),
                      prefixText: '₹ ',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _creditLimitController,
                    decoration: const InputDecoration(
                      labelText: 'Credit Limit',
                      border: OutlineInputBorder(),
                      prefixText: '₹ ',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isEditing ? 'Update Customer' : 'Save Customer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
