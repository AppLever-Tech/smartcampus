import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:smartcampus/data/mock_master_data.dart';

class FirebaseAuthService {
  String? verificationId;
  ConfirmationResult? confirmationResult;
  String? lastLookupError;

  Future<OrgUserRoleMappingItem?> getRoleByUuid(String uuid) async {
    final user = await getUserByUuid(uuid);
    if (user == null || user.normalizedUserRole.isEmpty) {
      return null;
    }
    return OrgUserRoleMappingItem.fromUserMaster(user);
  }

  Future<OrgUserRoleMappingItem?> getRoleByUuidAndOrgId(
    String uuid,
    String orgId,
  ) async {
    final user = await getUserByUuid(uuid);
    if (user == null) {
      return null;
    }
    final normOrg = orgId.trim().toUpperCase();
    final userOrg = user.orgId.trim().toUpperCase();
    if (userOrg.isNotEmpty && userOrg != normOrg) {
      return null;
    }
    if (user.normalizedUserRole.isEmpty) {
      return null;
    }
    return OrgUserRoleMappingItem.fromUserMaster(user);
  }

  Future<UserMasterItem?> getUserByUuid(String uuid) async {
    lastLookupError = null;
    try {
      final candidates = uuidCandidates(uuid);
      for (final candidate in candidates) {
        final query = await FirebaseFirestore.instance
            .collection('smcUserMaster')
            .where('uuid', isEqualTo: candidate)
            .limit(1)
            .get();

        if (query.docs.isNotEmpty) {
          return UserMasterItem.fromMap(query.docs.first.data());
        }
      }

      final allDocs = await FirebaseFirestore.instance
          .collection('smcUserMaster')
          .limit(200)
          .get();
      for (final doc in allDocs.docs) {
        final data = doc.data();
        final dbUuid = normalizeUuidForCompare(data['uuid']);
        if (dbUuid.isEmpty) {
          continue;
        }
        for (final candidate in candidates) {
          if (dbUuid == normalizeUuidForCompare(candidate)) {
            return UserMasterItem.fromMap(data);
          }
        }
      }
      return null;
    } catch (error) {
      lastLookupError = error.toString();
      return null;
    }
  }

  Future<OrganizationItem?> getOrganizationById(String orgId) async {
    lastLookupError = null;
    final normalizedOrgId = orgId.trim().toUpperCase();
    if (normalizedOrgId.isEmpty) {
      return null;
    }

    try {
      for (final collectionName in <String>[
        'smcOrganizations',
      ]) {
        final queryByUniqueId = await FirebaseFirestore.instance
            .collection(collectionName)
            .where('org_unique_id', isEqualTo: normalizedOrgId)
            .limit(1)
            .get();
        if (queryByUniqueId.docs.isNotEmpty) {
          final doc = queryByUniqueId.docs.first;
          return OrganizationItem.fromMap(doc.data(), documentId: doc.id);
        }

        final queryByOrgId = await FirebaseFirestore.instance
            .collection(collectionName)
            .where('org_id', isEqualTo: normalizedOrgId)
            .limit(1)
            .get();
        if (queryByOrgId.docs.isNotEmpty) {
          final doc = queryByOrgId.docs.first;
          return OrganizationItem.fromMap(doc.data(), documentId: doc.id);
        }
      }

      return null;
    } catch (error) {
      lastLookupError = error.toString();
      return null;
    }
  }

  Future<void> sendOtp({
    required String mobileOrUuid,
    required VoidCallback onCodeSent,
    required VoidCallback onAutoVerified,
    required ValueChanged<String> onError,
  }) async {
    final phoneNumber = normalizeIndianPhoneNumber(mobileOrUuid);
    if (phoneNumber == null) {
      onError('Enter valid mobile number');
      return;
    }

    try {
      if (kIsWeb) {
        confirmationResult = await FirebaseAuth.instance.signInWithPhoneNumber(
          phoneNumber,
        );
        onCodeSent();
        return;
      }

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (credential) async {
          await FirebaseAuth.instance.signInWithCredential(credential);
          onAutoVerified();
        },

        verificationFailed: (exception) {
          onError(exception.message ?? 'OTP send failed');
        },

        codeSent: (verId, resendToken) {
          verificationId = verId;
          onCodeSent();
        },

        codeAutoRetrievalTimeout: (verId) {
          verificationId = verId;
        },

      );
    } catch (error) {
      onError('Unable to send OTP: $error');
    }
  }

  Future<bool> verifyOtp({
    required String otpCode,
    required ValueChanged<String> onError,
  }) async {
    try {
      if (kIsWeb) {
        if (confirmationResult == null) {
          onError('Please request OTP first');
          return false;
        }
        await confirmationResult!.confirm(otpCode);
        return true;
      }

      if (verificationId == null) {
        onError('Please request OTP first');
        return false;
      }

      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId!,
        smsCode: otpCode,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      return true;
    } on FirebaseAuthException catch (error) {
      onError(error.message ?? 'Invalid OTP');
      return false;
    } catch (_) {
      onError('Invalid OTP');
      return false;
    }
  }

  List<String> uuidCandidates(String input) {
    final trimmed = input.trim();
    final digitsOnly = trimmed.replaceAll(RegExp(r'\D'), '');
    final values = <String>{trimmed, digitsOnly};

    if (digitsOnly.length == 10) {
      values.add('91$digitsOnly');
      values.add('+91$digitsOnly');
    } else if (digitsOnly.length == 12 && digitsOnly.startsWith('91')) {
      final withoutCountry = digitsOnly.substring(2);
      values.add(withoutCountry);
      values.add('+$digitsOnly');
    } else if (trimmed.startsWith('+91') && digitsOnly.length == 12) {
      values.add(digitsOnly);
      values.add(digitsOnly.substring(2));
    }
    return values.where((v) => v.isNotEmpty).toList();
  }

  String? normalizeIndianPhoneNumber(String value) {
    final digitsOnly = value.trim().replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length == 10) {
      return '+91$digitsOnly';
    }
    if (digitsOnly.length == 12 && digitsOnly.startsWith('91')) {
      return '+$digitsOnly';
    }
    return null;
  }

  String normalizeFirestoreValue(Object? value) {
    if (value == null) {
      return '';
    }
    return value.toString().trim();
  }

  String normalizeUuidForCompare(Object? value) {
    final raw = normalizeFirestoreValue(value);
    final digitsOnly = raw.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length == 10) {
      return '91$digitsOnly';
    }
    if (digitsOnly.length == 12 && digitsOnly.startsWith('91')) {
      return digitsOnly;
    }
    return digitsOnly;
  }
}
