import '../../../../core/result/result.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/settings_repository.dart';

class DemoSettingsRepository implements SettingsRepository {
  DemoSettingsRepository({AppSettings? settings})
      : _settings = settings ??
            const AppSettings(
              pharmacyName: '',
              branchName: '',
              address: '',
              phone: '',
              email: '',
              taxPin: '',
              licenceNumber: '',
              taxRateBasisPoints: 0,
              maxCashierDiscountPercent: 5,
              allowCreditSales: true,
              printerConnection: PrinterConnection.usb,
              paperWidth: PaperWidth.mm80,
              autoPrintReceipt: true,
              receiptCopies: 1,
              printPharmacyDetails: true,
              receiptFooter: '',
            );

  static const Duration _latency = Duration(milliseconds: 250);
  AppSettings _settings;

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
