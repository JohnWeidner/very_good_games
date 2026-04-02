import 'package:bloc/bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:very_good_games/app/app_bloc_observer.dart';

void main() {
  group('AppBlocObserver', () {
    test('can be instantiated', () {
      expect(const AppBlocObserver(), isNotNull);
    });

    test('onChange does not throw', () {
      const observer = AppBlocObserver();
      const change = Change(currentState: 0, nextState: 1);

      expect(() => observer.onChange(_FakeBloc(), change), returnsNormally);
    });

    test('onError does not throw', () {
      const observer = AppBlocObserver();

      expect(
        () => observer.onError(
          _FakeBloc(),
          Exception('test'),
          StackTrace.current,
        ),
        returnsNormally,
      );
    });
  });
}

class _FakeBloc extends Cubit<int> {
  _FakeBloc() : super(0);
}
