import '../client.dart';
import '../dto/json.dart';
import '../dto/projects.dart';

Future<List<Folder>> listFolders() async {
  final res = await apiFetch('/api/folders');
  return asJsonList(res.jsonObject()['folders']).map(Folder.fromJson).toList();
}

Future<Folder> createFolder({required String name, String? parentId}) async {
  final res = await apiFetch('/api/folders', method: 'POST', body: {'name': name, 'parent_id': parentId});
  return Folder.fromJson(asJson(res.jsonObject()['folder']));
}

Future<void> deleteFolder(String id) async {
  await apiFetch('/api/folders/$id', method: 'DELETE');
}
