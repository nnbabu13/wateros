class OcrSaleRow {
  String time;
  DateTime? date;
  String productText;
  double quantity;
  double amount;
  bool paid;
  double partPaymentAmount;
  String customerText;
  String? productId;
  String? productName;
  double unitPrice;
  double gstRate;
  String? customerId;

  OcrSaleRow({
    this.time = '',
    this.date,
    this.productText = '',
    this.quantity = 1,
    this.amount = 0,
    this.paid = false,
    this.partPaymentAmount = 0,
    this.customerText = '',
    this.productId,
    this.productName,
    this.unitPrice = 0,
    this.gstRate = 0,
    this.customerId,
  });

  bool get needsProductMatch => productId == null;

  bool get needsCustomerMatch =>
      customerId == null && customerText.trim().isEmpty;

  bool get isNewCustomer =>
      customerId == null && customerText.trim().isNotEmpty;

  bool get hasPartPayment => !paid && partPaymentAmount > 0;

  double get remainingBalance =>
      paid ? 0 : (amount - partPaymentAmount).clamp(0, amount);

  bool get isValid =>
      productId != null && quantity > 0 && amount > 0;

  OcrSaleRow copyWith({
    String? time,
    DateTime? date,
    bool clearDate = false,
    String? productText,
    double? quantity,
    double? amount,
    bool? paid,
    double? partPaymentAmount,
    String? customerText,
    String? productId,
    String? productName,
    double? unitPrice,
    double? gstRate,
    String? customerId,
  }) {
    return OcrSaleRow(
      time: time ?? this.time,
      date: clearDate ? null : (date ?? this.date),
      productText: productText ?? this.productText,
      quantity: quantity ?? this.quantity,
      amount: amount ?? this.amount,
      paid: paid ?? this.paid,
      partPaymentAmount: partPaymentAmount ?? this.partPaymentAmount,
      customerText: customerText ?? this.customerText,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      unitPrice: unitPrice ?? this.unitPrice,
      gstRate: gstRate ?? this.gstRate,
      customerId: customerId ?? this.customerId,
    );
  }
}
