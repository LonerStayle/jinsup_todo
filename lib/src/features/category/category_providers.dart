import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/category.dart';
import '../../domain/todo.dart';

/// 특정 [Category] 의 모든 Todo (미체크 + 체크 모두) 스트림.
final watchTodosByCategoryProvider =
    StreamProvider.family<List<Todo>, Category>((ref, category) {
      final repo = ref.watch(todoRepositoryProvider);
      return repo.watchByCategory(category);
    });
