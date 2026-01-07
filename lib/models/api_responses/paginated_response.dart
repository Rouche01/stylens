import 'package:stylens_app/models/api_responses/pagination_info.dart';

class PaginatedResponse<T> {
  final List<T> items;
  final PaginationInfo pagination;

  PaginatedResponse({required this.items, required this.pagination});

  bool get hasMore => pagination.hasNextPage;
}
