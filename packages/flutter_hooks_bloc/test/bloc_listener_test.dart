import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_hooks_bloc/flutter_hooks_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class CounterCubit extends Cubit<int> {
  CounterCubit() : super(0);

  void increment() => emit(state + 1);
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key, this.onListenerCalled}) : super(key: key);

  final BlocWidgetListener<int>? onListenerCalled;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late CounterCubit _counterCubit;

  @override
  void initState() {
    super.initState();
    _counterCubit = CounterCubit();
  }

  @override
  void dispose() {
    _counterCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: HookBuilder(
          builder: (context) {
            useBloc<CounterCubit, int>(
              bloc: _counterCubit,
              onEmitted: (context, _, state) {
                widget.onListenerCalled?.call(context, state);
                return false;
              },
            );
            return Column(
              children: [
                ElevatedButton(
                  key: const Key('cubit_listener_reset_button'),
                  onPressed: () {
                    setState(() => _counterCubit = CounterCubit());
                  },
                  child: null,
                ),
                ElevatedButton(
                  key: const Key('cubit_listener_noop_button'),
                  onPressed: () {
                    setState(() => _counterCubit = _counterCubit);
                  },
                  child: null,
                ),
                ElevatedButton(
                  key: const Key('cubit_listener_increment_button'),
                  onPressed: () => _counterCubit.increment(),
                  child: null,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

void main() {
  group('BlocListener', () {
    testWidgets('renders child properly', (tester) async {
      const targetKey = Key('cubit_listener_container');
      await tester.pumpWidget(
        BlocListener<CounterCubit, int>(
          bloc: CounterCubit(),
          listener: (_, __) {},
          child: const SizedBox(key: targetKey),
        ),
      );
      expect(find.byKey(targetKey), findsOneWidget);
    });

    testWidgets('calls listener on single state change', (tester) async {
      final counterCubit = CounterCubit();
      final states = <int>[];
      const expectedStates = [1];
      await tester.pumpWidget(
        BlocListener<CounterCubit, int>(
          bloc: counterCubit,
          listener: (_, state) {
            states.add(state);
          },
          child: const SizedBox(),
        ),
      );
      counterCubit.increment();
      await tester.pump();
      expect(states, expectedStates);
    });

    testWidgets('calls listener on multiple state change', (tester) async {
      final counterCubit = CounterCubit();
      final states = <int>[];
      const expectedStates = [1, 2];
      await tester.pumpWidget(
        BlocListener<CounterCubit, int>(
          bloc: counterCubit,
          listener: (_, state) {
            states.add(state);
          },
          child: const SizedBox(),
        ),
      );
      counterCubit.increment();
      await tester.pump();
      counterCubit.increment();
      await tester.pump();
      expect(states, expectedStates);
    });

    testWidgets(
        'updates when the cubit is changed at runtime to a different cubit '
        'and unsubscribes from old cubit', (tester) async {
      var listenerCallCount = 0;
      late int latestState;
      final incrementFinder = find.byKey(
        const Key('cubit_listener_increment_button'),
      );
      final resetCubitFinder = find.byKey(
        const Key('cubit_listener_reset_button'),
      );
      await tester.pumpWidget(MyApp(
        onListenerCalled: (_, state) {
          listenerCallCount++;
          latestState = state;
        },
      ));

      await tester.tap(incrementFinder);
      await tester.pump();
      expect(listenerCallCount, 1);
      expect(latestState, 1);

      await tester.tap(incrementFinder);
      await tester.pump();
      expect(listenerCallCount, 2);
      expect(latestState, 2);

      await tester.tap(resetCubitFinder);
      await tester.pump();
      await tester.tap(incrementFinder);
      await tester.pump();
      expect(listenerCallCount, 3);
      expect(latestState, 1);
    });

    testWidgets(
        'does not update when the cubit is changed at runtime to same cubit '
        'and stays subscribed to current cubit', (tester) async {
      var listenerCallCount = 0;
      late int latestState;
      final incrementFinder = find.byKey(
        const Key('cubit_listener_increment_button'),
      );
      final noopCubitFinder = find.byKey(
        const Key('cubit_listener_noop_button'),
      );
      await tester.pumpWidget(MyApp(
        onListenerCalled: (context, state) {
          listenerCallCount++;
          latestState = state;
        },
      ));

      await tester.tap(incrementFinder);
      await tester.pump();
      expect(listenerCallCount, 1);
      expect(latestState, 1);

      await tester.tap(incrementFinder);
      await tester.pump();
      expect(listenerCallCount, 2);
      expect(latestState, 2);

      await tester.tap(noopCubitFinder);
      await tester.pump();
      await tester.tap(incrementFinder);
      await tester.pump();
      expect(listenerCallCount, 3);
      expect(latestState, 3);
    });

    testWidgets(
        'calls listenWhen on single state change with correct previous '
        'and current states', (tester) async {
      late int latestPreviousState;
      var listenWhenCallCount = 0;
      final states = <int>[];
      final counterCubit = CounterCubit();
      const expectedStates = [1];
      await tester.pumpWidget(
        BlocListener<CounterCubit, int>(
          bloc: counterCubit,
          listenWhen: (previous, state) {
            listenWhenCallCount++;
            latestPreviousState = previous;
            states.add(state);
            return true;
          },
          listener: (_, __) {},
          child: const SizedBox(),
        ),
      );
      counterCubit.increment();
      await tester.pump();

      expect(states, expectedStates);
      expect(listenWhenCallCount, 1);
      expect(latestPreviousState, 0);
    });

    testWidgets(
        'calls listenWhen with previous listener state and current cubit state',
        (tester) async {
      late int latestPreviousState;
      var listenWhenCallCount = 0;
      final states = <int>[];
      final counterCubit = CounterCubit();
      const expectedStates = [2];
      await tester.pumpWidget(
        BlocListener<CounterCubit, int>(
          bloc: counterCubit,
          listenWhen: (previous, state) {
            listenWhenCallCount++;
            if ((previous + state) % 3 == 0) {
              latestPreviousState = previous;
              states.add(state);
              return true;
            }
            return false;
          },
          listener: (_, __) {},
          child: const SizedBox(),
        ),
      );
      counterCubit.increment();
      await tester.pump();
      counterCubit.increment();
      await tester.pump();
      counterCubit.increment();
      await tester.pump();

      expect(states, expectedStates);
      expect(listenWhenCallCount, 3);
      expect(latestPreviousState, 1);
    });

    testWidgets(
        'infers the cubit from the context if the cubit is not provided',
        (tester) async {
      late int latestPreviousState;
      var listenWhenCallCount = 0;
      final states = <int>[];
      final counterCubit = CounterCubit();
      const expectedStates = [1];
      await tester.pumpWidget(
        BlocProvider.value(
          value: counterCubit,
          child: BlocListener<CounterCubit, int>(
            listenWhen: (previous, state) {
              listenWhenCallCount++;
              latestPreviousState = previous;
              states.add(state);
              return true;
            },
            listener: (context, state) {},
            child: const SizedBox(),
          ),
        ),
      );
      counterCubit.increment();
      await tester.pump();

      expect(states, expectedStates);
      expect(listenWhenCallCount, 1);
      expect(latestPreviousState, 0);
    });

    testWidgets(
        'calls listenWhen on multiple state change with correct previous '
        'and current states', (tester) async {
      late int latestPreviousState;
      var listenWhenCallCount = 0;
      final states = <int>[];
      final counterCubit = CounterCubit();
      const expectedStates = [1, 2];
      await tester.pumpWidget(
        BlocListener<CounterCubit, int>(
          bloc: counterCubit,
          listenWhen: (previous, state) {
            listenWhenCallCount++;
            latestPreviousState = previous;
            states.add(state);
            return true;
          },
          listener: (_, __) {},
          child: const SizedBox(),
        ),
      );
      await tester.pump();
      counterCubit.increment();
      await tester.pump();
      counterCubit.increment();
      await tester.pump();

      expect(states, expectedStates);
      expect(listenWhenCallCount, 2);
      expect(latestPreviousState, 1);
    });

    testWidgets(
        'does not call listener when listenWhen returns false on single state '
        'change', (tester) async {
      final states = <int>[];
      final counterCubit = CounterCubit();
      const expectedStates = <int>[];
      await tester.pumpWidget(
        BlocListener<CounterCubit, int>(
          bloc: counterCubit,
          listenWhen: (_, __) => false,
          listener: (_, state) => states.add(state),
          child: const SizedBox(),
        ),
      );
      counterCubit.increment();
      await tester.pump();

      expect(states, expectedStates);
    });

    testWidgets(
        'calls listener when listenWhen returns true on single state change',
        (tester) async {
      final states = <int>[];
      final counterCubit = CounterCubit();
      const expectedStates = [1];
      await tester.pumpWidget(
        BlocListener<CounterCubit, int>(
          bloc: counterCubit,
          listenWhen: (_, __) => true,
          listener: (_, state) => states.add(state),
          child: const SizedBox(),
        ),
      );
      counterCubit.increment();
      await tester.pump();

      expect(states, expectedStates);
    });

    testWidgets(
        'does not call listener when listenWhen returns false '
        'on multiple state changes', (tester) async {
      final states = <int>[];
      final counterCubit = CounterCubit();
      const expectedStates = <int>[];
      await tester.pumpWidget(
        BlocListener<CounterCubit, int>(
          bloc: counterCubit,
          listenWhen: (_, __) => false,
          listener: (_, state) => states.add(state),
          child: const SizedBox(),
        ),
      );
      counterCubit.increment();
      await tester.pump();
      counterCubit.increment();
      await tester.pump();
      counterCubit.increment();
      await tester.pump();
      counterCubit.increment();
      await tester.pump();

      expect(states, expectedStates);
    });

    testWidgets(
        'calls listener when listenWhen returns true on multiple state change',
        (tester) async {
      final states = <int>[];
      final counterCubit = CounterCubit();
      const expectedStates = [1, 2, 3, 4];
      await tester.pumpWidget(
        BlocListener<CounterCubit, int>(
          bloc: counterCubit,
          listenWhen: (_, __) => true,
          listener: (_, state) => states.add(state),
          child: const SizedBox(),
        ),
      );
      counterCubit.increment();
      await tester.pump();
      counterCubit.increment();
      await tester.pump();
      counterCubit.increment();
      await tester.pump();
      counterCubit.increment();
      await tester.pump();

      expect(states, expectedStates);
    });
  });

  group('BlocListener diagnostics', () {
    test('does not prints the state after the widget runtimeType', () async {
      final blocListener = BlocListener<CounterCubit, int>(
        listener: (context, state) {},
        child: const SizedBox(),
      );

      expect(
        blocListener.asDiagnosticsNode().toString(),
        'BlocListener<CounterCubit, int>',
      );
    });

    test('prints the state after the widget runtimeType', () async {
      final cubit = CounterCubit();
      final blocListener = BlocListener<CounterCubit, int>(
        bloc: cubit,
        listener: (context, state) {},
        child: const SizedBox(),
      );

      expect(
        blocListener.toDiagnosticsNode().toStringDeep(),
        'BlocListener<CounterCubit, int>(state: 0)\n',
      );

      cubit.increment();

      expect(
        blocListener.toDiagnosticsNode().toStringDeep(),
        'BlocListener<CounterCubit, int>(state: 1)\n',
      );
    });
  });
}
