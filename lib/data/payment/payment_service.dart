import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/attendee/state/attendee_controller.dart';

abstract interface class PaymentService {
  Future<MockPaymentOutcome> pay({required int amount, required String method});
}

class MockPaymentService implements PaymentService {
  const MockPaymentService({this.outcome = MockPaymentOutcome.success});

  final MockPaymentOutcome outcome;

  @override
  Future<MockPaymentOutcome> pay({
    required int amount,
    required String method,
  }) async {
    // TODO(backend): Replace this mock with the payment API contract.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return outcome;
  }
}

final paymentServiceProvider = Provider<PaymentService>(
  (ref) => const MockPaymentService(),
);
