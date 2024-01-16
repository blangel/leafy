
import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart';
import 'package:leafy/util/google_signin_util.dart';
import 'package:tuple/tuple.dart';

const _leafyGoogleDriveDirectoryName = 'Leafy Data';

const _leafyMnemonicFileName = 'mnemonic_phrase';

const _googleDriveFolderMimeType = 'application/vnd.google-apps.folder';


class GoogleDriveUtil {

  static Future<GoogleDriveUtil> create(GoogleSignInAccount account) async {
    final authenticateClient = await GoogleAuthClient.create(account);
    final googleDriveApi = DriveApi(authenticateClient);
    return GoogleDriveUtil._(googleDriveApi);
  }

  final DriveApi _driveApi;

  GoogleDriveUtil._(this._driveApi);

  Future<File?> getMnemonicFile() async {
    final directoryPair = await _getLeafyMnemonic();
    if (directoryPair == null || directoryPair.item2 == null) {
      return null;
    }
    return directoryPair.item2;
  }

  Future<Tuple2<File, File?>?> _getLeafyMnemonic() async {
    var response = await _driveApi.files.list(q: "name='$_leafyGoogleDriveDirectoryName' and mimeType='$_googleDriveFolderMimeType'");
    if (response.files == null || response.files!.isEmpty) {
      return null;
    } else {
      // TODO - what to do on multiple matches (could ask for passphrase and limit to what matches, then further limit to which correspond to valid bitcoin addresses) [currently, take first]
      for (var folder in response.files!) {
        var mnemonicFile = await _getLeafyMnemonicFileInDirectory(folder);
        if (mnemonicFile != null) {
          return Tuple2(folder, mnemonicFile);
        }
      }
      return Tuple2(response.files!.first, null);
    }
  }

  Future<File?> _getLeafyMnemonicFileInDirectory(File directory) async {
    // TODO - what to do on multiple matches (could ask for passphrase and limit to what matches, then further limit to which correspond to valid bitcoin addresses) [currently, take first]
    var response = await _driveApi.files.list(q: "'${directory.id}' in parents and name='$_leafyMnemonicFileName'", $fields: "files(id, name, mimeType, trashed, parents)");
    if (response.files == null || response.files!.isEmpty) {
      return null;
    } else {
      return response.files!.first;
    }
  }

  Future<File> _getLeafyDirectoryOrCreate() async {
    File directory;
    var directoryPair = await _getLeafyMnemonic();
    if (directoryPair == null) {
      File leafyFolder = File()
        ..name = _leafyGoogleDriveDirectoryName
        ..mimeType = _googleDriveFolderMimeType;
      directory = await _driveApi.files.create(leafyFolder, useContentAsIndexableText: false, keepRevisionForever: true);
    } else {
      directory = directoryPair.item1;
    }
    return directory;
  }

  Future<String> createAndRetrieveMnemonicFile(String mnemonicPhraseEncrypted) async {
    final directory = await _getLeafyDirectoryOrCreate();

    var mnemonicPhraseFile = File()
      ..name = _leafyMnemonicFileName
      ..mimeType = 'text/plain'
      ..parents = [directory.id!];
    List<int> mnemonicPhraseBytes = utf8.encode(mnemonicPhraseEncrypted);
    Stream<List<int>> mnemonicPhraseStream = Stream.fromIterable([mnemonicPhraseBytes]);
    var media = Media(mnemonicPhraseStream, mnemonicPhraseBytes.length);
    final createdFile = await _driveApi.files.create(mnemonicPhraseFile, uploadMedia: media,
        useContentAsIndexableText: false, keepRevisionForever: true);
    // now verify the value persisted correctly by rereading it
    return getContent(createdFile.id!);
  }

  Future<String> getContent(String fileId) async {
    final retrievedFileMedia = await _driveApi.files.get(fileId, downloadOptions: DownloadOptions.fullMedia) as Media;
    final retrievedFileStream = retrievedFileMedia.stream.transform(utf8.decoder);
    return await retrievedFileStream.join();
  }

  Future<void> restore(File trashed) async {
    await _restoreItem(trashed.id!);
  }

  Future<void> _restoreItem(String id) async {
    var item = await _driveApi.files.get(id, $fields: 'id,name,trashed,parents') as File;
    if (item.parents != null && item.parents!.isNotEmpty) {
      for (var parentId in item.parents!) {
        await _restoreItem(parentId);
      }
    }
    if (item.trashed == true) {
      await _driveApi.files.update(File()..trashed = false, id);
    }
  }

}