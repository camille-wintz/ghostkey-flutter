import '../config.dart';
import '../dto/projects.dart';

String _absolute(String url) {
  if (RegExp(r'^https?://', caseSensitive: false).hasMatch(url)) return url;
  return '$serverBaseUrl${url.startsWith('/') ? '' : '/'}$url';
}

/// A derived cover image's URL, or null when the project has no cover. No
/// `Authorization` header: the routes answer without a session, access control
/// being the unguessable project id in the path — which is what lets the image
/// cache work.
///
/// `?v=` is not a cache buster — the path is stable across cover changes, so
/// its presence is what tells the server the URL is safe to cache immutably.
String? _derivativeUrl(CoverThumbnail? derivative) {
  if (derivative == null) return null;
  final version = derivative.etag ?? derivative.updatedAt;
  final url = _absolute(derivative.url);
  return version != null ? '$url?v=${Uri.encodeQueryComponent(version)}' : url;
}

/// The 44px shelf thumbnail's URL, or null.
String? projectThumbnailUrl(ProjectMeta project) => _derivativeUrl(project.coverThumbnail);

/// The cover as the project home's stage light: 160px and already blurred,
/// two kilobytes rather than the cover's megabytes. The blur is the server's
/// because the phone doing it meant downloading the whole cover first and
/// holding the screen black until it had.
String? projectBackdropUrl(ProjectMeta project) => _derivativeUrl(project.coverBackdrop);

/// The full cover's URL for the project home's hero, resolved the way the
/// desktop does: `cover_filename` names an asset, the asset's id names the
/// route. Null when the project has no cover.
String? projectCoverUrl(ProjectMeta project, List<AssetMeta> assets) {
  if (project.coverFilename.isEmpty) return null;
  final asset = assets.where((a) => a.filename == project.coverFilename).firstOrNull;
  if (asset == null) return null;
  return '$serverBaseUrl/api/projects/${project.id}/assets/${asset.id}';
}
