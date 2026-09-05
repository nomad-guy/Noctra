import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/search/domain/search_repository_contract.dart';
import '../features/search/application/search_coordinator.dart';
import '../features/search/infrastructure/search_repository_impl.dart';

// Search Subsystem Modular Contract Providers
final searchRepositoryContractProvider =
    Provider<SearchRepositoryContract>((ref) {
  return SearchRepositoryImpl();
});

final searchCoordinatorProvider = Provider<SearchCoordinator>((ref) {
  return SearchCoordinator(ref.watch(searchRepositoryContractProvider));
});
