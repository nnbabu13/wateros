import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/business_helper.dart';

class SalaryScreen extends StatefulWidget {
  const SalaryScreen({super.key});

  @override
  State<SalaryScreen> createState() => _SalaryScreenState();
}

class _SalaryScreenState extends State<SalaryScreen> {
  DateTime _selectedMonth = DateTime.now();
  List<Map<String, dynamic>> _employees = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final bizId = await BusinessHelper.getOrCreateBusinessId();
      final data = await Supabase.instance.client
          .from('employees')
          .select('id, name, designation, basic_salary')
          .eq('business_id', bizId)
          .eq('is_active', true)
          .order('name');
      if (mounted) setState(() { _employees = List<Map<String, dynamic>>.from(data); _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedMonth = DateTime(picked.year, picked.month));
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Salary'),
        actions: [
          IconButton(onPressed: _pickMonth, icon: const Icon(Icons.calendar_month)),
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: cs.primaryContainer.withOpacity(0.3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(DateFormat('MMMM yyyy').format(_selectedMonth),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                      Text('${_employees.length} employees', style: TextStyle(color: cs.onPrimaryContainer)),
                    ],
                  ),
                ),
                Expanded(
                  child: _employees.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_outline, size: 64, color: cs.outline),
                              const SizedBox(height: 16),
                              const Text('No employees found'),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _employees.length,
                          itemBuilder: (context, index) => _buildSalaryCard(_employees[index]),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildSalaryCard(Map<String, dynamic> emp) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _calcSalary(emp),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(child: Text((emp['name'] as String? ?? '?')[0].toUpperCase())),
              title: Text(emp['name'] as String? ?? ''),
              trailing: const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          );
        }
        final d = snapshot.data!;
        final earned = d['earned'] as double;
        final present = d['present'] as int;
        final half = d['half'] as int;
        final absent = d['absent'] as int;
        final days = d['days'] as int;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text((emp['name'] as String? ?? '?')[0].toUpperCase(),
                  style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer, fontWeight: FontWeight.w600)),
            ),
            title: Text(emp['name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('$present present, $half half, $absent absent of $days days',
                style: const TextStyle(fontSize: 12)),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('₹${earned.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                Text('${((present + half * 0.5) / days * 100).toStringAsFixed(0)}%',
                    style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline)),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _calcSalary(Map<String, dynamic> emp) async {
    final basicSalary = (emp['basic_salary'] as num?)?.toDouble() ?? 0;
    final year = _selectedMonth.year;
    final month = _selectedMonth.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final start = '$year-${month.toString().padLeft(2, '0')}-01';
    final end = '$year-${month.toString().padLeft(2, '0')}-${daysInMonth.toString().padLeft(2, '0')}';
    final attendance = await Supabase.instance.client
        .from('attendance')
        .select('status')
        .eq('employee_id', emp['id'] as String)
        .gte('attendance_date', start)
        .lte('attendance_date', end);
    int present = 0, absent = 0, half = 0;
    for (final a in attendance) {
      switch (a['status']) {
        case 'present': present++; break;
        case 'absent': absent++; break;
        case 'half_day': half++; break;
      }
    }
    final perDay = daysInMonth > 0 ? basicSalary / daysInMonth : 0.0;
    final earned = (present * perDay) + (half * perDay * 0.5);
    return {'earned': earned, 'present': present, 'half': half, 'absent': absent, 'days': daysInMonth};
  }
}
