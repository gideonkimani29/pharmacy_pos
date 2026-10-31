import 'dart:async';

import 'package:http/http.dart' as http;

import '../../../core/error/failures.dart';
import '../../../core/network/api_repository.dart';
import '../../../core/network/api_session.dart';
import '../../../core/result/result.dart';
import '../../checkout/domain/entities/customer.dart';
import '../../checkout/domain/entities/product.dart';
import '../../checkout/domain/entities/sale.dart';
import '../../checkout/domain/repositories/customer_repository.dart';
import '../../checkout/domain/repositories/product_repository.dart';
import '../../checkout/domain/repositories/sale_repository.dart';
import '../../customers/domain/entities/customer_account.dart';
import '../../customers/domain/repositories/customer_account_repository.dart';
import '../../dashboard/domain/entities/dashboard_summary.dart';
import '../../dashboard/domain/repositories/dashboard_repository.dart';
import '../../medicines/domain/entities/medicine.dart';
import '../../medicines/domain/repositories/medicine_repository.dart';
import '../../purchases/domain/entities/purchase.dart';
import '../../purchases/domain/entities/supplier.dart';
import '../../purchases/domain/repositories/purchase_repository.dart';
import '../../purchases/domain/repositories/supplier_repository.dart';
import '../../reports/domain/entities/losses_report.dart';
import '../../reports/domain/entities/profit_report.dart';
import '../../reports/domain/entities/report_range.dart';
import '../../reports/domain/entities/sales_report.dart';
import '../../reports/domain/repositories/report_repository.dart';
import '../../settings/domain/entities/app_settings.dart';
import '../../settings/domain/entities/app_user.dart';
import '../../settings/domain/repositories/settings_repository.dart';
import '../../settings/domain/repositories/user_repository.dart';
import '../../stock/domain/entities/stock_batch.dart';
import '../../stock/domain/repositories/stock_repository.dart';

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw FormatException('The API field "$key" must be a string.');
}

String? _nullableString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String) return value;
  throw FormatException('The API field "$key" must be a string or null.');
}

int _integer(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw FormatException('The API field "$key" must be an integer.');
}

bool _boolean(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw FormatException('The API field "$key" must be a boolean.');
}

DateTime _date(Map<String, dynamic> json, String key) {
  final value = DateTime.tryParse(_string(json, key));
  if (value != null) return value;
  throw FormatException('The API field "$key" must be an ISO-8601 date.');
}

DateTime? _optionalDate(Map<String, dynamic> json, String key) {
  final value = _nullableString(json, key);
  if (value == null || value.isEmpty) return null;
  final result = DateTime.tryParse(value);
  if (result != null) return result;
  throw FormatException('The API field "$key" must be an ISO-8601 date or null.');
}

T _enumValue<T extends Enum>(Iterable<T> values, String name, String field) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  throw FormatException('The API returned an unsupported $field value.');
}

