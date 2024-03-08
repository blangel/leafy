
import 'dart:convert';
import 'dart:developer';

import 'package:cloud_kit/cloud_kit.dart';
import 'package:leafy/util/remote_module.dart';

class AppleICloudRemoteAccount extends RemoteModule {

  static const _leafyICloudContainerId = 'iCloud.com.leafybitcoin.leafy';

  static const _leafyMnemonicFileName = 'mnemonic_phrase';

  static const _leafyCompanionFileNamePrefix = 'companion';

  static const _leafyCompanionIdFileName = 'companion_files';

  static AppleICloudRemoteAccount create() {
    return AppleICloudRemoteAccount._();
  }

  final CloudKit _cloudKit = CloudKit(_leafyICloudContainerId);

  AppleICloudRemoteAccount._();

  Future<bool> isLoggedIn() async {
    var status = await _cloudKit.getAccountStatus();
    return status == CloudKitAccountStatus.available;
  }

  Future<String?> getUserId() async {
    // iCloud doesn't expose ID directly and doesn't enforce user to setup an email.
    // Even if email present, requires permission check. Instead, simply get the
    // per-application persistent id as the remote-account-id. A drawback here
    // is the id is not user-friendly or recognizable
    return await _cloudKit.getUserId();
  }

  @override
  Future<String?> getCompanionData(String companionId) async {
    String companionFileName = _getCompanionFileName(companionId);
    return await _cloudKit.get(companionFileName);
  }

  @override
  Future<List<String>> getCompanionIds() async {
    String? companionIds = await _cloudKit.get(_leafyCompanionIdFileName);
    if (companionIds == null) {
      return [];
    }
    List<String> ids = jsonDecode(companionIds);
    return ids;
  }

  Future<void> _persistCompanionIds(List<String> ids) async {
    String idsJson = jsonEncode(ids);
    await _cloudKit.save(_leafyCompanionIdFileName, idsJson);
  }

  @override
  Future<String?> getEncryptedSecondSeed() async {
    return await _cloudKit.get(_leafyMnemonicFileName);
  }

  @override
  Future<bool> persistCompanionData(String companionId, String encryptedData) async {
    List<String> existingIds = await getCompanionIds();
    if (!existingIds.contains(companionId)) {
      List<String> expanded = [];
      expanded.addAll(existingIds);
      expanded.add(companionId);
      await _persistCompanionIds(expanded);
    }
    String companionFileName = _getCompanionFileName(companionId);
    await _cloudKit.save(companionFileName, encryptedData);
    String? persistedCompanionData = await getCompanionData(companionId);
    return persistedCompanionData == encryptedData;
  }

  @override
  Future<bool> persistEncryptedSecondSeed(String encryptedSecondSeed, SecondSeedValidator validator) async {
    await _cloudKit.save(_leafyMnemonicFileName, encryptedSecondSeed);
    String? persistedContent = await getEncryptedSecondSeed();
    if (persistedContent == null) {
      return false;
    }
    return validator.validate(persistedContent);
  }

  @override
  RemoteModuleProvider getProvider() {
    return RemoteModuleProvider.apple;
  }

  static String _getCompanionFileName(String companionId) {
    return "${_leafyCompanionFileNamePrefix}_$companionId";
  }

}