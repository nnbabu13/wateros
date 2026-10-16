class OcrSaleRow {
  String time;
  String productText;
  double quantity;
  double amount;
  bool paid;
  String customerText;
  String? productId;
  String? productName;
  double unitPrice;
  double gstRate;
  String? customerId;

  OcrSaleRow({
    this.time = '',
    this.productText = '',
    this.quantity = 1,
    this.amount = 0,
    this.paid = false,
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

  bool get isValid =>
      productId != null && quantity > 0 && amount > 0;

  OcrSaleRow copyWith({
    String? time,
    String? productText,
    double? quantity,
    double? amount,
    bool? paid,
    String? customerText,
    String? productId,
    String? productName,
    double? unitPrice,
    double? gstRate,
    String? customerId,
  }) {
    return OcrSaleRow(
      time: time ?? this.time,
      productText: productText ?? this.productText,
      quantity: quantity ?? this.quantity,
      amount: amount ?? this.amount,
      paid: paid ?? this.paid,
      customerText: customerText ?? this.customerText,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      unitPrice: unitPrice ?? this.unitPrice,
      gstRate: gstRate ?? this.gstRate,
      customerId: customerId ?? this.customerId,
    );
  }
}
