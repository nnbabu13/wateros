import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../features/sales/data/models/sale_model.dart';
import '../../features/customers/data/models/customer_model.dart';

class PdfGenerator {
  PdfGenerator._();

  static Future<void> generateInvoice({
    required SaleModel sale,
    required CustomerModel customer,
    required Map<String, dynamic> business,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          _buildHeader(business),
          pw.SizedBox(height: 20),
          _buildInvoiceInfo(sale),
          pw.SizedBox(height: 20),
          _buildCustomerInfo(customer),
          pw.SizedBox(height: 20),
          _buildItemsTable(sale),
          pw.SizedBox(height: 20),
          _buildTotals(sale),
          pw.SizedBox(height: 30),
          _buildFooter(business),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Invoice_${sale.invoiceNumber}',
    );
  }

  static pw.Widget _buildHeader(Map<String, dynamic> business) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              business['name'] ?? '',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(business['address'] ?? ''),
            pw.Text('Phone: ${business['phone'] ?? ''}'),
            if (business['gst_number'] != null)
              pw.Text('GST: ${business['gst_number']}'),
          ],
        ),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.blue50,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Text(
            'TAX INVOICE',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue800,
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildInvoiceInfo(SaleModel sale) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Invoice No:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text(sale.invoiceNumber),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Date:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('${sale.invoiceDate.day}/${sale.invoiceDate.month}/${sale.invoiceDate.year}'),
          ],
        ),
        if (sale.dueDate != null)
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Due Date:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('${sale.dueDate!.day}/${sale.dueDate!.month}/${sale.dueDate!.year}'),
            ],
          ),
      ],
    );
  }

  static pw.Widget _buildCustomerInfo(CustomerModel customer) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Bill To:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
          pw.SizedBox(height: 4),
          pw.Text(customer.name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
          pw.Text(customer.phone),
          if (customer.address != null) pw.Text(customer.address!),
          if (customer.gstNumber != null) pw.Text('GST: ${customer.gstNumber}'),
        ],
      ),
    );
  }

  static pw.Widget _buildItemsTable(SaleModel sale) {
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
      cellHeight: 30,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
      },
      headerAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
      },
      headers: ['Item', 'Qty', 'Rate', 'GST', 'Amount'],
      data: sale.items.map((item) => [
        item.productName,
        item.quantity.toString(),
        '₹${item.unitPrice.toStringAsFixed(2)}',
        '${item.gstRate.toStringAsFixed(1)}%',
        '₹${item.totalAmount.toStringAsFixed(2)}',
      ]).toList(),
    );
  }

  static pw.Widget _buildTotals(SaleModel sale) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.SizedBox(
          width: 200,
          child: pw.Column(
            children: [
              _buildTotalRow('Subtotal', sale.subtotal),
              if (sale.discountAmount > 0)
                _buildTotalRow('Discount', -sale.discountAmount),
              _buildTotalRow('GST', sale.taxAmount),
              pw.Divider(),
              _buildTotalRow('Total', sale.totalAmount, isBold: true),
              _buildTotalRow('Paid', sale.paidAmount),
              _buildTotalRow('Balance', sale.balanceAmount, isBold: true, isRed: sale.balanceAmount > 0),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildTotalRow(String label, double amount, {bool isBold = false, bool isRed = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(
            '₹${amount.toStringAsFixed(2)}',
            style: pw.TextStyle(
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: isRed ? PdfColors.red : null,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(Map<String, dynamic> business) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Divider(),
        pw.SizedBox(height: 10),
        pw.Text('Thank you for your business!', style: pw.TextStyle(fontStyle: pw.FontStyle.italic)),
        pw.SizedBox(height: 5),
        pw.Text('${business['name']} | ${business['phone']}', style: pw.TextStyle(color: PdfColors.grey600)),
      ],
    );
  }
}
