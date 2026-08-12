enum UserRole {
  owner,
  admin,
  manager,
  sales,
  accountant,
  delivery,
  employee;

  String get displayName {
    switch (this) {
      case UserRole.owner:
        return 'Owner';
      case UserRole.admin:
        return 'Admin';
      case UserRole.manager:
        return 'Manager';
      case UserRole.sales:
        return 'Sales';
      case UserRole.accountant:
        return 'Accountant';
      case UserRole.delivery:
        return 'Delivery';
      case UserRole.employee:
        return 'Employee';
    }
  }
}

enum PaymentMode {
  cash,
  upi,
  bankTransfer,
  credit,
  partial;

  String get displayName {
    switch (this) {
      case PaymentMode.cash:
        return 'Cash';
      case PaymentMode.upi:
        return 'UPI';
      case PaymentMode.bankTransfer:
        return 'Bank Transfer';
      case PaymentMode.credit:
        return 'Credit';
      case PaymentMode.partial:
        return 'Partial';
    }
  }

  String get dbValue {
    switch (this) {
      case PaymentMode.bankTransfer:
        return 'bank_transfer';
      default:
        return name;
    }
  }
}

enum BillStatus {
  paid,
  partiallyPaid,
  pending,
  cancelled;

  String get displayName {
    switch (this) {
      case BillStatus.paid:
        return 'Paid';
      case BillStatus.partiallyPaid:
        return 'Partially Paid';
      case BillStatus.pending:
        return 'Pending';
      case BillStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get dbValue {
    switch (this) {
      case BillStatus.partiallyPaid:
        return 'partially_paid';
      default:
        return name;
    }
  }
}

enum AttendanceStatus {
  present,
  absent,
  halfDay,
  leave,
  holiday;

  String get displayName {
    switch (this) {
      case AttendanceStatus.present:
        return 'Present';
      case AttendanceStatus.absent:
        return 'Absent';
      case AttendanceStatus.halfDay:
        return 'Half Day';
      case AttendanceStatus.leave:
        return 'Leave';
      case AttendanceStatus.holiday:
        return 'Holiday';
    }
  }

  String get dbValue {
    switch (this) {
      case AttendanceStatus.halfDay:
        return 'half_day';
      default:
        return name;
    }
  }
}

enum ExpenseCategory {
  electricity,
  fuel,
  salary,
  maintenance,
  rawMaterial,
  rent,
  transport,
  misc;

  String get displayName {
    switch (this) {
      case ExpenseCategory.electricity:
        return 'Electricity';
      case ExpenseCategory.fuel:
        return 'Fuel';
      case ExpenseCategory.salary:
        return 'Salary';
      case ExpenseCategory.maintenance:
        return 'Maintenance';
      case ExpenseCategory.rawMaterial:
        return 'Raw Material';
      case ExpenseCategory.rent:
        return 'Rent';
      case ExpenseCategory.transport:
        return 'Transport';
      case ExpenseCategory.misc:
        return 'Misc';
    }
  }
}

enum MovementType {
  in_,
  out,
  adjustment,
  transfer,
  return_;

  String get displayName {
    switch (this) {
      case MovementType.in_:
        return 'Stock In';
      case MovementType.out:
        return 'Stock Out';
      case MovementType.adjustment:
        return 'Adjustment';
      case MovementType.transfer:
        return 'Transfer';
      case MovementType.return_:
        return 'Return';
    }
  }

  String get dbValue {
    switch (this) {
      case MovementType.in_:
        return 'in';
      case MovementType.return_:
        return 'return';
      default:
        return name;
    }
  }
}

enum NotificationType {
  paymentDue,
  lowStock,
  expenseDue,
  salaryDue,
  followUp,
  info;

  String get displayName {
    switch (this) {
      case NotificationType.paymentDue:
        return 'Payment Due';
      case NotificationType.lowStock:
        return 'Low Stock';
      case NotificationType.expenseDue:
        return 'Expense Due';
      case NotificationType.salaryDue:
        return 'Salary Due';
      case NotificationType.followUp:
        return 'Follow Up';
      case NotificationType.info:
        return 'Info';
    }
  }
}

enum ReminderType {
  friendly,
  second,
  final_,
  custom;

  String get displayName {
    switch (this) {
      case ReminderType.friendly:
        return 'Friendly Reminder';
      case ReminderType.second:
        return 'Second Reminder';
      case ReminderType.final_:
        return 'Final Reminder';
      case ReminderType.custom:
        return 'Custom';
    }
  }
}

enum AccountType {
  bank,
  upi,
  cash;

  String get displayName {
    switch (this) {
      case AccountType.bank:
        return 'Bank';
      case AccountType.upi:
        return 'UPI';
      case AccountType.cash:
        return 'Cash';
    }
  }
}
