import '../../../../core/result/result.dart';
import '../entities/medicine.dart';

abstract interface class MedicineRepository {
  Future<Result<List<Medicine>>> list();
  Future<Result<Medicine>> create(MedicineDraft draft);
  Future<Result<Medicine>> update(String id, MedicineDraft draft);
  Future<Result<Medicine>> setActive(String id, {required bool active});
}
