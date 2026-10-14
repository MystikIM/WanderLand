import 'package:plural_app/data/doc_store.dart';
import 'doc_store_contract.dart';

void main() => docStoreContract('memory', () async => MemoryDocStore());
