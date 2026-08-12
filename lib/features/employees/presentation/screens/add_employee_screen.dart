import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/business_helper.dart';

class AddEmployeeScreen extends StatefulWidget {
  final String? employeeId;
  const AddEmployeeScreen({super.key, this.employeeId});

  @override
  State<AddEmployeeScreen> createState() => _AddEmployeeScreenState();
}

class _AddEmployeeScreenState extends State<AddEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _designation = TextEditingController();
  final _department = TextEditingController();
  final _salary = TextEditingController();
  final _bankName = TextEditingController();
  final _bankAccount = TextEditingController();
  final _ifsc = TextEditingController();
  final _pan = TextEditingController();
  final _aadhar = TextEditingController();
  final _emergencyContact = TextEditingController();
  final _emergencyName = TextEditingController();
  final _employeeCode = TextEditingController();
  DateTime _dateOfJoining = DateTime.now();
  DateTime? _dateOfBirth;
  bool _isLoading = false;
  bool _isSaving = false;

  bool get isEditing => widget.employeeId != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) _loadEmployee();
  }

  Future<void> _loadEmployee() async {
    setState(() => _isLoading = true);
    try {
      final data = await Supabase.instance.client.from('employees').select().eq('id', widget.employeeId!).single();
      if (mounted) {
        setState(() {
          _name.text = data['name'] ?? '';
          _phone.text = data['phone'] ?? '';
          _email.text = data['email'] ?? '';
          _address.text = data['address'] ?? '';
          _city.text = data['city'] ?? '';
          _designation.text = data['designation'] ?? '';
          _department.text = data['department'] ?? '';
          _salary.text = (data['basic_salary'] as num?)?.toString() ?? '';
          _bankName.text = data['bank_name'] ?? '';
          _bankAccount.text = data['bank_account_number'] ?? '';
          _ifsc.text = data['ifsc_code'] ?? '';
          _pan.text = data['pan_number'] ?? '';
          _aadhar.text = data['aadhar_number'] ?? '';
          _emergencyContact.text = data['emergency_contact'] ?? '';
          _emergencyName.text = data['emergency_contact_name'] ?? '';
          _employeeCode.text = data['employee_code'] ?? '';
          if (data['date_of_joining'] != null) _dateOfJoining = DateTime.parse(data['date_of_joining']);
          if (data['date_of_birth'] != null) _dateOfBirth = DateTime.parse(data['date_of_birth']);
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
        'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
        'address': _address.text.trim().isEmpty ? null : _address.text.trim(),
        'city': _city.text.trim().isEmpty ? null : _city.text.trim(),
        'designation': _designation.text.trim().isEmpty ? null : _designation.text.trim(),
        'department': _department.text.trim().isEmpty ? null : _department.text.trim(),
        'basic_salary': double.tryParse(_salary.text) ?? 0,
        'bank_name': _bankName.text.trim().isEmpty ? null : _bankName.text.trim(),
        'bank_account_number': _bankAccount.text.trim().isEmpty ? null : _bankAccount.text.trim(),
        'ifsc_code': _ifsc.text.trim().isEmpty ? null : _ifsc.text.trim(),
        'pan_number': _pan.text.trim().isEmpty ? null : _pan.text.trim(),
        'aadhar_number': _aadhar.text.trim().isEmpty ? null : _aadhar.text.trim(),
        'emergency_contact': _emergencyContact.text.trim().isEmpty ? null : _emergencyContact.text.trim(),
        'emergency_contact_name': _emergencyName.text.trim().isEmpty ? null : _emergencyName.text.trim(),
        'employee_code': _employeeCode.text.trim().isEmpty ? null : _employeeCode.text.trim(),
        'date_of_joining': DateFormat('yyyy-MM-dd').format(_dateOfJoining),
        'date_of_birth': _dateOfBirth != null ? DateFormat('yyyy-MM-dd').format(_dateOfBirth!) : null,
      };
      if (isEditing) {
        await Supabase.instance.client.from('employees').update(data).eq('id', widget.employeeId!);
      } else {
        await Supabase.instance.client.from('employees').insert(data);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEditing ? 'Employee updated!' : 'Employee added!'),
          backgroundColor: Colors.green,
        ));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickDate({required bool isDob}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isDob ? (_dateOfBirth ?? DateTime(1995)) : _dateOfJoining,
      firstDate: DateTime(1970),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isDob) {
          _dateOfBirth = picked;
        } else {
          _dateOfJoining = picked;
        }
      });
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _address, _city, _designation, _department, _salary,
      _bankName, _bankAccount, _ifsc, _pan, _aadhar, _emergencyContact, _emergencyName, _employeeCode]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit Employee' : 'Add Employee')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _section('Personal Info', [
                    _field('Full Name *', _name, required: true),
                    Row(children: [
                      Expanded(child: _field('Phone *', _phone, type: TextInputType.phone, required: true)),
                      const SizedBox(width: 12),
                      Expanded(child: _field('Email', _email, type: TextInputType.emailAddress)),
                    ]),
                    _field('Address', _address, maxLines: 2),
                    Row(children: [
                      Expanded(child: _field('City', _city)),
                      const SizedBox(width: 12),
                      Expanded(child: _field('Employee Code', _employeeCode)),
                    ]),
                  ]),
                  _section('Employment', [
                    _field('Designation', _designation),
                    _field('Department', _department),
                    _field('Salary', _salary, type: TextInputType.number, prefix: '₹ '),
                    _dateField('Date of Joining', _dateOfJoining, () => _pickDate(isDob: false)),
                    _dateField('Date of Birth', _dateOfBirth, () => _pickDate(isDob: true)),
                  ]),
                  _section('Bank Details', [
                    _field('Bank Name', _bankName),
                    _field('Account Number', _bankAccount),
                    _field('IFSC Code', _ifsc),
                  ]),
                  _section('Documents', [
                    Row(children: [
                      Expanded(child: _field('PAN', _pan)),
                      const SizedBox(width: 12),
                      Expanded(child: _field('Aadhar', _aadhar, type: TextInputType.number)),
                    ]),
                  ]),
                  _section('Emergency Contact', [
                    _field('Contact Name', _emergencyName),
                    _field('Contact Phone', _emergencyContact, type: TextInputType.phone),
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
                      label: Text(_isSaving ? 'Saving...' : (isEditing ? 'Update Employee' : 'Add Employee')),
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
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          prefixText: prefix,
        ),
        validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null,
      ),
    );
  }

  Widget _dateField(String label, DateTime? value, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        child: InputDecorator(
          decoration: const InputDecoration(labelText: '', border: OutlineInputBorder(), isDense: true, suffixIcon: Icon(Icons.calendar_today, size: 18)),
          child: Text(
            value != null ? DateFormat('dd MMM yyyy').format(value) : label,
            style: TextStyle(color: value != null ? null : Theme.of(context).hintColor),
          ),
        ),
      ),
    );
  }
}
