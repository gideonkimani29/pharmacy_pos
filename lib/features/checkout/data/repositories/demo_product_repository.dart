import '../../../../core/result/result.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/product_repository.dart';

/// In-memory catalog so the UI runs before the Go API is wired up.
/// Replace with an implementation backed by the REST client (and Isar cache).
class DemoProductRepository implements ProductRepository {
  DemoProductRepository({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static const Duration _latency = Duration(milliseconds: 120);

  final DateTime Function() _clock;

  late final List<Product> _catalog = _buildCatalog(_clock())
      .indexed
      .map((entry) => entry.$2.copyWith(
            nextBatchNumber: 'B${(entry.$1 + 1).toString().padLeft(3, '0')}',
          ))
      .toList();

  @override
  Future<Result<List<Product>>> search(String query) async {
    await Future<void>.delayed(_latency);
    final needle = query.toLowerCase();
    if (needle.isEmpty) return Ok(_catalog);
    final matches = _catalog.where((p) {
      return p.name.toLowerCase().contains(needle) ||
          p.genericName.toLowerCase().contains(needle) ||
          p.sku.toLowerCase().contains(needle) ||
          p.barcode.contains(needle);
    }).toList();
    return Ok(matches);
  }

  @override
  Future<Result<Product?>> findByBarcode(String barcode) async {
    await Future<void>.delayed(_latency);
    for (final product in _catalog) {
      if (product.barcode == barcode) return Ok(product);
    }
    return const Ok(null);
  }

  static List<Product> _buildCatalog(DateTime now) {
    DateTime inDays(int days) => now.add(Duration(days: days));
    return [
      Product(id: 'p1', sku: 'PAR-500', barcode: '6161100010011', name: 'Panadol 500mg x24', genericName: 'Paracetamol', unitPriceMinor: 18000, sellableStock: 140, lowStockThreshold: 20, requiresPrescription: false, nearestExpiry: inDays(420)),
      Product(id: 'p2', sku: 'AMX-500', barcode: '6161100010028', name: 'Amoxil 500mg capsules x21', genericName: 'Amoxicillin', unitPriceMinor: 45000, sellableStock: 62, lowStockThreshold: 15, requiresPrescription: true, nearestExpiry: inDays(75)),
      Product(id: 'p3', sku: 'ORS-SAC', barcode: '6161100010035', name: 'ORS sachet', genericName: 'Oral rehydration salts', unitPriceMinor: 3500, sellableStock: 8, lowStockThreshold: 25, requiresPrescription: false, nearestExpiry: inDays(210)),
      Product(id: 'p4', sku: 'IBU-400', barcode: '6161100010042', name: 'Brufen 400mg x30', genericName: 'Ibuprofen', unitPriceMinor: 32000, sellableStock: 55, lowStockThreshold: 15, requiresPrescription: false, nearestExpiry: inDays(48)),
      Product(id: 'p5', sku: 'MET-500', barcode: '6161100010059', name: 'Glucophage 500mg x60', genericName: 'Metformin', unitPriceMinor: 62000, sellableStock: 34, lowStockThreshold: 10, requiresPrescription: true, nearestExpiry: inDays(300)),
      Product(id: 'p6', sku: 'CET-10', barcode: '6161100010066', name: 'Zyrtec 10mg x10', genericName: 'Cetirizine', unitPriceMinor: 28000, sellableStock: 71, lowStockThreshold: 15, requiresPrescription: false, nearestExpiry: inDays(18)),
      Product(id: 'p7', sku: 'OME-20', barcode: '6161100010073', name: 'Losec 20mg x14', genericName: 'Omeprazole', unitPriceMinor: 54000, sellableStock: 0, lowStockThreshold: 10, requiresPrescription: false, nearestExpiry: null),
      Product(id: 'p8', sku: 'VTC-1000', barcode: '6161100010080', name: 'Vitamin C 1000mg x20', genericName: 'Ascorbic acid', unitPriceMinor: 36000, sellableStock: 90, lowStockThreshold: 20, requiresPrescription: false, nearestExpiry: inDays(600)),
      Product(id: 'p9', sku: 'ZNC-20', barcode: '6161100010097', name: 'Zinc 20mg dispersible x10', genericName: 'Zinc sulfate', unitPriceMinor: 15000, sellableStock: 120, lowStockThreshold: 20, requiresPrescription: false, nearestExpiry: inDays(88)),
      Product(id: 'p10', sku: 'SAL-100', barcode: '6161100010103', name: 'Ventolin inhaler 100mcg', genericName: 'Salbutamol', unitPriceMinor: 78000, sellableStock: 12, lowStockThreshold: 6, requiresPrescription: true, nearestExpiry: inDays(160)),
      Product(id: 'p11', sku: 'ALU-80', barcode: '6161100010110', name: 'Coartem 80/480mg x6', genericName: 'Artemether/Lumefantrine', unitPriceMinor: 55000, sellableStock: 4, lowStockThreshold: 12, requiresPrescription: true, nearestExpiry: inDays(25)),
      Product(id: 'p12', sku: 'DIC-GEL', barcode: '6161100010127', name: 'Voltaren Emulgel 50g', genericName: 'Diclofenac gel', unitPriceMinor: 89000, sellableStock: 27, lowStockThreshold: 8, requiresPrescription: false, nearestExpiry: inDays(380)),
      Product(id: 'p13', sku: 'LOP-2', barcode: '6161100010134', name: 'Imodium 2mg x12', genericName: 'Loperamide', unitPriceMinor: 41000, sellableStock: 38, lowStockThreshold: 10, requiresPrescription: false, nearestExpiry: inDays(240)),
      Product(id: 'p14', sku: 'POV-100', barcode: '6161100010141', name: 'Betadine solution 100ml', genericName: 'Povidone iodine', unitPriceMinor: 32500, sellableStock: 46, lowStockThreshold: 10, requiresPrescription: false, nearestExpiry: inDays(510)),
    ];
  }
}
