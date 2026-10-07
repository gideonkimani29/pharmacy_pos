import 'package:equatable/equatable.dart';

enum PrinterConnection { none, usb, bluetooth }

enum PaperWidth { mm58, mm80 }

/// Pharmacy-wide settings. Money is always KES, so currency is not a setting.
class AppSettings extends Equatable {
  const AppSettings({
    required this.pharmacyName,
    required this.branchName,
    required this.address,
    required this.phone,
    required this.email,
    required this.taxPin,
    required this.licenceNumber,
    required this.taxRateBasisPoints,
    required this.maxCashierDiscountPercent,
    required this.allowCreditSales,
    required this.printerConnection,
    required this.paperWidth,
    required this.autoPrintReceipt,
    required this.receiptCopies,
    required this.printPharmacyDetails,
    required this.receiptFooter,
  });

  final String pharmacyName;
  final String branchName;
  final String address;
  final String phone;
  final String email;

  /// KRA PIN, e.g. "A123456789B". Empty when not entered.
  final String taxPin;

  /// Pharmacy and Poisons Board registration. Free text.
  final String licenceNumber;

  /// 1600 means 16.00%.
  final int taxRateBasisPoints;
  final int maxCashierDiscountPercent;
  final bool allowCreditSales;

  final PrinterConnection printerConnection;
  final PaperWidth paperWidth;
  final bool autoPrintReceipt;
  final int receiptCopies;
  final bool printPharmacyDetails;
  final String receiptFooter;

  AppSettings copyWith({
    String? pharmacyName,
    String? branchName,
    String? address,
    String? phone,
    String? email,
    String? taxPin,
    String? licenceNumber,
    int? taxRateBasisPoints,
    int? maxCashierDiscountPercent,
    bool? allowCreditSales,
    PrinterConnection? printerConnection,
    PaperWidth? paperWidth,
    bool? autoPrintReceipt,
    int? receiptCopies,
    bool? printPharmacyDetails,
    String? receiptFooter,
  }) {
    return AppSettings(
      pharmacyName: pharmacyName ?? this.pharmacyName,
      branchName: branchName ?? this.branchName,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      taxPin: taxPin ?? this.taxPin,
      licenceNumber: licenceNumber ?? this.licenceNumber,
      taxRateBasisPoints: taxRateBasisPoints ?? this.taxRateBasisPoints,
      maxCashierDiscountPercent: maxCashierDiscountPercent ?? this.maxCashierDiscountPercent,
      allowCreditSales: allowCreditSales ?? this.allowCreditSales,
      printerConnection: printerConnection ?? this.printerConnection,
      paperWidth: paperWidth ?? this.paperWidth,
      autoPrintReceipt: autoPrintReceipt ?? this.autoPrintReceipt,
      receiptCopies: receiptCopies ?? this.receiptCopies,
      printPharmacyDetails: printPharmacyDetails ?? this.printPharmacyDetails,
      receiptFooter: receiptFooter ?? this.receiptFooter,
    );
  }

  @override
  List<Object?> get props => [
        pharmacyName,
        branchName,
        address,
        phone,
        email,
        taxPin,
        licenceNumber,
        taxRateBasisPoints,
        maxCashierDiscountPercent,
        allowCreditSales,
        printerConnection,
        paperWidth,
        autoPrintReceipt,
        receiptCopies,
        printPharmacyDetails,
        receiptFooter,
      ];
}
