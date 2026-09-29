import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/server/dto/wisp.dart';
import 'package:ghostkey/wisp/page_turner.dart';

BookPage _page(String chapter) => BookPage(chapter: chapter, blocks: const []);

PlacedBetaComment _on(int page) => PlacedBetaComment(
      chapter: 'c.md',
      reaction: BetaReaction.hooked,
      note: 'on $page',
      quote: null,
      page: page,
      at: null,
    );

void main() {
  // Five pages; comments on pages 1, 1 and 3.
  final pages = [for (var i = 0; i < 5; i++) _page('c$i.md')];
  final comments = [_on(1), _on(1), _on(3)];

  test('opens on the first page, with its first comment picked (none here)', () {
    final t = PageTurner(pages, comments);
    expect(t.page, 0);
    expect(t.active, isNull);
    expect(t.onPage, isEmpty);
    expect(t.prevPage, isNull);
    expect(t.prevComment, isNull);
    expect(t.pageCount, 5);
    expect(t.commentCount, 3);
  });

  test('turning to a page picks its first comment', () {
    final t = PageTurner(pages, comments).nextPage!;
    expect(t.page, 1);
    expect(t.active, 0);
    expect(t.onPage.map((e) => e.index), [0, 1]);
    expect(t.nextPage!.nextPage!.active, 2);
  });

  test('next and previous comment walk the list and open their pages', () {
    var t = PageTurner(pages, comments).toComment(0);
    t = t.nextComment!;
    expect((t.page, t.active), (1, 1));
    t = t.nextComment!;
    expect((t.page, t.active), (3, 2));
    expect(t.nextComment, isNull);
    t = t.prevComment!;
    expect((t.page, t.active), (1, 1));
  });

  test('with no comment picked: next is the first from this page on, previous the last before it', () {
    final onTwo = PageTurner(pages, comments).toPage(2);
    expect(onTwo.active, isNull);
    expect(onTwo.nextComment!.active, 2);
    expect(onTwo.prevComment!.active, 1);

    final onFirst = PageTurner(pages, comments);
    expect(onFirst.nextComment!.active, 0);
    expect(onFirst.prevComment, isNull);

    final onLast = PageTurner(pages, comments).toPage(4);
    expect(onLast.nextComment, isNull);
    expect(onLast.prevComment!.active, 2);
    expect(onLast.nextPage, isNull);
  });

  test('a book without comments still turns pages', () {
    final t = PageTurner(pages, const []);
    expect(t.nextComment, isNull);
    expect(t.prevComment, isNull);
    expect(t.nextPage!.page, 1);
    expect(t.activeComment, isNull);
  });

  test('a page past the end is clamped', () {
    expect(PageTurner(pages, comments).toPage(99).page, 4);
  });
}
