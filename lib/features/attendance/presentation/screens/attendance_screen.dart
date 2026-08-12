import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/business_helper.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _employees = [];
  Map<String, String> _attendance = {};
  Map<String, String> _existingAttendance = {};
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final bizId = await BusinessHelper.getOrCreateBusinessId();
      final employeesFuture = Supabase.instance.client
          .from('employees')
          .select('id, name, designation, basic_salary')
          .eq('business_id', bizId)
          .eq('is_active', true)
          .order('name');
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final attendanceFuture = Supabase.instance.client
          .from('attendance')
          .select('employee_id, status')
          .eq('business_id', bizId)
          .eq('attendance_date', dateStr);
      final results = await Future.wait([employeesFuture, attendanceFuture]);
      if (mounted) {
        final existing = <String, String>{};
        for (final a in List<Map<String, dynamic>>.from(results[1])) {
          existing[a['employee_id'] as String] = a['status'] as String;
        }
        // Default all employees to absent, then apply saved statuses
        final attendance = <String, String>{};
        for (final emp in List<Map<String, dynamic>>.from(results[0])) {
          final empId = emp['id'] as String;
          attendance[empId] = existing[empId] ?? 'absent';
        }
        setState(() {
          _employees = List<Map<String, dynamic>>.from(results[0]);
          _existingAttendance = existing;
          _attendance = attendance;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAttendance() async {
    setState(() => _isSaving = true);
    try {
      final bizId = await BusinessHelper.getOrCreateBusinessId();
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      for (final emp in _employees) {
        final empId = emp['id'] as String;
        final status = _attendance[empId] ?? 'present';
        await Supabase.instance.client.from('attendance').upsert({
          'business_id': bizId,
          'employee_id': empId,
          'attendance_date': dateStr,
          'status': status,
        }, onConflict: 'employee_id,attendance_date');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance saved!'), backgroundColor: Colors.green),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadData();
    }
  }

  int _getMarkedCount(String status) => _attendance.values.where((v) => v == status).length;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        actions: [
          IconButton(onPressed: _pickDate, icon: const Icon(Icons.calendar_today)),
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildCalendar(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: cs.primaryContainer.withOpacity(0.3),
                  child: Row(
                    children: [
                      _countChip('Present', _getMarkedCount('present'), Colors.green),
                      const SizedBox(width: 6),
                      _countChip('Absent', _getMarkedCount('absent'), Colors.red),
                      const SizedBox(width: 6),
                      _countChip('Half', _getMarkedCount('half_day'), Colors.orange),
                      const SizedBox(width: 6),
                      _countChip('Leave', _getMarkedCount('leave'), Colors.blue),
                      const SizedBox(width: 6),
                      _countChip('Holiday', _getMarkedCount('holiday'), Colors.purple),
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
                              const Text('No active employees'),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _employees.length,
                          itemBuilder: (context, index) => _buildEmployeeRow(_employees[index]),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : _saveAttendance,
        icon: _isSaving
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.save),
        label: Text(_isSaving ? 'Saving...' : 'Save Attendance'),
      ),
    );
  }

  Widget _buildCalendar() {
    final cs = Theme.of(context).colorScheme;
    final year = _selectedDate.year;
    final month = _selectedDate.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstWeekday = DateTime(year, month, 1).weekday;
    final today = DateTime.now();

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      _selectedDate = DateTime(year, month - 1);
                    });
                    _loadData();
                  },
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(DateFormat('MMMM yyyy').format(_selectedDate),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                IconButton(
                  onPressed: DateTime(year, month + 1).isAfter(DateTime(today.year, today.month))
                      ? null
                      : () {
                          setState(() {
                            _selectedDate = DateTime(year, month + 1);
                          });
                          _loadData();
                        },
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                  .map((d) => Expanded(
                        child: Center(
                          child: Text(d, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.outline)),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 4),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 2, crossAxisSpacing: 2),
              itemCount: (firstWeekday - 1) + daysInMonth,
              itemBuilder: (context, index) {
                if (index < firstWeekday - 1) return const SizedBox();
                final day = index - (firstWeekday - 1) + 1;
                final date = DateTime(year, month, day);
                final isToday = date.year == today.year && date.month == today.month && date.day == today.day;
                final isSelected = date.year == _selectedDate.year && date.month == _selectedDate.month && date.day == _selectedDate.day;
                final dateStr = DateFormat('yyyy-MM-dd').format(date);
                final isFuture = date.isAfter(today);

                return GestureDetector(
                  onTap: isFuture ? null : () {
                    setState(() => _selectedDate = date);
                    _loadData();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? cs.primary : isToday ? cs.primaryContainer : null,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('$day', style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected || isToday ? FontWeight.w700 : FontWeight.w400,
                          color: isFuture ? cs.outline.withOpacity(0.3) : isSelected ? cs.onPrimary : null,
                        )),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _countChip(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text('$count', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: color)),
            Text(label, style: TextStyle(fontSize: 10, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeRow(Map<String, dynamic> emp) {
    final empId = emp['id'] as String;
    final status = _attendance[empId];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  child: Text((emp['name'] as String? ?? '?')[0].toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(emp['name'] as String? ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      if (emp['designation'] != null)
                        Text(emp['designation'] as String,
                            style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (status == 'present')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(8)),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text('Present', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                  ],
                ),
              )
            else
              Row(
                children: [
                  _statusButton(empId, 'present', 'Mark Present', Colors.green, status),
                  const SizedBox(width: 6),
                  _statusButton(empId, 'absent', 'Absent', Colors.red, status),
                  const SizedBox(width: 6),
                  _statusButton(empId, 'half_day', 'Half', Colors.orange, status),
                  const SizedBox(width: 6),
                  _statusButton(empId, 'leave', 'Leave', Colors.blue, status),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _statusButton(String empId, String value, String label, Color color, String? current) {
    final isSelected = current == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _attendance[empId] = value;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color : color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? color : color.withOpacity(0.2)),
          ),
          child: Center(
            child: Text(label, style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 11,
              color: isSelected ? Colors.white : color,
            )),
          ),
        ),
      ),
    );
  }
}
