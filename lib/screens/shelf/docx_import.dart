import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../../server/dto/jobs.dart';
import '../../server/dto/projects.dart';
import '../../server/errors.dart';
import '../../server/jobs/run_job.dart';
import '../../server/projects/api.dart';

/// A manuscript arriving from a desk: a `.docx` picked on the phone becomes a
/// new project whose chapters are split out of the document's headings.
///
/// The desktop offers this beside Create, and so does the shelf, but the two
/// are not the same call. The server route is additive — it imports into a
/// project that already exists and never makes one — so "import a book" is
/// three steps here, and the middle one can fail after the first has already
/// written a row. That is the whole reason this is a module rather than a
/// handler: the empty project has to be cleaned up, and a half-imported book
/// left on someone's shelf is worse than an import that plainly failed.

/// The size the server refuses at (`IMPORT_MAX_BYTES`). Checked here as well
/// so a 40 MB file is a sentence rather than a long upload ending in a 413.
const int _maxBytes = 20 * 1024 * 1024;

sealed class DocxImport {
  const DocxImport();
}

/// The picker closed with nothing chosen. Not a failure, and says nothing.
class DocxImportCancelled extends DocxImport {
  const DocxImportCancelled();
}

class DocxImportFailed extends DocxImport {
  const DocxImportFailed(this.message);
  final String message;
}

class DocxImportDone extends DocxImport {
  const DocxImportDone({required this.project, required this.chapters});
  final ProjectMeta project;

  /// What the job says it wrote, or null when it finished without saying.
  final int? chapters;
}

/// How long to follow the import before giving up on watching it. The job
/// keeps running on the server either way — this is patience, not a deadline —
/// but a hundred-chapter book is minutes, so it is generous.
const Duration _watchTimeout = Duration(minutes: 10);

/// Pick a `.docx`, make a project of it, and follow the import to the end.
///
/// [onProgress] is called with a line to put under the button. [isAlive] lets
/// the caller stop the watch when the screen goes away; the import itself is
/// server-side and finishes regardless.
Future<DocxImport> importDocxAsProject({
  required void Function(String line) onProgress,
  required bool Function() isAlive,
}) async {
  onProgress('Choosing a file…');

  final PlatformFile? file;
  try {
    file = await FilePicker.pickFile(
      dialogTitle: 'Choose a manuscript',
      // `custom` + an extension list rather than a mime type: Android's
      // document picker takes the extension, and a .docx offered by Drive or
      // by a mail attachment arrives under half a dozen different mime types.
      type: FileType.custom,
      allowedExtensions: const ['docx'],
    );
  } catch (e) {
    return DocxImportFailed('The file picker would not open. $e');
  }
  if (file == null) return const DocxImportCancelled();

  final name = file.name;
  if (file.extension?.toLowerCase() != 'docx') {
    return const DocxImportFailed(
      'That is not a Word document. Ghostkey imports .docx files — the format Word, '
      'Pages and Google Docs all export.',
    );
  }

  // Asked before the bytes are read: the file that has to be refused is the
  // big one, and reading it first to find out how big it is puts a phone's
  // whole memory behind the answer.
  int size;
  try {
    size = await file.length();
  } catch (e) {
    return DocxImportFailed('That file could not be read. $e');
  }
  if (size <= 0) return const DocxImportFailed('That file is empty.');
  if (size > _maxBytes) {
    return DocxImportFailed(
      'That document is ${(size / (1024 * 1024)).toStringAsFixed(1)} MB, and the import '
      'takes up to ${_maxBytes ~/ (1024 * 1024)} MB. A manuscript that large is usually '
      'carrying images — save a copy without them and import that.',
    );
  }

  final Uint8List bytes;
  try {
    bytes = await file.readAsBytes();
  } catch (e) {
    return DocxImportFailed('That file could not be read. $e');
  }

  final title = _titleFrom(name);
  onProgress('Making the project…');

  final ProjectMeta project;
  try {
    project = await _createUnderAFreeName(title);
  } catch (e) {
    return DocxImportFailed(messageFor(e));
  }

  try {
    onProgress('Sending $name…');
    final started = await importProjectDocx(project.id, bytes, name);
    onProgress(_lineFor(started.job) ?? 'Reading the document…');

    final outcome = await awaitJob(
      project.id,
      started.job,
      JobWatch(
        timeout: _watchTimeout,
        isAlive: isAlive,
        onSnapshot: (job) {
          final line = _lineFor(job);
          if (line != null) onProgress(line);
        },
      ),
    );

    switch (outcome) {
      case JobFinished(job: final job):
        if (job != null && job.status == JobStatus.error) {
          await _discard(project.id);
          return DocxImportFailed(job.errorDetail ?? 'The import did not finish.');
        }
        if (job != null && job.status == JobStatus.cancelled) {
          await _discard(project.id);
          return const DocxImportFailed('The import was cancelled.');
        }
        return DocxImportDone(project: project, chapters: job?.progress?.total);
      // The book is being written on the server; the project is real and the
      // chapters will be in it. Opening it is the honest end of both.
      case JobAbandoned():
      case JobTimedOut():
        return DocxImportDone(project: project, chapters: null);
    }
  } catch (e) {
    await _discard(project.id);
    return DocxImportFailed(messageFor(e));
  }
}

/// Project names are unique per account, and importing the same file twice is
/// a thing people do — a revised manuscript exported under the name it had
/// before. So a collision gets a number rather than an error, the way a
/// download folder does; the displayed title is left alone.
Future<ProjectMeta> _createUnderAFreeName(String title) async {
  final base = slugifyProjectName(title);
  for (var attempt = 0; ; attempt++) {
    final name = attempt == 0 ? base : '${base}_${attempt + 1}';
    try {
      return await createProject(name: name, title: title);
    } on ServerError catch (e) {
      if (e.code != 'name_taken' || attempt >= 20) rethrow;
    }
  }
}

/// Take back the empty project an import never filled. Best-effort: a project
/// that will not delete is a strange shelf entry, not a reason to replace the
/// error the author actually needs to read.
Future<void> _discard(String projectId) async {
  try {
    await deleteProject(projectId);
  } catch (_) {}
}

String? _lineFor(JobSnapshot job) {
  final progress = job.progress;
  if (progress == null) return null;
  if (progress.indeterminate || progress.total <= 0) {
    return progress.label.isEmpty ? null : progress.label;
  }
  final label = progress.label.isEmpty ? 'Importing' : progress.label;
  return '$label — ${progress.current} of ${progress.total}';
}

/// "The Hollow Crown - final draft (2).docx" → "The Hollow Crown - final draft".
String _titleFrom(String filename) {
  final stem = filename.replaceAll(RegExp(r'\.docx$', caseSensitive: false), '').trim();
  return stem.isEmpty ? 'Imported manuscript' : stem;
}

/// The project's `name` — its filename-shaped identifier, as distinct from the
/// title it is displayed under.
String slugifyProjectName(String title) {
  final slug = title.replaceAll(RegExp(r'[^\w\s.-]'), '').replaceAll(RegExp(r'\s+'), '_');
  final cut = slug.length > 60 ? slug.substring(0, 60) : slug;
  return cut.isEmpty ? 'project' : cut;
}
