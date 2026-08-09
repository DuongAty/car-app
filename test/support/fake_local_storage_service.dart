import 'package:viet_ktv/core/services/local_storage_service.dart';

class FakeLocalStorageService implements LocalStorageService {
  final Map<String, String> store = {};

  @override
  Future<String?> read(String key) async => store[key];

  @override
  Future<void> write(String key, String value) async {
    store[key] = value;
  }
}
