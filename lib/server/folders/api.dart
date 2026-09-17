import '../../offline/mirror.dart';
import '../client.dart';
import '../dto/json.dart';
import '../dto/projects.dart';

/// Mirrored with the project lists: the shelf opens offline.
Future<List<Folder>> listFolders() async {
  final json = await mirror.readThrough(
    'folders',
    () async => (await apiFetch('/api/folders', timeout: mirroredReadTimeout)).jsonObject(),
  );
  return asJsonList(json['folders']).map(Folder.fromJson).toList();
}

Future<Folder> createFolder({required String name, String? parentId}) async {
  final res = await apiFetch('/api/folders', method: 'POST', body: {'name': name, 'parent_id': parentId});
  return Folder.fromJson(asJson(res.jsonObject()['folder']));
}

Future<void> deleteFolder(String id) async {
  await apiFetch('/api/folders/$id', method: 'DELETE');
}
