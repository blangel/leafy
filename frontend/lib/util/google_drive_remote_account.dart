import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart';
import 'package:leafy/util/google_drive_util.dart';
import 'package:leafy/util/remote_module.dart';
import 'package:tuple/tuple.dart';

class GoogleDriveRemoteAccount extends RemoteModule {

  static const _leafyGoogleDriveDirectoryName = 'Leafy Data';

  static const _leafyMnemonicFileName = 'mnemonic_phrase';

  static Future<GoogleDriveRemoteAccount> create(GoogleSignInAccount account) async {
    var util = await GoogleDriveUtil.create(account);
    return GoogleDriveRemoteAccount._(util);
  }

  final GoogleDriveUtil _driveApi;

  GoogleDriveRemoteAccount._(this._driveApi);

  @override
  Future<String?> getEncryptedSecondSeed() async {
    // first retrieve from application directory (since unmodifiable by user), fallback to user directory if not found
    var mnemonicFiles = await _driveApi.getFileFromAppDirectory(_leafyMnemonicFileName);
    if (mnemonicFiles == null || mnemonicFiles.isEmpty) {
      mnemonicFiles = await _driveApi.getFileFromDirectory(_leafyGoogleDriveDirectoryName, _leafyMnemonicFileName);
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

}