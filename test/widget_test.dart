import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:multimodal_memory_agent/core/database/memory_repository.dart';
import 'package:multimodal_memory_agent/core/network/qwen_service.dart';
import 'package:multimodal_memory_agent/features/memory_agent/bloc/memory_agent_bloc.dart';
import 'package:multimodal_memory_agent/main_entry/app.dart';

void main() {
  testWidgets('shows the empty-state message on first load', (tester) async {
    // shared_preferences needs its platform channel mocked in widget tests -
    // this in-memory fake is the officially supported way to do that.
    SharedPreferences.setMockInitialValues({});

    final bloc = MemoryAgentBloc(
      qwenService: QwenService(),
      memoryRepository: MemoryRepository(),
    );
    addTearDown(bloc.close);

    await tester.pumpWidget(
      BlocProvider<MemoryAgentBloc>.value(
        value: bloc,
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your knowledge bank is empty'), findsOneWidget);
    expect(find.text('Memory Agent'), findsOneWidget);
  });
}
