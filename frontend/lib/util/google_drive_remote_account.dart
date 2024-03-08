import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart';
import 'package:leafy/util/google_drive_util.dart';
import 'package:leafy/util/remote_module.dart';
import 'package:tuple/tuple.dart';

class GoogleDriveRemoteAccount extends RemoteModule {

  static const _leafyGoogleDriveDirectoryName = 'Leafy Data';

  static const _leafyMnemonicFileName = 'mnemonic_phrase';

  static const _leafyCompanionFileNamePrefix = 'companion';

  static Future<GoogleDriveRemoteAccount> create(GoogleSignInAccount account) async {
    var util = await GoogleDriveUtil.create(account);
    return GoogleDriveRemoteAccount._(util);
  }

  final GoogleDriveUtil _driveApi;

  GoogleDriveRemoteAccount._(this._driveApi);

  // Retrieves the Second Seed encrypted value from the user's Google Drive account, first
  // pulling from the application directory and if not present pulling from the user drive directly.
  // If found, the data is encrypted and will need to be decrypted based on 'First Seed'.
  @override
  Future<String?> getEncryptedSecondSeed() async {
    // first retrieve from application directory (since unmodifiable by user), fallback to user directory if not found
    var mnemonicFiles = await _driveApi.getFileFromAppDirectory(_leafyMnemonicFileName, false);
    if (mnemonicFiles == null || mnemonicFiles.isEmpty) {
      mnemonicFiles = await _driveApi.getFileFromDirectory(_leafyGoogleDriveDirectoryName, _leafyMnemonicFileName, false);
      if (mnemonicFiles == null) {
        return null;
      }
      String? content = await _restoreAndGetContent(mnemonicFiles);
      if (content != null) {
        _persistEncryptedSecondSeedInAppDirectory(content);
      }
      return content;
    }
    return _restoreAndGetContent(mnemonicFiles);
  }

  Future<String?> _restoreAndGetContent(List<Tuple2<File, List<File>?>> files) async {
    // TODO - what to do on multiple matches (could ask for passphrase and limit to what matches, then further limit to which correspond to valid bitcoin addresses) [currently, take first]
    var mnemonicFile = files.first.item2!.first;
    if ((mnemonicFile.trashed != null) && mnemonicFile.trashed!) {
      await _driveApi.restore(mnemonicFile);
    }
    return _driveApi.getContent(mnemonicFile.id!);
  }

  // Persists 'encryptedSecondSeed' within the application directory and directly within the user drive.
  // Note, callers should first encrypt data based on 'First Seed'.
  @override
  Future<bool> persistEncryptedSecondSeed(String encryptedSecondSeed, SecondSeedValidator validator) async {
    // store in both Google Drive application directory and a user accessible directory
    final retrievedFileContentFromAppDirectory = await _persistEncryptedSecondSeedInAppDirectory(encryptedSecondSeed);
    if (!validator.validate(retrievedFileContentFromAppDirectory)) {
      return false;
    }
    final retrievedFileContent = await _driveApi.createAndRetrieveFile(_leafyGoogleDriveDirectoryName, _leafyMnemonicFileName, encryptedSecondSeed);
    return validator.validate(retrievedFileContent);
  }

  Future<String> _persistEncryptedSecondSeedInAppDirectory(String encryptedSecondSeed) async {
    return await _driveApi.createAndRetrieveFileFromAppDirectory(_leafyMnemonicFileName, encryptedSecondSeed);
  }

  // Persists 'encryptedData' within the application directory on behalf of companionId. Note, callers should
  // first encrypt data based on 'First Seed'.
  @override
  Future<bool> persistCompanionData(String companionId, String encryptedData) async {
    String companionFileName = _getCompanionFileName(companionId);
    var existing = await _driveApi.getFileFromAppDirectory(companionFileName, false);
    if (existing == null || existing.isEmpty) {
      String persisted = await _driveApi.createAndRetrieveFileFromAppDirectory(_getCompanionFileName(companionId), encryptedData);
      return (persisted == encryptedData);
    } else {
      var companionFile = existing.first.item2!.first;
      String persisted = await _driveApi.updateFile(companionFile, encryptedData);
      return (persisted == encryptedData);
    }
  }

  // Retrieves persisted data within the application directory on behalf of companionId. If found, the data
  // is encrypted and will need to be decrypted based on 'First Seed'.
  @override
  Future<String?> getCompanionData(String companionId) async {
    var results = await _driveApi.getFileFromAppDirectory(_getCompanionFileName(companionId), false);
    if (results == null || results.isEmpty) {
      return null;
    }
    var companionFile = results.first.item2!.first;
    return await _driveApi.getContent(companionFile.id!);
  }

  // Retrieves companion ids for any with persisted data within the user's remote account.
  @override
  Future<List<String>> getCompanionIds() async {
    var results = await _driveApi.getFileFromAppDirectory(_leafyCompanionFileNamePrefix, true);
    if ((results == null) || results.isEmpty || results.first.item2 == null) {
      return List.empty();
    }
    return results.first.item2!.where((file) => file.name != null).map((file) => file.name!).toList();
  }

  @override
  RemoteModuleProvider getProvider() {
    return RemoteModuleProvider.google;
  }

  static String _getCompanionFileName(String companionId) {
    return "${_leafyCompanionFileNamePrefix}_$companionId";
  }
}