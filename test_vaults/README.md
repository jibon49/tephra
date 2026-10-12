# Test Vaults

Fixture vaults used for parser verification, rendering, search, round-trip tests, and performance benchmarks.
Files in this folder are stored byte-exact (`.gitattributes`: `-text`). Never reformat them. `edge/` and `syntax/attachments/` are produced by `dart run tool/gen_test_vaults.dart`.

## syntax/

Contains individual notes isolating every single supported Markdown and Obsidian syntax element (headings, paragraphs, emphasis, lists, tasks, callouts, code blocks, tables, wikilinks, embeds, tags, math, footnotes, frontmatter, etc.). Used for AST parsing, reading view rendering, round-trip byte-safety tests, and golden image tests.

## edge/

Contains byte-exact edge cases created deterministically by tooling: CRLF line endings, UTF-8 BOM markers, malformed UTF-8 byte sequences, empty files, a 5,000-line huge note, Unicode and emoji file names, deep folder nesting, and empty folders.

## real/

A realistic 300-note vault mirroring real-world personal knowledge bases with interconnected links, tags, tasks, and attachments for indexing and integration testing. `real/` is generated (300 notes, seed 7); the human may replace it with a copy of a real Obsidian vault.

## bench/

A synthetic benchmark vault generated on demand by `tool/gen_bench_vault.dart` (git-ignored) containing up to 10,000 notes for measuring search latency, cold start, indexing throughput, and memory consumption.
