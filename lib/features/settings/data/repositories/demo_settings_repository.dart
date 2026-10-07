import '../../../../core/result/result.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/settings_repository.dart';

/// In-memory settings so the module can be built before the Go API exists.
/// The sample values are placeholders, not a real business.
class DemoSettingsRepository implements SettingsRepository {
  static const Duration _latency = Duration(milliseconds: 250);

  AppSettings _settings = const AppSettings(
    pharmacyName: 'Demo Pharmacy',
    branchName: 'Eldoret',
    address: 'Main Street, Eldoret',
    phone: '+254700000100',
    email: 'hello@demopharmacy.example',
    taxPin: 'P012345678Q',
    licenceNumber: 'PPB/DEMO/0000',
    taxRateBasisPoints: 0,
    maxCashierDiscountPercent: 5,
    allowCreditSales: true,
    printerConnection: PrinterConnection.usb,
    paperWidth: PaperWidth.mm80,
    autoPrintReceipt: true,
    receiptCopies: 1,
    printPharmacyDetails: true,
    receiptFooter: 'Thank you. Get well soon.',
  );

  @override
  Future<Result<AppSettings>> load() async {
    await Future<void>.delayed(_latency);
    return Ok(_settings);
  }

  @override
  Future<Result<AppSettings>> save(AppSettings settings) async {
    await Future<void>.delayed(_latency);
    _settings = settings;
    return Ok(_settings);
  }
}
