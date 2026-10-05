part of 'product_search_bloc.dart';

sealed class ProductSearchEvent extends Equatable {
  const ProductSearchEvent();

  @override
  List<Object?> get props => [];
}

final class ProductSearchStarted extends ProductSearchEvent {
  const ProductSearchStarted();
}

final class ProductSearchQueryChanged extends ProductSearchEvent {
  const ProductSearchQueryChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

final class ProductBarcodeScanned extends ProductSearchEvent {
  const ProductBarcodeScanned(this.barcode);

  final String barcode;

  @override
  List<Object?> get props => [barcode];
}
