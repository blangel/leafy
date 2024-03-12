
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
    List<dynamic> idsJson = jsonDecode(companionIds);
    List<String> ids = [];
    for (var id in idsJson) {
      ids.add(id);
    }
    return ids;
  }

  Future<bool> _persistCompanionIds(List<String> ids) async {
    String idsJson = jsonEncode(ids);
    return await _cloudKit.save(_leafyCompanionIdFileName, idsJson);
  }

  @override
  Future<String?> getEncryptedSecondSeed() async {
    return await _cloudKit.get(_leafyMnemonicFileName);
  }

  @override
  Future<bool> persistCompanionData(String companionId, String encryptedData) async {
    log("apple icloud: getting companion ids");
    List<String> existingIds = await getCompanionIds();
    log("apple icloud: existingIds? $existingIds");
    if (!existingIds.contains(companionId)) {
      List<String> expanded = [];
      expanded.addAll(existingIds);
      expanded.add(companionId);
      var success = await _persistCompanionIds(expanded);
      if (!success) {
        log("apple icloud: failure persisting new companionId");
        return false;
      }
    }
    String companionFileName = _getCompanionFileName(companionId);
    var success = await _cloudKit.save(companionFileName, encryptedData);
    if (!success) {
      log("apple icloud: failure persisting encrypted second seed");
      return false;
    }
    String? persistedCompanionData = await getCompanionData(companionId);
    int counter = 0;
    while ((persistedCompanionData == null) && (counter < 5)) {
      await Future.delayed(const Duration(seconds: 1));
      persistedCompanionData = await getCompanionData(companionId);
      counter = counter + 1;
    }
    return persistedCompanionData == encryptedData;
  }

  @override
  Future<bool> persistEncryptedSecondSeed(String encryptedSecondSeed, SecondSeedValidator validator) async {
    var success = await _cloudKit.save(_leafyMnemonicFileName, encryptedSecondSeed);
    if (!success) {
      log("apple icloud: failure persisting encrypted second seed");
      return false;
    }
    String? persistedContent = await getEncryptedSecondSeed();
    int counter = 0;
    while ((persistedContent == null) && (counter < 5)) {
      await Future.delayed(const Duration(seconds: 1));
      persistedContent = await getEncryptedSecondSeed();
      counter = counter + 1;
    }
    if (persistedContent == null) {
      log("apple icloud: could not load encrypted second seed");
      return false;
    }
    return validator.validate(persistedContent);
  }

  @override
  RemoteModuleProvider getProvider() {
    return RemoteModuleProvider.apple;
  }

  static String _getCompanionFileName(String companionId) {
    // https://developer.apple.com/documentation/cloudkit/ckrecord/id/1500975-init indicates that recordName
    // must be less than 255 and ASCII but in practice it cannot contain '@' or '.', so normalizing
    return "${_leafyCompanionFileNamePrefix}_$companionId".replaceAll("@", "_at_").replaceAll(".", "_dot_");
  }

}