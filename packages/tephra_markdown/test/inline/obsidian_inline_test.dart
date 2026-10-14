// © 2026 Tephra. All rights reserved.

import 'package:tephra_markdown/src/block/block_parser.dart';
import 'package:tephra_markdown/src/parser_options.dart';
import 'package:test/test.dart';

import '../helpers/dump.dart';

String _parse(String text, [ParserOptions options = const ParserOptions()]) {
  return dump(parseBlocks(text, options: options).root);
}

void main() {
  group('Wikilinks', () {
    test('[[Note]]', () {
      expect(_parse('[[Note]]'), 'doc(p(wiki{t=Note}))');
    });

    test('[[Note|Alias]]', () {
      expect(_parse('[[Note|Alias]]'), 'doc(p(wiki{t=Note,a=Alias}))');
    });

    test('[[Note#Heading]]', () {
      expect(_parse('[[Note#Heading]]'), 'doc(p(wiki{t=Note,h=Heading}))');
    });

    test('[[Note#Heading|Alias]]', () {
      expect(
        _parse('[[Note#Heading|Alias]]'),
        'doc(p(wiki{t=Note,h=Heading,a=Alias}))',
      );
    });

    test(r'[[Note#^blk]]', () {
      expect(_parse(r'[[Note#^blk]]'), 'doc(p(wiki{t=Note,b=blk}))');
    });

    test('[[#Heading]]', () {
      expect(_parse('[[#Heading]]'), 'doc(p(wiki{t=,h=Heading}))');
    });

    test(r'[[#^blk]]', () {
      expect(_parse(r'[[#^blk]]'), 'doc(p(wiki{t=,b=blk}))');
    });

    test('[[Folder/Note]]', () {
      expect(_parse('[[Folder/Note]]'), 'doc(p(wiki{t=Folder/Note}))');
    });

    test('[[Note.md]]', () {
      expect(_parse('[[Note.md]]'), 'doc(p(wiki{t=Note.md}))');
    });

    test('[[ Note ]]', () {
      expect(_parse('[[ Note ]]'), 'doc(p(wiki{t=Note}))');
    });

    test('[[]]', () {
      expect(_parse('[[]]'), 'doc(p(t"[[]]"))');
    });

    test('[[Note unclosed', () {
      expect(_parse('[[Note'), 'doc(p(t"[[Note"))');
    });

    test('[[a]] and [[b]]', () {
      expect(_parse('[[a]] and [[b]]'), 'doc(p(wiki{t=a},t" and ",wiki{t=b}))');
    });

    test('[[Note#H1#H2]]', () {
      expect(_parse('[[Note#H1#H2]]'), 'doc(p(wiki{t=Note,h=H1#H2}))');
    });

    test('[[Note|a|b]]', () {
      expect(_parse('[[Note|a|b]]'), 'doc(p(wiki{t=Note,a=a|b}))');
    });

    test(r'[[Note\|Alias]]', () {
      expect(_parse(r'[[Note\|Alias]]'), 'doc(p(wiki{t=Note,a=Alias}))');
    });

    test('[[বাংলা নোট]]', () {
      expect(_parse('[[বাংলা নোট]]'), 'doc(p(wiki{t=বাংলা নোট}))');
    });

    test('[[Note]]s', () {
      expect(_parse('[[Note]]s'), 'doc(p(wiki{t=Note},t"s"))');
    });

    test('**[[Note]]**', () {
      expect(_parse('**[[Note]]**'), 'doc(p(strong(wiki{t=Note})))');
    });

    test('[[Note]]\\n[[Other]]', () {
      expect(
        _parse('[[Note]]\n[[Other]]'),
        'doc(p(wiki{t=Note},sb,wiki{t=Other}))',
      );
    });

    test('[[a\\nb]] is not wikilink across newline', () {
      expect(_parse('[[a\nb]]'), 'doc(p(t"[[a",sb,t"b]]"))');
    });

    test('`[[Note]]`', () {
      expect(_parse('`[[Note]]`'), 'doc(p(c"[[Note]]"))');
    });

    test('[[Note|]]', () {
      expect(_parse('[[Note|]]'), 'doc(p(wiki{t=Note}))');
    });

    test('[[Note#]]', () {
      expect(_parse('[[Note#]]'), 'doc(p(wiki{t=Note}))');
    });

    test('[[Note#page=2]]', () {
      expect(_parse('[[Note#page=2]]'), 'doc(p(wiki{t=Note,p=2}))');
    });
  });

  group('Embeds', () {
    test('![[img.png]]', () {
      expect(_parse('![[img.png]]'), 'doc(p(embed{t=img.png}))');
    });

    test('![[img.png|300]]', () {
      expect(_parse('![[img.png|300]]'), 'doc(p(embed{t=img.png,w=300}))');
    });

    test('![[img.png|300x200]]', () {
      expect(
        _parse('![[img.png|300x200]]'),
        'doc(p(embed{t=img.png,w=300,x=200}))',
      );
    });

    test('![[img.png|alt text]]', () {
      expect(
        _parse('![[img.png|alt text]]'),
        'doc(p(embed{t=img.png,a=alt text}))',
      );
    });

    test('![[img.png|alt|300]]', () {
      expect(
        _parse('![[img.png|alt|300]]'),
        'doc(p(embed{t=img.png,a=alt,w=300}))',
      );
    });

    test('![[doc.pdf#page=3]]', () {
      expect(_parse('![[doc.pdf#page=3]]'), 'doc(p(embed{t=doc.pdf,p=3}))');
    });

    test('![[doc.pdf#page=3|400]]', () {
      expect(
        _parse('![[doc.pdf#page=3|400]]'),
        'doc(p(embed{t=doc.pdf,p=3,w=400}))',
      );
    });

    test('![[Note#Heading]]', () {
      expect(_parse('![[Note#Heading]]'), 'doc(p(embed{t=Note,h=Heading}))');
    });

    test(r'![[Note#^blk]]', () {
      expect(_parse(r'![[Note#^blk]]'), 'doc(p(embed{t=Note,b=blk}))');
    });

    test('![[Note]]', () {
      expect(_parse('![[Note]]'), 'doc(p(embed{t=Note}))');
    });

    test('![[ ]]', () {
      expect(_parse('![[ ]]'), 'doc(p(t"![[ ]]"))');
    });

    test('![[a|300x]]', () {
      expect(_parse('![[a|300x]]'), 'doc(p(embed{t=a,a=300x}))');
    });

    test('[[a|300]] non-embed leaves 300 as alias', () {
      expect(_parse('[[a|300]]'), 'doc(p(wiki{t=a,a=300}))');
    });

    test('![[a]] text', () {
      expect(_parse('![[a]] text'), 'doc(p(embed{t=a},t" text"))');
    });

    test('text ![[a]]', () {
      expect(_parse('text ![[a]]'), 'doc(p(t"text ",embed{t=a}))');
    });

    test('!![[a]]', () {
      expect(_parse('!![[a]]'), 'doc(p(t"!",embed{t=a}))');
    });

    test('![[a unclosed', () {
      expect(_parse('![[a'), 'doc(p(t"![[a"))');
    });

    test('![[song.mp3]]', () {
      expect(_parse('![[song.mp3]]'), 'doc(p(embed{t=song.mp3}))');
    });

    test('![[Note#H|Alias]]', () {
      expect(_parse('![[Note#H|Alias]]'), 'doc(p(embed{t=Note,h=H,a=Alias}))');
    });
  });

  group('Tags', () {
    test('#tag', () {
      expect(_parse('#tag'), 'doc(p(tag"tag"))');
    });

    test('#nested/tag', () {
      expect(_parse('#nested/tag'), 'doc(p(tag"nested/tag"))');
    });

    test('a #tag b', () {
      expect(_parse('a #tag b'), 'doc(p(t"a ",tag"tag",t" b"))');
    });

    test('#123 is text', () {
      expect(_parse('#123'), 'doc(p(t"#123"))');
    });

    test('#2024-q1', () {
      expect(_parse('#2024-q1'), 'doc(p(tag"2024-q1"))');
    });

    test('#y2k', () {
      expect(_parse('#y2k'), 'doc(p(tag"y2k"))');
    });

    test('a#b is text', () {
      expect(_parse('a#b'), 'doc(p(t"a#b"))');
    });

    test('(#tag)', () {
      expect(_parse('(#tag)'), 'doc(p(t"(",tag"tag",t")"))');
    });

    test('#tag,', () {
      expect(_parse('#tag,'), 'doc(p(tag"tag",t","))');
    });

    test('#tag.', () {
      expect(_parse('#tag.'), 'doc(p(tag"tag",t"."))');
    });

    test('#Tag_With-Chars', () {
      expect(_parse('#Tag_With-Chars'), 'doc(p(tag"Tag_With-Chars"))');
    });

    test('#বাংলা', () {
      expect(_parse('#বাংলা'), 'doc(p(tag"বাংলা"))');
    });

    test('#tag/', () {
      expect(_parse('#tag/'), 'doc(p(tag"tag",t"/"))');
    });

    test('`#tag`', () {
      expect(_parse('`#tag`'), 'doc(p(c"#tag"))');
    });

    test('## Heading #tag', () {
      expect(_parse('## Heading #tag'), 'doc(h2(t"Heading ",tag"tag"))');
    });

    test('#tag1 #tag2', () {
      expect(_parse('#tag1 #tag2'), 'doc(p(tag"tag1",t" ",tag"tag2"))');
    });

    test('##tag is text', () {
      expect(_parse('##tag'), 'doc(p(t"##tag"))');
    });

    test(r'\#tag is text', () {
      expect(_parse(r'\#tag'), 'doc(p(t"#tag"))');
    });

    test('- #tag in list', () {
      expect(_parse('- #tag'), 'doc(ul(li(p(tag"tag"))))');
    });
  });

  group('Inline comments', () {
    test('a %%hidden%% b', () {
      expect(_parse('a %%hidden%% b'), 'doc(p(t"a ",icmt"hidden",t" b"))');
    });

    test('%%x%%', () {
      expect(_parse('%%x%%'), 'doc(p(icmt"x"))');
    });

    test('text %%a%% and %%b%%', () {
      expect(
        _parse('text %%a%% and %%b%%'),
        'doc(p(t"text ",icmt"a",t" and ",icmt"b"))',
      );
    });

    test('**%%x%%**', () {
      expect(_parse('**%%x%%**'), 'doc(p(strong(icmt"x")))');
    });

    test('`%%x%%`', () {
      expect(_parse('`%%x%%`'), 'doc(p(c"%%x%%"))');
    });

    test('x %%a unclosed', () {
      expect(_parse('x %%a'), 'doc(p(t"x %%a"))');
    });
  });

  group('Inline math', () {
    test(r'$x^2$', () {
      expect(_parse(r'$x^2$'), 'doc(p(imath"x^2"))');
    });

    test(r'$a$ and $b$', () {
      expect(_parse(r'$a$ and $b$'), 'doc(p(imath"a",t" and ",imath"b"))');
    });

    test(r'$5 and $10 is text', () {
      expect(_parse(r'$5 and $10'), r'doc(p(t"$5 and $10"))');
    });

    test(r'$ x$ is text', () {
      expect(_parse(r'$ x$'), r'doc(p(t"$ x$"))');
    });

    test(r'$x $ is text', () {
      expect(_parse(r'$x $'), r'doc(p(t"$x $"))');
    });

    test(r'cost $5. is text', () {
      expect(_parse(r'cost $5.'), r'doc(p(t"cost $5."))');
    });

    test(r'\$x\$ is text', () {
      expect(_parse(r'\$x\$'), r'doc(p(t"$x$"))');
    });

    test(r'`$x$` is code', () {
      expect(_parse(r'`$x$`'), r'doc(p(c"$x$"))');
    });

    test(r'text $$a$$ text', () {
      expect(_parse(r'text $$a$$ text'), 'doc(p(t"text ",imath"a",t" text"))');
    });

    test(r'$x unclosed', () {
      expect(_parse(r'$x'), r'doc(p(t"$x"))');
    });

    test(r'$a$1 followed by digit is text', () {
      expect(_parse(r'$a$1'), r'doc(p(t"$a$1"))');
    });
  });

  group('Footnotes and block IDs', () {
    test('text[^1]', () {
      expect(_parse('text[^1]'), 'doc(p(t"text",fref"1"))');
    });

    test('^[inline note]', () {
      expect(_parse('^[inline note]'), 'doc(p(ifn(t"inline note")))');
    });

    test('text^[a *b*]', () {
      expect(_parse('text^[a *b*]'), 'doc(p(t"text",ifn(t"a ",em(t"b"))))');
    });

    test('[^a b] is text', () {
      expect(_parse('[^a b]'), 'doc(p(t"[^a b]"))');
    });

    test('[^1] ref', () {
      expect(_parse('[^1]'), 'doc(p(fref"1"))');
    });

    test(r'Paragraph text ^abc', () {
      expect(
        _parse('Paragraph text ^abc'),
        'doc(p(t"Paragraph text ",bid"abc"))',
      );
    });

    test(r'Para ^a-b-1', () {
      expect(_parse('Para ^a-b-1'), 'doc(p(t"Para ",bid"a-b-1"))');
    });

    test(r'Para^abc is text', () {
      expect(_parse('Para^abc'), 'doc(p(t"Para^abc"))');
    });

    test(r'^abc solo', () {
      expect(_parse('^abc'), 'doc(p(bid"abc"))');
    });

    test(r'## Heading ^h1', () {
      expect(_parse('## Heading ^h1'), 'doc(h2{id=h1}(t"Heading ",bid"h1"))');
    });

    test(r'- item ^i1', () {
      expect(_parse('- item ^i1'), 'doc(ul(li(p(t"item ",bid"i1"))))');
    });

    test(r'Para ^bad id is text', () {
      expect(_parse('Para ^bad id'), 'doc(p(t"Para ^bad id"))');
    });

    test(r'Para ^abc  with trailing spaces', () {
      expect(_parse('Para ^abc  '), 'doc(p(t"Para ",bid"abc"))');
    });

    test(r'Para ^a_b is text (underscore not allowed in block ID)', () {
      expect(_parse('Para ^a_b'), 'doc(p(t"Para ^a_b"))');
    });

    test(r'> quote ^q1', () {
      expect(_parse('> quote ^q1'), 'doc(bq(p(t"quote ",bid"q1")))');
    });

    test(r'Para ^ABC', () {
      expect(_parse('Para ^ABC'), 'doc(p(t"Para ",bid"ABC"))');
    });
  });
}
