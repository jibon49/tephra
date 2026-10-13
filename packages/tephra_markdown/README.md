# tephra_markdown

Markdown parser with Obsidian extensions, exact UTF-16 source offsets, and zero Flutter dependencies for Tephra.
Pure Dart. Must not import `package:flutter` (see `instructions/00-conventions.md` §3).

## Syntax Supported

### CommonMark Blocks & Inlines
- ATX headings (`#` to `######`)
- Setext headings (`===` and `---`)
- Fenced code blocks (```` ``` ```` and `~~~` with language specifiers)
- Indented code blocks (4 spaces / tab)
- HTML blocks (types 1–7) & raw HTML inlines
- Link reference definitions (`[id]: url "title"`)
- Paragraphs & blank lines
- Block quotes (`> quote`) with lazy continuation
- Thematic breaks (`---`, `***`, `___`)
- Lists and list items (ordered & bulleted, tight & loose, nested lists)
- Inlines: Code spans, emphasis (`*`, `_`), strong emphasis (`**`, `__`), hyperlinks (`[text](url)`), image links (`![alt](url)`), autolinks (`<url>`), hard line breaks (backslash and trailing spaces), soft line breaks, backslash escapes, character & entity references (`&amp;`, `&#65;`, `&#x41;`).

### GFM Extensions
- Tables with alignment syntax (`|:---|:---:|---:|---|`) and escaped pipe delimiters
- Task list items (`- [ ]`, `- [x]`, etc.)
- Strikethrough (`~~text~~`)

### Obsidian Extensions
- YAML frontmatter (`---` delimiters at start of file, metadata extraction)
- Wikilinks (`[[Note]]`, `[[Note#Heading]]`, `[[Note#^block-id]]`, `[[Note|Alias]]`)
- Embeds (`![[image.png]]`, `![[img.png|300]]`, `![[img.png|300x200]]`, `![[doc.pdf#page=3]]`)
- Callouts (`> [!type]`, `> [!type]+`, `> [!type]-` supporting all 27 standard types plus custom types, foldable states)
- Highlights (`==highlight==`)
- Comments: inline (`%% comment %%`) and multiline block comments
- LaTeX mathematics: inline (`$x$`) and block (`$$x$$`)
- Footnotes: references (`[^1]`), definitions (`[^1]: def`), and inline footnotes (`^[inline]`)
- Tags: `#tag`, `#nested/tag/hierarchical`, Unicode tags (e.g. `#বাংলা`)
- Block reference identifiers (`^block-id` on headings, paragraphs, lists, tables, callouts)

## Conformance & Test Metrics

- **CommonMark 0.31.2 Conformance**:
  - Total passed: **617 / 652** (**94.6%**) (target ≥ 85%)
  - Required sections: **100.0%** pass rate across all 7 sections:
    - Backslash escapes: 13 / 13 (100.0%)
    - Thematic breaks: 19 / 19 (100.0%)
    - ATX headings: 18 / 18 (100.0%)
    - Setext headings: 27 / 27 (100.0%)
    - Fenced code blocks: 29 / 29 (100.0%)
    - Block quotes: 25 / 25 (100.0%)
    - Code spans: 22 / 22 (100.0%)
    - Tabs: 11 / 11 (100.0%)
    - Indented code blocks: 12 / 12 (100.0%)
    - Paragraphs: 8 / 8 (100.0%)
    - Blank lines: 1 / 1 (100.0%)
    - Emphasis and strong emphasis: 132 / 132 (100.0%)
    - Images: 22 / 22 (100.0%)
    - Autolinks: 19 / 19 (100.0%)
    - Hard line breaks: 15 / 15 (100.0%)
    - Soft line breaks: 2 / 2 (100.0%)
- **Obsidian Spec Cases**: 262 / 262 passed (100.0%)
- **Syntax Vault Fixture Suite**: 24 / 24 note suites passed (100.0%)
- **Fuzz Testing**:
  - 2,000 random documents (1–60 fragments, seed 42) with Obsidian options: zero exceptions, AST invariants verified (`0 <= start <= end <= text.length`, parent containment, ordered non-overlapping siblings), 100% deterministic re-parse.
  - 500 random documents (seed 7) with CommonMark options: zero exceptions, AST invariants verified.
