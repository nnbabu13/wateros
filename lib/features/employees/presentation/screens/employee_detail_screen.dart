import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/business_helper.dart';

class EmployeeDetailScreen extends StatefulWidget {
  final String employeeId;
  const EmployeeDetailScreen({super.key, required this.employeeId});

  @override
  State<EmployeeDetailScreen> createState() => _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends State<EmployeeDetailScreen> {
  Map<String, dynamic>? _employee;
  List<Map<String, dynamic>> _attendance = [];
  Map<String, dynamic>? _salaryData;
  bool _isLoading = true;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final empFuture = Supabase.instance.client
          .from('employees')
          .select()
          .eq('id', widget.employeeId)
          .single();
      final attFuture = Supabase.instance.client
          .from('attendance')
          .select('attendance_date, status')
          .eq('employee_id', widget.employeeId)
          .order('attendance_date', ascending: false);
      final results = await Future.wait([empFuture, attFuture]);
      final emp = results[0] as Map<String, dynamic>;
      final attList = (results[1] as List).cast<Map<String, dynamic>>();
      final joinDateStr = emp['date_of_joining'] as String?;
      final joinDate = joinDateStr != null ? DateTime.parse(joinDateStr) : DateTime.now().subtract(const Duration(days: 30));
      final today = DateTime.now();
      final savedMap = <String, String>{};
      for (final a in attList) {
        savedMap[a['attendance_date'] as String] = a['status'] as String;
      }
      final allDays = <Map<String, dynamic>>[];
      for (var d = today; !d.isBefore(joinDate); d = d.subtract(const Duration(days: 1))) {
        final dateStr = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        allDays.add({
          'attendance_date': dateStr,
          'status': savedMap[dateStr] ?? 'present',
        });
      }
      if (mounted) {
        setState(() {
          _employee = emp;
          _attendance = allDays;
          _isLoading = false;
        });
        _loadSalary();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSalary() async {
    try {
      final year = _selectedYear;
      final month = _selectedMonth;
      final daysInMonth = DateTime(year, month + 1, 0).day;
      final start = '$year-${month.toString().padLeft(2, '0')}-01';
      final end = '$year-${month.toString().padLeft(2, '0')}-${daysInMonth.toString().padLeft(2, '0')}';
      final att = await Supabase.instance.client
          .from('attendance')
          .select('attendance_date, status')
          .eq('employee_id', widget.employeeId)
          .gte('attendance_date', start)
          .lte('attendance_date', end);
      final savedMap = <String, String>{};
      for (final a in List<Map<String, dynamic>>.from(att)) {
        savedMap[a['attendance_date'] as String] = a['status'] as String;
      }
      final joinDateStr = _employee?['date_of_joining'] as String?;
      final joinDate = joinDateStr != null ? DateTime.parse(joinDateStr) : DateTime(2020);
      final monthStart = DateTime(year, month, 1);
      final startDay = joinDate.isAfter(monthStart) ? joinDate.day : 1;
      int present = 0, absent = 0, half = 0, leave = 0;
      for (var d = startDay; d <= daysInMonth; d++) {
        final dateStr = '$year-${month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
        switch (savedMap[dateStr] ?? 'present') {
          case 'present': present++; break;
          case 'absent': absent++; break;
          case 'half_day': half++; break;
          case 'leave': leave++; break;
        }
      }
      final totalDays = daysInMonth - startDay + 1;
      final basicSalary = (_employee?['basic_salary'] as num?)?.toDouble() ?? 0;
      final perDay = totalDays > 0 ? basicSalary / totalDays : 0.0;
      final earned = (present * perDay) + (half * perDay * 0.5);
      if (mounted) {
        setState(() {
          _salaryData = {
            'basic_salary': basicSalary,
            'working_days': totalDays,
            'present_days': present,
            'absent_days': absent,
            'half_days': half,
            'leave_days': leave,
            'per_day': perDay,
            'earned': earned,
          };
        });
      }
    } catch (e) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_employee?['name'] ?? 'Employee'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Details'),
              Tab(text: 'Attendance'),
              Tab(text: 'Salary'),
              Tab(text: 'Documents'),
            ],
          ),
          actions: [
            if (_employee != null)
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () async {
                  await context.push('/employees/${widget.employeeId}/edit');
                  _loadData();
                },
              ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _employee == null
                ? const Center(child: Text('Employee not found'))
                : TabBarView(
                    children: [
                      _buildDetailsTab(),
                      _buildAttendanceTab(),
                      _buildSalaryTab(),
                      _buildDocumentsTab(),
                    ],
                  ),
      ),
    );
  }

  Widget _buildDetailsTab() {
    final cs = Theme.of(context).colorScheme;
    final emp = _employee!;
    final name = emp['name'] as String? ?? '';
    final phone = emp['phone'] as String? ?? '';
    final email = emp['email'] as String? ?? '';
    final address = emp['address'] as String? ?? '';
    final city = emp['city'] as String? ?? '';
    final designation = emp['designation'] as String? ?? '';
    final department = emp['department'] as String? ?? '';
    final salary = (emp['basic_salary'] as num?)?.toDouble() ?? 0;
    final joiningDate = emp['date_of_joining'] as String? ?? '';
    final dob = emp['date_of_birth'] as String? ?? '';
    final bankName = emp['bank_name'] as String? ?? '';
    final bankAccount = emp['bank_account_number'] as String? ?? '';
    final ifsc = emp['ifsc_code'] as String? ?? '';
    final pan = emp['pan_number'] as String? ?? '';
    final aadhar = emp['aadhar_number'] as String? ?? '';
    final emergencyContact = emp['emergency_contact'] as String? ?? '';
    final emergencyName = emp['emergency_contact_name'] as String? ?? '';
    final empCode = emp['employee_code'] as String? ?? '';
    final isActive = emp['is_active'] as bool? ?? true;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: cs.primaryContainer,
                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: cs.onPrimaryContainer)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      if (designation.isNotEmpty) Text(designation, style: TextStyle(color: cs.primary, fontWeight: FontWeight.w500)),
                      if (department.isNotEmpty) Text(department, style: TextStyle(color: cs.outline, fontSize: 13)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(isActive ? 'ACTIVE' : 'INACTIVE',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isActive ? Colors.green : Colors.grey)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _infoCard('Contact', [
          _infoRow(Icons.phone, 'Phone', phone),
          if (email.isNotEmpty) _infoRow(Icons.email, 'Email', email),
          if (address.isNotEmpty) _infoRow(Icons.location_on, 'Address', [address, city].where((s) => s.isNotEmpty).join(', ')),
          if (empCode.isNotEmpty) _infoRow(Icons.badge, 'Employee Code', empCode),
        ]),
        _infoCard('Employment', [
          if (joiningDate.isNotEmpty) _infoRow(Icons.calendar_today, 'Joined', DateFormat('dd MMM yyyy').format(DateTime.parse(joiningDate))),
          if (dob.isNotEmpty) _infoRow(Icons.cake, 'Date of Birth', DateFormat('dd MMM yyyy').format(DateTime.parse(dob))),
          _infoRow(Icons.currency_rupee, 'Salary', '₹${salary.toStringAsFixed(0)}/month'),
        ]),
        if (bankName.isNotEmpty || bankAccount.isNotEmpty)
          _infoCard('Bank Details', [
            if (bankName.isNotEmpty) _infoRow(Icons.account_balance, 'Bank', bankName),
            if (bankAccount.isNotEmpty) _infoRow(Icons.account_box, 'Account', bankAccount),
            if (ifsc.isNotEmpty) _infoRow(Icons.code, 'IFSC', ifsc),
          ]),
        if (pan.isNotEmpty || aadhar.isNotEmpty)
          _infoCard('Documents', [
            if (pan.isNotEmpty) _infoRow(Icons.credit_card, 'PAN', pan),
            if (aadhar.isNotEmpty) _infoRow(Icons.fingerprint, 'Aadhar', aadhar),
          ]),
        if (emergencyContact.isNotEmpty)
          _infoCard('Emergency Contact', [
            if (emergencyName.isNotEmpty) _infoRow(Icons.person, 'Name', emergencyName),
            _infoRow(Icons.phone, 'Phone', emergencyContact),
          ]),
      ],
    );
  }

  Widget _infoCard(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 12),
          SizedBox(width: 100, child: Text(label, style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodySmall?.color))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _buildAttendanceTab() {
    if (_attendance.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text('No attendance records', style: TextStyle(color: Theme.of(context).colorScheme.outline)),
          ],
        ),
      );
    }
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final year = _selectedYear;
    final month = _selectedMonth;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstWeekday = DateTime(year, month, 1).weekday;

    final statusMap = <String, String>{};
    for (final r in _attendance) {
      statusMap[r['attendance_date'] as String] = r['status'] as String;
    }

    int present = 0, absent = 0, half = 0, leave = 0;
    for (var d = 1; d <= daysInMonth; d++) {
      final dateStr = '$year-${month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
      switch (statusMap[dateStr] ?? 'absent') {
        case 'present': present++; break;
        case 'absent': absent++; break;
        case 'half_day': half++; break;
        case 'leave': leave++; break;
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      if (_selectedMonth == 1) { _selectedMonth = 12; _selectedYear--; }
                      else { _selectedMonth--; }
                    });
                  },
                ),
                Text(DateFormat('MMMM yyyy').format(DateTime(year, month)),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: (year < now.year || (year == now.year && month < now.month))
                      ? () {
                          setState(() {
                            if (_selectedMonth == 12) { _selectedMonth = 1; _selectedYear++; }
                            else { _selectedMonth++; }
                          });
                        }
                      : null,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
              .map((d) => Expanded(
                    child: Center(
                      child: Text(d, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.outline)),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 4),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 3, crossAxisSpacing: 3),
          itemCount: (firstWeekday - 1) + daysInMonth,
          itemBuilder: (context, index) {
            if (index < firstWeekday - 1) return const SizedBox();
            final day = index - (firstWeekday - 1) + 1;
            final date = DateTime(year, month, day);
            final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
            final isFuture = date.isAfter(now);
            final dateStr = '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
            final status = isFuture ? 'future' : (statusMap[dateStr] ?? 'absent');
            final color = _attStatusColor(status);

            return GestureDetector(
              onTap: isFuture ? null : () => _showMarkDialog(dateStr, status),
              child: Container(
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: isToday ? Border.all(color: cs.primary, width: 2) : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$day', style: TextStyle(
                      fontSize: 12,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                      color: isFuture ? cs.outline.withOpacity(0.3) : color,
                    )),
                    if (!isFuture) ...[
                      const SizedBox(height: 2),
                      Icon(_attStatusIcon(status), size: 10, color: color),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _countChip('Present', present, Colors.green),
            const SizedBox(width: 6),
            _countChip('Absent', absent, Colors.red),
            const SizedBox(width: 6),
            _countChip('Half', half, Colors.orange),
            const SizedBox(width: 6),
            _countChip('Leave', leave, Colors.blue),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Summary', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _attSummaryRow('Total Days', daysInMonth, Colors.grey),
                _attSummaryRow('Present', present, Colors.green),
                _attSummaryRow('Absent', absent, Colors.red),
                _attSummaryRow('Half Days', half, Colors.orange),
                _attSummaryRow('Leave', leave, Colors.blue),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Attendance %', style: TextStyle(fontWeight: FontWeight.w700)),
                    Text(daysInMonth > 0 ? '${((present + half * 0.5) / daysInMonth * 100).toStringAsFixed(1)}%' : '0%',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: cs.primary)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showMarkDialog(String dateStr, String currentStatus) async {
    final statuses = [
      {'status': 'present', 'label': 'Present', 'icon': Icons.check_circle, 'color': Colors.green},
      {'status': 'absent', 'label': 'Absent', 'icon': Icons.cancel, 'color': Colors.red},
      {'status': 'half_day', 'label': 'Half Day', 'icon': Icons.timelapse, 'color': Colors.orange},
      {'status': 'leave', 'label': 'Leave', 'icon': Icons.event_busy, 'color': Colors.blue},
    ];
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Mark attendance for $dateStr',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            ),
            ...statuses.map((s) => ListTile(
                  leading: Icon(s['icon'] as IconData, color: s['color'] as Color),
                  title: Text(s['label'] as String),
                  trailing: currentStatus == s['status']
                      ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () => Navigator.pop(ctx, s['status'] as String),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null && picked != currentStatus) {
      try {
        final bizId = await BusinessHelper.getOrCreateBusinessId();
        await Supabase.instance.client.from('attendance').upsert({
          'business_id': bizId,
          'employee_id': widget.employeeId,
          'attendance_date': dateStr,
          'status': picked,
        }, onConflict: 'employee_id,attendance_date');
        if (mounted) {
          setState(() {
            final idx = _attendance.indexWhere((r) => r['attendance_date'] == dateStr);
            if (idx >= 0) {
              _attendance[idx] = {'attendance_date': dateStr, 'status': picked};
            }
          });
          _loadSalary();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Marked as ${picked.replaceAll('_', ' ')}'), backgroundColor: Colors.green, duration: const Duration(seconds: 1)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Widget _countChip(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text('$count', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _attSummaryRow(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(label),
          ]),
          Text('$count', style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Color _attStatusColor(String s) {
    switch (s) {
      case 'present': return Colors.green;
      case 'absent': return Colors.red;
      case 'half_day': return Colors.orange;
      case 'leave': return Colors.blue;
      case 'holiday': return Colors.purple;
      default: return Colors.grey;
    }
  }

  IconData _attStatusIcon(String s) {
    switch (s) {
      case 'present': return Icons.check_circle;
      case 'absent': return Icons.cancel;
      case 'half_day': return Icons.timelapse;
      case 'leave': return Icons.event_busy;
      case 'holiday': return Icons.celebration;
      default: return Icons.help;
    }
  }

  Widget _buildSalaryTab() {
    final now = DateTime.now();
    final monthName = DateFormat('MMMM yyyy').format(DateTime(_selectedYear, _selectedMonth));
    if (_salaryData == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final data = _salaryData!;
    final basicSalary = data['basic_salary'] as double;
    final workingDays = data['working_days'] as int;
    final presentDays = data['present_days'] as int;
    final halfDays = data['half_days'] as int;
    final absentDays = data['absent_days'] as int;
    final leaveDays = data['leave_days'] as int;
    final perDay = data['per_day'] as double;
    final earned = data['earned'] as double;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      if (_selectedMonth == 1) { _selectedMonth = 12; _selectedYear--; }
                      else { _selectedMonth--; }
                    });
                    _loadSalary();
                  },
                ),
                Text(monthName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: (_selectedYear < now.year || (_selectedYear == now.year && _selectedMonth < now.month))
                      ? () {
                          setState(() {
                            if (_selectedMonth == 12) { _selectedMonth = 1; _selectedYear++; }
                            else { _selectedMonth++; }
                          });
                          _loadSalary();
                        }
                      : null,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _salaryStat('Monthly', '₹${basicSalary.toStringAsFixed(0)}', Colors.blue),
                _salaryStat('Per Day', '₹${perDay.toStringAsFixed(0)}', Colors.teal),
                _salaryStat('Earned', '₹${earned.toStringAsFixed(0)}', Colors.green),
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
                Text('Attendance Summary', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                _attSummaryRow('Working Days', workingDays, Colors.grey),
                _attSummaryRow('Present', presentDays, Colors.green),
                _attSummaryRow('Half Days', halfDays, Colors.orange),
                _attSummaryRow('Absent', absentDays, Colors.red),
                _attSummaryRow('Leave', leaveDays, Colors.blue),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Net Salary', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    Text('₹${earned.toStringAsFixed(0)}',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: Theme.of(context).colorScheme.primary)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _salaryStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: color)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color)),
        ],
      ),
    );
  }

  Widget _buildDocumentsTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder, size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text('Documents coming soon...', style: TextStyle(color: Theme.of(context).colorScheme.outline)),
        ],
      ),
    );
  }
}
