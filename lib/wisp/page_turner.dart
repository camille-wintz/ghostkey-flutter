import '../server/dto/wisp.dart';

/// Turning a beta reader's book: a page at a time, or a comment at a time —
/// which opens the page it's on. Turning to a page picks its first comment.
/// The same walk as the desk's `usePageTurner`; the pages and where each
/// comment sits are the server's. Immutable: every step is a new turner, and a
/// null step is one there is nowhere to take.
class PageTurner {
  PageTurner._(this.pages, this._comments, int page, int? active)
      : page = pages.isEmpty ? 0 : page.clamp(0, pages.length - 1),
        active = active != null && active >= 0 && active < _comments.length ? active : null;

  /// Opens on the first page, its first comment picked.
  factory PageTurner(List<BookPage> pages, List<PlacedBetaComment> comments) =>
      PageTurner._(pages, comments, 0, _firstOn(comments, 0));

  factory PageTurner.of(CommentedBook book) => PageTurner(book.pages, book.comments);

  final List<BookPage> pages;
  final List<PlacedBetaComment> _comments;

  /// The page open, 0-based.
  final int page;

  /// The comment picked — its passage marked on the page — or null.
  final int? active;

  int get pageCount => pages.length;
  int get commentCount => _comments.length;
  List<PlacedBetaComment> get comments => _comments;

  BookPage? get openPage => pages.isEmpty ? null : pages[page];
  PlacedBetaComment? get activeComment => active == null ? null : _comments[active!];

  /// The comments on the open page, in reading order, with their place in the
  /// whole list.
  List<({PlacedBetaComment comment, int index})> get onPage => [
        for (var i = 0; i < _comments.length; i++)
          if (_comments[i].page == page) (comment: _comments[i], index: i),
      ];

  static int? _firstOn(List<PlacedBetaComment> comments, int page) {
    final at = comments.indexWhere((c) => c.page == page);
    return at >= 0 ? at : null;
  }

  PageTurner toPage(int p) => PageTurner._(pages, _comments, p, _firstOn(_comments, p));
  PageTurner toComment(int i) => PageTurner._(pages, _comments, _comments[i].page, i);

  // With no comment picked, the next one is the first from this page on, the
  // previous one the last before it.
  int get _next => active != null ? active! + 1 : _comments.indexWhere((c) => c.page >= page);
  int get _prev => active != null ? active! - 1 : _comments.where((c) => c.page < page).length - 1;

  PageTurner? get prevPage => page > 0 ? toPage(page - 1) : null;
  PageTurner? get nextPage => page < pages.length - 1 ? toPage(page + 1) : null;
  PageTurner? get prevComment => _prev >= 0 ? toComment(_prev) : null;
  PageTurner? get nextComment => _next >= 0 && _next < _comments.length ? toComment(_next) : null;
}
