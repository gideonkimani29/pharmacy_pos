import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:stream_transform/stream_transform.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/product.dart';
import '../../domain/usecases/find_product_by_barcode.dart';
import '../../domain/usecases/search_products.dart';

part 'product_search_event.dart';
part 'product_search_state.dart';

class ProductSearchBloc extends Bloc<ProductSearchEvent, ProductSearchState> {
  ProductSearchBloc({
    required SearchProducts searchProducts,
    required FindProductByBarcode findProductByBarcode,
  })  : _searchProducts = searchProducts,
        _findProductByBarcode = findProductByBarcode,
        super(const ProductSearchState.initial()) {
    on<ProductSearchStarted>((event, emit) => _runSearch('', emit), transformer: restartable());
    on<ProductSearchQueryChanged>(
      (event, emit) => _runSearch(event.query, emit),
      transformer: _debounced(AppConfig.searchDebounce),
    );
    on<ProductBarcodeScanned>(_onBarcodeScanned);
  }

  final SearchProducts _searchProducts;
  final FindProductByBarcode _findProductByBarcode;
  int _scanSequence = 0;

  Future<void> _runSearch(String query, Emitter<ProductSearchState> emit) async {
    emit(state.copyWith(status: ProductSearchStatus.loading, query: query));
    final result = await _searchProducts(query);
    switch (result) {
      case Ok<List<Product>>(:final value):
        emit(ProductSearchState(
          status: ProductSearchStatus.success,
          query: query,
          products: value,
          scanOutcome: state.scanOutcome,
        ));
      case Err<List<Product>>(:final failure):
        emit(ProductSearchState(
          status: ProductSearchStatus.failure,
          query: query,
          products: state.products,
          failure: failure,
          scanOutcome: state.scanOutcome,
        ));
    }
  }

  Future<void> _onBarcodeScanned(ProductBarcodeScanned event, Emitter<ProductSearchState> emit) async {
    final result = await _findProductByBarcode(event.barcode);
    final id = ++_scanSequence;
    switch (result) {
      case Ok<Product?>(:final value):
        emit(state.copyWith(scanOutcome: ScanOutcome(id: id, barcode: event.barcode, product: value)));
      case Err<Product?>(:final failure):
        emit(state.copyWith(scanOutcome: ScanOutcome(id: id, barcode: event.barcode, failure: failure)));
    }
  }

  static EventTransformer<E> _debounced<E>(Duration duration) {
    return (events, mapper) => restartable<E>().call(events.debounce(duration), mapper);
  }
}
