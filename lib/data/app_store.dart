import 'mock_data_store.dart';

/// Глобална, апликациски-широка инстанца на (mock) "backend"-от.
///
/// Екраните слушаат промени преку `ListenableBuilder(listenable: appStore, ...)`.
/// Кога ќе се поврзе вистинскиот Firebase backend, оваа инстанца се менува
/// со репозиториум класи кои читаат/пишуваат во Firestore/Auth, а UI кодот
/// во screens/ останува непроменет бидејќи јавниот интерфејс е истоветен.
final MockDataStore appStore = MockDataStore();