String _day(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

List<Map<String, dynamic>> _objects(Object? value) =>
    apiList(value).map(apiObject).toList(growable: false);

Product _product(Map<String, dynamic> json) => Product(
      id: _string(json, 'id'),
      sku: _string(json, 'sku'),
      barcode: _string(json, 'barcode'),
      name: _string(json, 'name'),
      genericName: _string(json, 'genericName'),
      unitPriceMinor: _integer(json, 'unitPriceMinor'),
      sellableStock: _integer(json, 'sellableStock'),
      lowStockThreshold: _integer(json, 'lowStockThreshold'),
      requiresPrescription: _boolean(json, 'requiresPrescription'),
      nearestExpiry: _optionalDate(json, 'nearestExpiry'),
      nextBatchNumber: _nullableString(json, 'nextBatchNumber'),
    );

Medicine _medicine(Map<String, dynamic> json) => Medicine(
      id: _string(json, 'id'),
      name: _string(json, 'name'),
      genericName: _string(json, 'genericName'),
      dosageForm: _enumValue(DosageForm.values, _string(json, 'dosageForm'), 'dosage form'),
      sku: _string(json, 'sku'),
      barcode: _string(json, 'barcode'),
      sellingPriceMinor: _integer(json, 'sellingPriceMinor'),
      reorderLevel: _integer(json, 'reorderLevel'),
      requiresPrescription: _boolean(json, 'requiresPrescription'),
      isActive: _boolean(json, 'isActive'),
      stockOnHand: _integer(json, 'stockOnHand'),
    );

StockBatch _batch(Map<String, dynamic> json) => StockBatch(
      id: _string(json, 'id'),
      medicineId: _string(json, 'medicineId'),
      medicineName: _string(json, 'medicineName'),
      batchNumber: _string(json, 'batchNumber'),
      supplierName: _string(json, 'supplierName'),
      receivedOn: _date(json, 'receivedOn'),
      expiryDate: _date(json, 'expiryDate'),
      quantityReceived: _integer(json, 'quantityReceived'),
      quantityOnHand: _integer(json, 'quantityOnHand'),
      unitCostMinor: _integer(json, 'unitCostMinor'),
      sellingPriceMinor: _integer(json, 'sellingPriceMinor'),
      reorderLevel: _integer(json, 'reorderLevel'),
    );

CustomerAccount _customerAccount(Map<String, dynamic> json) => CustomerAccount(
      id: _string(json, 'id'),
      name: _string(json, 'name'),
      phone: _string(json, 'phone'),
      email: _string(json, 'email'),
      creditLimitMinor: _integer(json, 'creditLimitMinor'),
      balanceMinor: _integer(json, 'balanceMinor'),
      isActive: _boolean(json, 'isActive'),
      lastPurchaseOn: _optionalDate(json, 'lastPurchaseOn'),
    );

AppUser _appUser(Map<String, dynamic> json) => AppUser(
      id: _string(json, 'id'),
      name: _string(json, 'name'),
      email: _string(json, 'email'),
      phone: _string(json, 'phone'),
      role: _enumValue(UserRole.values, _string(json, 'role'), 'user role'),
      isActive: _boolean(json, 'isActive'),
      lastSignInAt: _optionalDate(json, 'lastSignInAt'),
      invitationToken: _nullableString(json, 'invitationToken'),
    );

AppSettings _appSettings(Map<String, dynamic> json) => AppSettings(
      pharmacyName: _string(json, 'pharmacyName'),
      branchName: _string(json, 'branchName'),
      address: _string(json, 'address'),
      phone: _string(json, 'phone'),
      email: _string(json, 'email'),
      taxPin: _string(json, 'taxPin'),
      licenceNumber: _string(json, 'licenceNumber'),
      taxRateBasisPoints: _integer(json, 'taxRateBasisPoints'),
      maxCashierDiscountPercent: _integer(json, 'maxCashierDiscountPercent'),
      allowCreditSales: _boolean(json, 'allowCreditSales'),
      printerConnection: _enumValue(
        PrinterConnection.values,
        _string(json, 'printerConnection'),
        'printer connection',
      ),
      paperWidth: _enumValue(PaperWidth.values, _string(json, 'paperWidth'), 'paper width'),
      autoPrintReceipt: _boolean(json, 'autoPrintReceipt'),
      receiptCopies: _integer(json, 'receiptCopies'),
      printPharmacyDetails: _boolean(json, 'printPharmacyDetails'),
      receiptFooter: _string(json, 'receiptFooter'),
    );

ReportRange _reportRange(Map<String, dynamic> json) {
  final range = apiObject(json['range']);
  return ReportRange(from: _date(range, 'from'), to: _date(range, 'to'));
}

class RestProductRepository extends ApiRepository implements ProductRepository {
  const RestProductRepository(super.api);

  @override
  Future<Result<List<Product>>> search(String query) => run(() async {
        final response = await api.get(
          'products',
          query: query.trim().isEmpty ? null : {'query': query.trim()},
        );
        return _objects(response).map(_product).toList(growable: false);
      });

  @override
  Future<Result<Product?>> findByBarcode(String barcode) async {
    try {
      return Ok(_product(apiObject(await api.get('products/barcode/${Uri.encodeComponent(barcode)}'))));
    } on ApiException catch (error) {
      if (error.statusCode == 404) return const Ok(null);
      return _mapApiError<Product?>(error);
    } on FormatException catch (error) {
      return Err(UnexpectedFailure(error.message));
    } on http.ClientException {
      return const Err(NetworkFailure());
    } on TimeoutException {
      return const Err(NetworkFailure());
    }
  }
}

class RestSaleRepository extends ApiRepository implements SaleRepository {
  const RestSaleRepository(super.api);

  @override
  Future<Result<SaleReceipt>> submit(SaleRequest request) => run(() async {
        final response = apiObject(await api.post(
          'sales',
          idempotencyKey: request.idempotencyKey,
          body: {
            'saleType': request.saleType.name,
            'customerId': request.customerId,
            'lines': request.lines
                .map((line) => {
                      'productId': line.productId,
                      'quantity': line.quantity,
                      'unitPriceMinor': line.unitPriceMinor,
                    })
                .toList(growable: false),
            'payments': request.payments
                .map((payment) => {
                      'method': payment.method.name,
                      'amountMinor': payment.amountMinor,
                      'reference': payment.reference,
                    })
                .toList(growable: false),
            'prescriptionVerified': request.prescriptionVerified,
            'discountMinor': request.discountMinor,
            'expectedTotalMinor': request.expectedTotalMinor,
          },
        ));
        return SaleReceipt(
          receiptNumber: _string(response, 'receiptNumber'),
          totalMinor: _integer(response, 'totalMinor'),
          changeDueMinor: _integer(response, 'changeDueMinor'),
          amountOnAccountMinor: _integer(response, 'amountOnAccountMinor'),
          completedAt: _date(response, 'completedAt'),
        );
      });
}

class RestCustomerRepository extends ApiRepository implements CustomerRepository {
  const RestCustomerRepository(super.api);

  @override
  Future<Result<List<Customer>>> list() => run(() async {
        final response = await api.get('customers');
        return _objects(response)
            .map((json) => Customer(
                  id: _string(json, 'id'),
                  name: _string(json, 'name'),
                  phone: _nullableString(json, 'phone'),
                ))
            .toList(growable: false);
      });
}

class RestDashboardRepository extends ApiRepository implements DashboardRepository {
  const RestDashboardRepository(super.api);

  @override
  Future<Result<DashboardSummary>> load() => run(() async {
        final json = apiObject(await api.get('dashboard/summary'));
        return DashboardSummary(
          todaySalesMinor: _integer(json, 'todaySalesMinor'),
          todayTransactions: _integer(json, 'todayTransactions'),
          todayItemsSold: _integer(json, 'todayItemsSold'),
          creditOutstandingMinor: _integer(json, 'creditOutstandingMinor'),
          weeklySales: _objects(json['weeklySales'])
              .map((row) => DailySales(date: _date(row, 'date'), totalMinor: _integer(row, 'totalMinor')))
              .toList(growable: false),
          lowStock: _objects(json['lowStock'])
              .map((row) => StockAlert(
                    productName: _string(row, 'productName'),
                    sellableStock: _integer(row, 'sellableStock'),
                    lowStockThreshold: _integer(row, 'lowStockThreshold'),
                  ))
              .toList(growable: false),
          expiring: _objects(json['expiring'])
              .map((row) => ExpiryAlert(
                    productName: _string(row, 'productName'),
                    batchNumber: _string(row, 'batchNumber'),
                    expiryDate: _date(row, 'expiryDate'),
                    quantity: _integer(row, 'quantity'),
                  ))
              .toList(growable: false),
          topProducts: _objects(json['topProducts'])
              .map((row) => TopProduct(
                    name: _string(row, 'name'),
                    unitsSold: _integer(row, 'unitsSold'),
                    revenueMinor: _integer(row, 'revenueMinor'),
                  ))
              .toList(growable: false),
        );
      });
}

class RestMedicineRepository extends ApiRepository implements MedicineRepository {
  const RestMedicineRepository(super.api);

  @override
  Future<Result<List<Medicine>>> list() => run(() async {
        return _objects(await api.get('medicines')).map(_medicine).toList(growable: false);
      });

  @override
  Future<Result<Medicine>> create(MedicineDraft draft) => run(() async {
        return _medicine(apiObject(await api.post('medicines', body: _medicineDraft(draft))));
      });

  @override
  Future<Result<Medicine>> update(String id, MedicineDraft draft) => run(() async {
        return _medicine(apiObject(await api.put('medicines/${Uri.encodeComponent(id)}', body: _medicineDraft(draft))));
      });

  @override
  Future<Result<Medicine>> setActive(String id, {required bool active}) => run(() async {
        await api.patch('medicines/${Uri.encodeComponent(id)}/active', body: {'active': active});
        final medicines = _objects(await api.get('medicines')).map(_medicine);
        return medicines.firstWhere((medicine) => medicine.id == id);
      });

  Map<String, Object?> _medicineDraft(MedicineDraft draft) => {
        'name': draft.name,
        'genericName': draft.genericName,
        'dosageForm': draft.dosageForm.name,
        'sku': draft.sku,
        'barcode': draft.barcode,
        'sellingPriceMinor': draft.sellingPriceMinor,
        'reorderLevel': draft.reorderLevel,
        'requiresPrescription': draft.requiresPrescription,
      };
}

class RestStockRepository extends ApiRepository implements StockRepository {
  const RestStockRepository(super.api);

  @override
  Future<Result<List<StockBatch>>> list() => run(() async {
        return _objects(await api.get('stock/batches')).map(_batch).toList(growable: false);
      });

  @override
  Future<Result<StockBatch>> adjust(StockAdjustmentDraft draft) => run(() async {
        await api.post(
          'stock/adjustments',
          body: {
            'batchId': draft.batchId,
            'previousQuantity': draft.previousQuantity,
            'newQuantity': draft.newQuantity,
            'reason': _stockReason(draft.reason),
            'note': draft.note,
          },
        );
        final batches = _objects(await api.get('stock/batches')).map(_batch);
        return batches.firstWhere((batch) => batch.id == draft.batchId);
      });

  String _stockReason(StockAdjustmentReason reason) => switch (reason) {
        StockAdjustmentReason.expired => 'expired',
        StockAdjustmentReason.damaged => 'damaged',
        StockAdjustmentReason.returnedToSupplier => 'returnedToSupplier',
        StockAdjustmentReason.countCorrection => 'countCorrection',
        StockAdjustmentReason.other => 'other',
      };
}

class RestCustomerAccountRepository extends ApiRepository implements CustomerAccountRepository {
  const RestCustomerAccountRepository(super.api);

  @override
  Future<Result<List<CustomerAccount>>> list() => run(() async {
        return _objects(await api.get('customer-accounts')).map(_customerAccount).toList(growable: false);
      });

  @override
  Future<Result<CustomerAccount>> create(CustomerDraft draft) => run(() async {
        return _customerAccount(apiObject(await api.post('customer-accounts', body: _draft(draft))));
      });

  @override
  Future<Result<CustomerAccount>> update(String id, CustomerDraft draft) => run(() async {
        return _customerAccount(apiObject(await api.put('customer-accounts/${Uri.encodeComponent(id)}', body: _draft(draft))));
      });

  @override
  Future<Result<CustomerAccount>> setActive(String id, {required bool active}) => run(() async {
        return _customerAccount(apiObject(await api.patch(
          'customer-accounts/${Uri.encodeComponent(id)}/active',
          body: {'active': active},
        )));
      });

  @override
  Future<Result<CustomerAccount>> receivePayment(AccountPaymentDraft draft) => run(() async {
        return _customerAccount(apiObject(await api.post(
          'customer-account-payments',
          body: {
            'customerId': draft.customerId,
            'amountMinor': draft.amountMinor,
            'method': draft.method.name,
            'reference': draft.reference,
          },
        )));
      });

  Map<String, Object?> _draft(CustomerDraft draft) => {
        'name': draft.name,
        'phone': draft.phone,
        'email': draft.email,
        'creditLimitMinor': draft.creditLimitMinor,
      };
}

class RestSupplierRepository extends ApiRepository implements SupplierRepository {
  const RestSupplierRepository(super.api);

  @override
  Future<Result<List<Supplier>>> list() => run(() async {
        return _objects(await api.get('suppliers'))
            .map((json) => Supplier(
                  id: _string(json, 'id'),
                  name: _string(json, 'name'),
                  phone: _nullableString(json, 'phone'),
                ))
            .toList(growable: false);
      });
}

class RestPurchaseRepository extends ApiRepository implements PurchaseRepository {
  const RestPurchaseRepository(super.api);

  @override
  Future<Result<List<Purchase>>> list() => run(() async {
        return _objects(await api.get('purchases')).map(_purchase).toList(growable: false);
      });

  @override
  Future<Result<Purchase>> record(PurchaseRequest request) => run(() async {
        final response = apiObject(await api.post(
          'purchases',
          idempotencyKey: request.idempotencyKey,
          body: {
            'supplierId': request.supplierId,
            'invoiceNumber': request.invoiceNumber,
            'receivedOn': _day(request.receivedOn),
            'paymentStatus': request.paymentStatus.name,
            'lines': request.lines
                .map((line) => {
                      'productId': line.productId,
                      'productName': line.productName,
                      'batchNumber': line.batchNumber,
                      'expiryDate': line.expiryDate == null ? null : _day(line.expiryDate!),
                      'quantity': line.quantity,
                      'unitCostMinor': line.unitCostMinor,
                      'sellingPriceMinor': line.sellingPriceMinor,
                    })
                .toList(growable: false),
          },
        ));
        return _purchase(response);
      });

  Purchase _purchase(Map<String, dynamic> json) => Purchase(
        id: _string(json, 'id'),
        reference: _string(json, 'reference'),
        supplierName: _string(json, 'supplierName'),
        invoiceNumber: _string(json, 'invoiceNumber'),
        receivedOn: _date(json, 'receivedOn'),
        paymentStatus: _enumValue(PurchasePaymentStatus.values, _string(json, 'paymentStatus'), 'purchase status'),
        lineCount: _integer(json, 'lineCount'),
        unitCount: _integer(json, 'unitCount'),
        totalMinor: _integer(json, 'totalMinor'),
      );
}

class RestReportRepository extends ApiRepository implements ReportRepository {
  const RestReportRepository(super.api);

  @override
  Future<Result<SalesReport>> sales(ReportRange range) => run(() async {
        final json = apiObject(await api.get('reports/sales', query: _rangeQuery(range)));
        return SalesReport(
          range: _reportRange(json),
          days: _objects(json['days'])
              .map((row) => DailySalesRow(
                    date: _date(row, 'date'),
                    transactions: _integer(row, 'transactions'),
                    itemsSold: _integer(row, 'itemsSold'),
                    grossMinor: _integer(row, 'grossMinor'),
                    discountMinor: _integer(row, 'discountMinor'),
                  ))
              .toList(growable: false),
          byPayment: _objects(json['byPayment'])
              .map((row) => PaymentTotal(
                    method: _enumValue(ReportPayment.values, _string(row, 'method'), 'payment method'),
                    amountMinor: _integer(row, 'amountMinor'),
                  ))
              .toList(growable: false),
        );
      });

  @override
  Future<Result<ProfitReport>> profit(ReportRange range) => run(() async {
        final json = apiObject(await api.get('reports/profit', query: _rangeQuery(range)));
        return ProfitReport(
          range: _reportRange(json),
          products: _objects(json['products'])
              .map((row) => ProductProfit(
                    name: _string(row, 'name'),
                    unitsSold: _integer(row, 'unitsSold'),
                    revenueMinor: _integer(row, 'revenueMinor'),
                    costMinor: _integer(row, 'costMinor'),
                  ))
              .toList(growable: false),
        );
      });

  @override
  Future<Result<LossesReport>> losses(ReportRange range) => run(() async {
        final json = apiObject(await api.get('reports/losses', query: _rangeQuery(range)));
        return LossesReport(
          range: _reportRange(json),
          rows: _objects(json['rows'])
              .map((row) => LossRow(
                    date: _date(row, 'date'),
                    medicineName: _string(row, 'medicineName'),
                    batchNumber: _string(row, 'batchNumber'),
                    quantity: _integer(row, 'quantity'),
                    unitCostMinor: _integer(row, 'unitCostMinor'),
                    reason: _enumValue(LossReason.values, _string(row, 'reason'), 'loss reason'),
                  ))
              .toList(growable: false),
        );
      });

  Map<String, String> _rangeQuery(ReportRange range) => {
        'from': _day(range.from),
        'to': _day(range.to),
      };
}

class RestSettingsRepository extends ApiRepository implements SettingsRepository {
  const RestSettingsRepository(super.api);

  @override
  Future<Result<AppSettings>> load() => run(() async {
        return _appSettings(apiObject(await api.get('settings')));
      });

  @override
  Future<Result<AppSettings>> save(AppSettings settings) => run(() async {
        final response = apiObject(await api.put('settings', body: {
          'pharmacyName': settings.pharmacyName,
          'branchName': settings.branchName,
          'address': settings.address,
          'phone': settings.phone,
          'email': settings.email,
          'taxPin': settings.taxPin,
          'licenceNumber': settings.licenceNumber,
          'taxRateBasisPoints': settings.taxRateBasisPoints,
          'maxCashierDiscountPercent': settings.maxCashierDiscountPercent,
          'allowCreditSales': settings.allowCreditSales,
          'printerConnection': settings.printerConnection.name,
          'paperWidth': settings.paperWidth.name,
          'autoPrintReceipt': settings.autoPrintReceipt,
          'receiptCopies': settings.receiptCopies,
          'printPharmacyDetails': settings.printPharmacyDetails,
          'receiptFooter': settings.receiptFooter,
        }));
        return _appSettings(response);
      });
}

class RestUserRepository extends ApiRepository implements UserRepository {
  const RestUserRepository(super.api);

  @override
  Future<Result<List<AppUser>>> list() => run(() async {
        return _objects(await api.get('users')).map(_appUser).toList(growable: false);
      });

  @override
  Future<Result<AppUser>> create(UserDraft draft) => run(() async {
        final response = apiObject(await api.post('users', body: _draft(draft)));
        return _appUser(response);
      });

  @override
  Future<Result<AppUser>> update(String id, UserDraft draft) => run(() async {
        return _appUser(apiObject(await api.put('users/${Uri.encodeComponent(id)}', body: _draft(draft))));
      });

  @override
  Future<Result<AppUser>> setActive(String id, {required bool active}) => run(() async {
        return _appUser(apiObject(await api.patch('users/${Uri.encodeComponent(id)}/active', body: {'active': active})));
      });

  Map<String, Object?> _draft(UserDraft draft) => {
        'name': draft.name,
        'email': draft.email,
        'phone': draft.phone,
        'role': draft.role.name,
      };
}

Result<T> _mapApiError<T>(ApiException error) {
  if (error.statusCode == 401 || error.statusCode == 403) {
    return Err(UnauthorizedFailure(error.message));
  }
  if (error.statusCode == 400 || error.statusCode == 404 || error.statusCode == 409 || error.statusCode == 422) {
    return Err(ValidationFailure(error.message));
  }
  if (error.statusCode == 0) return Err(NetworkFailure(error.message));
  return Err(UnexpectedFailure(error.message));
}
