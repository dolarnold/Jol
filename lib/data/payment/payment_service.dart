import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/attendee/state/attendee_controller.dart';

abstract interface class PaymentService {
  Future<MockPaymentOutcome> pay({required int amount, required String method});
}

class MockPaymentService implements PaymentService {
  const MockPaymentService({
    this.outcome = MockPaymentOutcome.success,
    this.supportedMethods = const {'Card', 'Instant EFT', 'Mobile payment'},
  });

  final MockPaymentOutcome outcome;
  final Set<String> supportedMethods;

  @override
  Future<MockPaymentOutcome> pay({
    required int amount,
    required String method,
  }) async {
    final normalisedMethod = method.trim();
    if (normalisedMethod.isEmpty || amount <= 0) {
      return MockPaymentOutcome.declined;
    }

    if (!supportedMethods.contains(normalisedMethod)) {
      return MockPaymentOutcome.declined;
    }

    await Future<void>.delayed(const Duration(milliseconds: 350));
    return outcome;
  }
}

final paymentServiceProvider = Provider<PaymentService>(
  (ref) => const MockPaymentService(),
);
