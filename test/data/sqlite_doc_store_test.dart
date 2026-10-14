import 'package:plural_app/data/sqlite_doc_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'doc_store_contract.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  docStoreContract('sqlite', () async => SqliteDocStore.open(inMemoryDatabasePath));
}
