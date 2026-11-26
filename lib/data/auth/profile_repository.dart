import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';

/// The signed-in user, as returned by Laravel's UserResource.
@immutable
class JolUser {
  const JolUser({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.avatarUrl,
    this.bio,
    this.role,
    this.emailVerified = false,
    this.kycStatus,
    this.businessName,
    this.vatNumber,
    this.businessAddress,
    this.bank,
    this.hasIdDocument = false,
    this.hasBankStatement = false,
    this.payoutsHeld = false,
  });

  factory JolUser.fromApi(Map<String, dynamic> json) {
    String? text(String key) {
      final value = json[key];
      return value is String && value.isNotEmpty ? value : null;
    }

    final bank = json['bank'];
    return JolUser(
      id: '${json['id']}',
      name: text('name') ?? '',
      email: text('email'),
      phone: text('phone'),
      avatarUrl: text('avatar_url'),
      bio: text('bio'),
      role: text('role'),
      emailVerified: text('email_verified_at') != null,
      kycStatus: text('kyc_status'),
      businessName: text('business_name'),
      vatNumber: text('vat_number'),
      businessAddress: text('business_address'),
      bank: bank is Map ? BankSummary.fromApi(Map<String, dynamic>.from(bank)) : null,
      hasIdDocument: json['has_id_document'] == true,
      hasBankStatement: json['has_bank_statement'] == true,
      payoutsHeld: json['payouts_held'] == true,
    );
  }

  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final String? bio;
  final String? role;
  final bool emailVerified;

  /// pending, verified or rejected (ID and bank checks by the JOL team).
  final String? kycStatus;
  final String? businessName;
  final String? vatNumber;
  final String? businessAddress;
  final BankSummary? bank;
  final bool hasIdDocument;
  final bool hasBankStatement;
  final bool payoutsHeld;

  bool get kycVerified => kycStatus == 'verified';

  /// What a host still needs before JOL can pay out ticket money.
  List<String> get payoutSteps => [
    if (!emailVerified) 'Verify your email',
    if (phone == null) 'Add your mobile number',
    if (bank == null) 'Add your bank details',
    if (!hasIdDocument) 'Upload your ID',
    if (!hasBankStatement) 'Upload a bank statement',
  ];

  String get initial => name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
}

/// A photo or PDF the person picked to upload (ID document, bank statement).
@immutable
class PickedDocument {
  const PickedDocument({required this.name, required this.bytes});

  final String name;
  final List<int> bytes;

  /// The API accepts up to 4 MB.
  static const maxBytes = 4 * 1024 * 1024;
  bool get tooBig => bytes.length > maxBytes;
}

/// Payout account, as the API shows it: never the full account number.
@immutable
class BankSummary {
  const BankSummary({this.bankName, this.accountType, this.branchCode, this.last4});

  factory BankSummary.fromApi(Map<String, dynamic> json) => BankSummary(
    bankName: json['bank_name'] as String?,
    accountType: json['account_type'] as String?,
    branchCode: json['branch_code'] as String?,
    last4: json['account_last4'] as String?,
  );

  final String? bankName;
  final String? accountType;
  final String? branchCode;
  final String? last4;
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(apiClientProvider)),
);

/// Didit identity check for hosts: basic (ID + selfie) or Home Affairs when money is involved.
@immutable
class IdentityCheck {
  const IdentityCheck({
    required this.available,
    this.status,
    this.neededLevel,
    this.verified = false,
  });

  factory IdentityCheck.fromApi(Map<String, dynamic> json) => IdentityCheck(
    available: json['available'] == true,
    status: json['status'] as String?,
    neededLevel: json['needed_level'] as String?,
    verified: json['verified'] == true,
  );

  /// False until the JOL team sets Didit up.
  final bool available;
  final String? status;

  /// basic or dha (Home Affairs).
  final String? neededLevel;
  final bool verified;

  bool get needsAction => available && !verified && status != 'in_review';
}

final identityCheckProvider = FutureProvider<IdentityCheck>(
  (ref) => ref.watch(profileRepositoryProvider).identity(),
);

/// Loads GET /auth/profile. Call `ref.invalidate(currentUserProvider)` after
/// logging in, logging out or saving the profile so it reloads.
final currentUserProvider = FutureProvider<JolUser>(
  (ref) => ref.watch(profileRepositoryProvider).fetchProfile(),
);

class ProfileRepository {
  const ProfileRepository(this._dio);

  final Dio _dio;

  Future<JolUser> fetchProfile() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/auth/profile');
      return _parseUser(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<JolUser> updateProfile({String? name, String? bio}) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        '/auth/profile',
        data: {'name': ?name, 'bio': bio},
      );
      return _parseUser(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  /// Host details, payout account and documents. Files go as a multipart POST.
  /// Existing bank details can only be changed on the website (with a check).
  Future<JolUser> updateHostProfile({
    String? phone,
    String? businessName,
    String? vatNumber,
    String? businessAddress,
    Map<String, String>? bankDetails,
    PickedDocument? idDocument,
    PickedDocument? bankStatement,
  }) async {
    final fields = <String, Object?>{
      'phone': ?phone,
      // An empty string clears a field (the API stores it as empty).
      'business_name': ?businessName,
      'vat_number': ?vatNumber,
      'business_address': ?businessAddress,
      if (bankDetails != null)
        for (final entry in bankDetails.entries) 'bank_details[${entry.key}]': entry.value,
    };
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/profile',
        data: FormData.fromMap({
          ...fields,
          if (idDocument != null)
            'id_document': MultipartFile.fromBytes(idDocument.bytes, filename: idDocument.name),
          if (bankStatement != null)
            'bank_statement': MultipartFile.fromBytes(bankStatement.bytes, filename: bankStatement.name),
        }),
      );
      return _parseUser(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  /// Student status: whether verified, and which university email.
  Future<({bool verified, String? email})> studentStatus() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/student');
      final data = response.data?['data'];
      return (
        verified: data is Map && data['verified'] == true,
        email: data is Map ? data['student_email'] as String? : null,
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  /// Sends a 6-digit code (valid 24 hours), only to a university email JOL knows.
  Future<String> sendStudentCode(String email) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/student/send',
        data: {'email': email.trim()},
      );
      return response.data?['message'] as String? ?? 'Code sent.';
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<void> confirmStudentCode(String code) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/student/confirm',
        data: {'code': code.trim()},
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  /// Where the Didit identity check stands (GET /identity).
  Future<IdentityCheck> identity() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/identity');
      final data = response.data?['data'];
      return IdentityCheck.fromApi(data is Map ? Map<String, dynamic>.from(data) : const {});
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  /// Starts a Didit identity check; returns the link to open.
  Future<String> startIdentityCheck() async {
    try {
      final response = await _dio.post<Map<String, dynamic>>('/identity/start');
      final url = response.data?['data']?['url'] as String?;
      if (url == null) throw const ApiException('Couldn’t start the identity check.');
      return url;
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  /// Emails a new verification link.
  Future<String> sendEmailVerification() async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/email/verification-notification',
      );
      return response.data?['message'] as String? ?? 'Check your email.';
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  JolUser _parseUser(Map<String, dynamic>? body) {
    final data = body?['data'];
    final user = data is Map ? data['user'] : null;
    if (user is! Map) {
      throw const ApiException(
        'The profile response was not in the expected format.',
      );
    }
    return JolUser.fromApi(Map<String, dynamic>.from(user));
  }
}
