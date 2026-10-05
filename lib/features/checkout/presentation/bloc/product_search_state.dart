part of 'product_search_bloc.dart';

enum ProductSearchStatus { initial, loading, success, failure }

/// Result of a barcode scan. [id] makes repeat scans of the same code distinct
/// so listeners fire every time.
class ScanOutcome extends Equatable {
  const ScanOutcome({required this.id, required this.barcode, this.product, this.failure});

  final int id;
  final String barcode;
  final Product? product;
  final Failure? failure;

  @override
  List<Object?> get props => [id, barcode, product, failure];
}

class ProductSearchState extends Equatable {
  const ProductSearchState({
    required this.status,
    required this.query,
    required this.products,
    this.failure,
    this.scanOutcome,
  });

  const ProductSearchState.initial()
      : status = ProductSearchStatus.initial,
        query = '',
        products = const [],
        failure = null,
        scanOutcome = null;

  final ProductSearchStatus status;
  final String query;
  final List<Product> products;
  final Failure? failure;
  final ScanOutcome? scanOutcome;

  ProductSearchState copyWith({
    ProductSearchStatus? status,
    String? query,
    ScanOutcome? scanOutcome,
  }) {
    return ProductSearchState(
      status: status ?? this.status,
      query: query ?? this.query,
      products: products,
      failure: failure,
      scanOutcome: scanOutcome ?? this.scanOutcome,
    );
  }

  @override
  List<Object?> get props => [status, query, products, failure, scanOutcome];
}
