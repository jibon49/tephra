# Phase 08 — Advanced extras

> **Duration:** 8 weeks, four 2-week blocks: **8a** AI & semantic search, **8b** productivity, **8c** media intelligence, **8d** security.
> **Goal:** add the built-in "extras" that go beyond Obsidian's core: an opt-in AI assistant using Anthropic Claude with the user's own API key,
> an on-device semantic search index, Dataview-lite queries, a Tasks dashboard, Kanban boards, spaced-repetition flashcards, OCR,
> voice-note transcription, a sketching canvas, encrypted notes/folders and an app lock. Every Phase 2 performance budget must still hold at the end.

---

## Before you start

1. Read `GEMINI.md`, `instructions/00-conventions.md`, `PROGRESS.md` and this whole file before writing any code.
2. Confirm in `PROGRESS.md` that the Phase 7 exit gate is fully checked. If not, stop and tell the human.
3. `git checkout main; git pull` (if a remote exists), then `git checkout -b phase-08`.
4. Run the baseline and make sure everything is green before you change anything:
   ```
   flutter pub get
   dart format --output=none --set-exit-if-changed app/lib app/test packages tool
   flutter analyze --fatal-infos
   dart run tool/check_licenses.dart
   ```
   and `dart test` in every package plus `flutter test` in `app/`. If anything fails, fix it first (that is Phase 7 debt) and note it in `PROGRESS.md`.
5. Add every step of this file (IDs `08.1` … `08.54`) to `PROGRESS.md` as unchecked items, grouped under the block headings 8a, 8b, 8c, 8d.
6. This phase is long. Work block by block in order (8a → 8b → 8c → 8d). At the end of each block run that block's check step
   (08.23, 08.36, 08.47, 08.53), record the results in `PROGRESS.md`, commit, and continue with the next block **without** waiting for the human,
   unless a stop condition from `GEMINI.md` §5 applies.
7. Earlier phase files describe code that already exists. When this file says "the Phase N service that does X", find it with a search
   (for example `Select-String -Path app\lib -Pattern "class .*NotificationService" -Recurse` or your search tool) and use the name you find.
   Do not create a second implementation of something that already exists.

### Decisions made for this phase (follow them; do not re-decide)

| # | Topic | Decision |
|---|---|---|
| D1 | Claude client | Our own thin client over `package:http` inside `packages/tephra_ai`. There is no official Anthropic Dart SDK; community SDKs add surface we do not need. Raw HTTP against the documented Messages API is the supported path for languages without an official SDK. |
| D2 | Default model | `claude-sonnet-5-5`. Built-in choices: `claude-sonnet-5-5`, `claude-opus-5-5`, `claude-haiku-5-5`, plus a free-text "custom model id" field. We never append date suffixes to model ids. |
| D3 | Thinking | We do **not** send a `thinking` parameter. Current models run adaptive thinking by default; the stream may contain `thinking` content blocks, which the client ignores. We send `output_config.effort` (setting, default `medium`). |
| D4 | Privacy | AI is **off** until the user turns it on and enters a key. Nothing is ever sent unless the user invokes an AI action. Before each request a preview sheet lists exactly which notes/snippets will be sent (setting "Always confirm before sending", default **on**). Encrypted notes (8d) are never sent and never embedded. |
| D5 | Embeddings | Local, on-device, using ONNX Runtime (`onnxruntime` Flutter plugin, MIT) and the model **`intfloat/multilingual-e5-small`** (MIT; 384 dimensions; max 512 tokens; ~100 languages including Bangla). We use the int8-quantised ONNX export `Xenova/multilingual-e5-small` → `onnx/model_quantized.onnx` (~118 MB) plus its `tokenizer.json`, **downloaded on demand** (never bundled), verified by pinned SHA-256. An optional remote provider (Voyage AI) sits behind the same interface, **off by default**. |
| D6 | Vector storage | A separate SQLite file owned by `tephra_ai`: `<appSupportDir>/index/<vaultId>.vectors.sqlite`, table `chunk_vectors` (float32 little-endian blobs). It lives next to the main index file, is a rebuildable cache, and is never synced. It is a separate file (not a table inside the drift index DB) because it is written by the embedding worker isolate while the indexer isolate writes the main DB; two writers on one SQLite file would contend for the write lock and slow down indexing. |
| D7 | Vector search | Brute force. In memory the worker keeps one int8-quantised matrix (per-vector scale) for a fast first pass, then re-ranks the best 100 candidates with exact float32 cosine using `Float32x4List`. 30k chunks ≈ 11.5 MB RAM. Fine up to 100k chunks. |
| D8 | Embedding runtime | A long-lived **embedding worker isolate** spawned by the app. The main isolate reads note text (works for both `IoVaultFileSystem` and the Android SAF fallback) and sends it to the worker; the worker chunks, tokenises, runs ONNX, writes `chunk_vectors`, and answers search requests. |
| D9 | Dataview-lite | Grammar is a strict subset of Dataview's DQL (EBNF in Format F1). Implemented in `packages/tephra_search/lib/src/query/`: our own DQL lexer/parser that **compiles to the Phase 6 Bases expression AST** (`packages/tephra_search/lib/src/bases/expr/`) and evaluates with `BaseEvaluator` over the Phase 6 `BaseDataset`, so values, operators, dates and durations behave exactly like Bases. Both ` ```tephra-query ` and ` ```dataview ` fences are rendered by Tephra, so a query written in one works in the other. Inline fields (`key:: value`) are **not** supported in this phase. |
| D10 | Text-format parsers | Tasks metadata, Kanban and flashcard parsing + SM-2 scheduling are pure Dart in `packages/tephra_markdown/lib/src/{tasks,kanban,flashcards}/`. |
| D11 | OCR | Android: `google_mlkit_text_recognition` (Latin script only). Windows: `Windows.Media.Ocr` through our own small FFI plugin `app/plugins/tephra_win_ocr` (C++/WinRT, no extra download). **Bangla OCR is not supported on either platform** in this phase (ML Kit has no Bengali model; Windows OCR language packs do not include Bengali — verify in 08.39). Documented limitation. |
| D12 | Transcription | On-device `whisper.cpp` (MIT) through our own FFI plugin `app/plugins/tephra_whisper`, built from vendored source pinned to a release tag. Models downloaded on demand: `ggml-base-q5_1.bin` (default, ~57 MB) and `ggml-small-q5_1.bin` (~181 MB, recommended for Bangla). Input: WAV. New voice notes are recorded as 16 kHz mono WAV. |
| D13 | Sketches | Stroke data in `<name>.sketch.json` (Format F5) + a PNG preview `<name>.sketch.png` embedded as `![[<name>.sketch.png]]`. Variable-width strokes via `perfect_freehand` (MIT). |
| D14 | Encryption | Encrypted files use the extension **`.tephraenc`** and the binary format TENC v1 (Format F6), AES-256-GCM with keys from Argon2id. Obsidian shows them as unknown files (acceptable). Encrypted *areas* (folders) share one key per area; their registry is `.tephraenc`-independent JSON at `.tephra/encrypted-areas.json`. |
| D15 | App lock | PIN (4–8 digits, Argon2id hash in secure storage) + biometrics via `local_auth` (BSD-3; Android biometrics, Windows Hello). App lock protects the UI only; it does not encrypt files. |
| D16 | Native plugins location | FFI plugins live in `app/plugins/<name>/`, are workspace members, and are path dependencies of `app/`. Nothing native goes into `packages/` (packages stay pure Dart). |

### Contract additions made by this phase

These are **additions** to `00-conventions.md`; no existing name, signature or format changes. Record each in `PROGRESS.md` under a
heading "Contract additions (Phase 8)" when you implement it, so the human can fold them into the conventions file later.

1. New package `packages/tephra_ai` (already foreseen in conventions §2/§3) — dependencies exactly: `tephra_core`, `tephra_markdown`, `tephra_index`.
2. `NoteIndex` gains attachment-text methods (08.37): `putAttachmentText`, `removeAttachmentText`, `attachmentTextHashes`, `fullTextAttachments`. The drift schema gains table `attachment_text` and the FTS5 table `fts_attachments` (schema version bump). The existing `changes` stream (`Stream<IndexEvent>`, Phase 2) and the Phase 6 dataset queries (`allFiles`, `allNoteTags`, `allLinks`, `allProperties`) are reused, not duplicated.
3. New app feature folders: `app/lib/ai/`, `app/lib/tasks/`, `app/lib/kanban/`, `app/lib/flashcards/`, `app/lib/sketch/`, `app/lib/security/`,
   `app/lib/media/ocr/`, `app/lib/media/transcribe/`. New folder `app/plugins/` (D16).
4. New `.tephra/` files: `.tephra/flashcards.json` (F4), `.tephra/encrypted-areas.json` (F6).
5. New app-support files: `<appSupportDir>/index/<vaultId>.vectors.sqlite`, `<appSupportDir>/models/…`, `<appSupportDir>/ai_usage.json`.

---

## Human prerequisites

Ask the human for these at the start of the block that needs them. Do not block earlier blocks on later items.

| When | What | Exact instructions to give the human |
|---|---|---|
| 8a (step 08.7) | An Anthropic API key for testing | "Go to https://console.anthropic.com → Settings → API Keys → Create Key. Name it `tephra-dev`. Put a small monthly spend limit on the workspace (Settings → Limits, e.g. USD 10). Paste the key into the file `secrets/anthropic_api_key.txt` (one line, no quotes). Never paste it into chat or a commit." Tests that call the real API read that file and are skipped when it is missing. |
| 8a (step 08.12, optional) | A Voyage AI key, only if the human wants the remote embeddings provider tested | "Create a key at https://dash.voyageai.com → API keys, and save it in `secrets/voyage_api_key.txt`." If absent, Voyage tests are skipped and the provider is shipped untested against the live API — write that in `PROGRESS.md`. |
| 8a (step 08.11) | Python 3 with the `tokenizers` package, only if not already installed | Check with `python -c "import tokenizers; print(tokenizers.__version__)"`. If it fails, ask: "Please install Python 3.12+ and run `pip install tokenizers`, then tell me to continue." (Used once to generate tokenizer reference fixtures.) |
| 8b (step 08.36) | Obsidian desktop with plugins | "Install Obsidian desktop and enable the community plugins **Dataview**, **Tasks**, **Kanban** and **Spaced Repetition** in a copy of the test vault `test_vaults/real` (copy it to `D:\tmp\obsidian-compat`). Tell me when done." Used for the compatibility checks; Gemini then opens files there by hand-off instructions. |
| 8c (step 08.39) | Windows OCR language check | Gemini runs the PowerShell command in 08.39 itself. If installing an OCR language pack is needed for testing, it requires admin rights: ask "Please run PowerShell as Administrator and run `Add-WindowsCapability -Online -Name 'Language.OCR~~~en-US~0.0.1.0'`" (only if `en-US` is missing). |
| 8c (all) | A real Android phone with a stylus if possible | Real-device checks for OCR, transcription speed and stylus pressure. If no stylus device exists, record "pressure not verified on device". |
| 8c (step 08.38) | ML Kit terms acknowledgement | Tell the human: "`google_mlkit_text_recognition` is MIT-licensed, but it downloads Google's ML Kit native library, which is covered by Google's ML Kit Terms of Service (free, closed-source binary). Please confirm this is acceptable for Tephra (yes/no)." If no, skip Android OCR (keep the interface with a no-op implementation) and record it. |
| 8d | Nothing new | — |

---

## What exists when done

- `packages/tephra_ai`: Claude Messages API client (streaming SSE, retries, rate limiting, cost accounting), prompt templates with golden tests,
  note chunker, Unigram (XLM-R) tokenizer, embedding interfaces (local e5 helpers + Voyage), vector store + brute-force search,
  semantic indexer, hybrid retriever, "Ask your vault" service with citation validation, suggestion and flashcard generators.
- App: AI settings (key in secure storage, model, effort, confirm-before-send), outbound preview sheet, usage/cost ledger, selection actions
  (summarise / rewrite / translate / explain / continue), Ask-your-vault panel with streaming answer and sources list, Related-notes panel,
  semantic mode in the search panel, tag and link suggestions, flashcard generation, model download manager, embedding worker isolate.
- Dataview-lite query blocks (` ```tephra-query ` and ` ```dataview `), live-updating in reading view and Live Preview.
- Tasks dashboard (Tasks-plugin emoji format, filters, completion with ✅ date, simple recurrence, due-date reminders).
- Kanban boards (obsidian-kanban format) with drag-and-drop, writing Markdown back while preserving unknown content.
- Flashcards (`::`, `?`, `==cloze==`), SM-2 scheduling, review screen and statistics, state in `.tephra/flashcards.json`.
- OCR of images and scanned PDF pages (Android ML Kit, Windows OCR) feeding the full-text search; PDF text layers indexed too.
- Voice notes recorded as WAV and transcribed on-device with whisper.cpp; transcript inserted below the embed.
- Sketch editor with stylus pressure, pen/highlighter/eraser/lasso, undo/redo, `.sketch.json` + `.sketch.png`, tap to edit.
- Encrypted notes and folders (`.tephraenc`), unlock sessions with auto-lock, in-memory-only search of unlocked content.
- App lock with PIN, biometrics/Windows Hello and lock-after-N-minutes.

---

## Dependencies

Add each with `dart pub add` (inside the package folder) or `flutter pub add` (inside `app/` or the plugin folder), then run
`dart run tool/check_licenses.dart`. **Before using any package, open its pub.dev page and README and re-check its licence, platform support
and current API**; the API names below were correct when this file was written but may have moved.

| Package / asset | Added to | Licence | Purpose |
|---|---|---|---|
| `http` | `tephra_ai` | BSD-3-Clause | Claude + Voyage HTTP |
| `sqlite3` | `tephra_ai` | MIT | vector store file (D6) |
| `crypto` | `tephra_ai` | BSD-3-Clause | chunk hashes |
| `path` | `tephra_ai` | BSD-3-Clause | paths |
| `logging` | `tephra_ai` | BSD-3-Clause | logging |
| `test` (dev) | `tephra_ai` | BSD-3-Clause | tests |
| `onnxruntime` | `app` | MIT | ONNX inference for e5 (bundles the MIT-licensed ONNX Runtime native library) |
| `google_mlkit_text_recognition` | `app` | MIT (plugin) + Google ML Kit Terms (native SDK) | Android OCR |
| `perfect_freehand` | `app` | MIT | pressure-sensitive stroke outlines |
| `local_auth` | `app` | BSD-3-Clause | biometrics / Windows Hello |
| `ffi` | `app/plugins/tephra_whisper`, `app/plugins/tephra_win_ocr` | BSD-3-Clause | FFI helpers (`calloc`, `Utf8`, `Utf16`) |
| `cryptography` | `tephra_vault` (if not already there) | Apache-2.0 | AES-256-GCM, Argon2id, HKDF (already used by Phase 3) |
| whisper.cpp source (vendored at a release tag) | `app/plugins/tephra_whisper/src/whisper.cpp/` | MIT | speech-to-text engine |
| multilingual-e5-small ONNX + tokenizer (downloaded at runtime) | `<appSupportDir>/models/` | MIT | embeddings |
| Whisper ggml models (downloaded at runtime) | `<appSupportDir>/models/` | MIT | transcription |
| Windows.Media.Ocr | OS API | part of Windows | Windows OCR |

Already present from earlier phases (do not add again): `flutter_secure_storage`, `flutter_riverpod`, `drift`, `pdfrx`, `record`, `just_audio`,
`yaml_edit`, `flutter_local_notifications` (or whatever Phase 4 uses), `path_provider`.

`THIRD_PARTY_NOTICES.md` is generated by `tool/check_licenses.dart` (Phase 0) and must not be edited by hand. Non-Dart components are added through a new input file `tool/extra_notices.json` that you create in 08.41 and that `check_licenses.dart` appends (see 08.41). Components to list there: whisper.cpp (MIT, with its copyright line), ONNX Runtime (MIT),
multilingual-e5-small (MIT, "intfloat"), OpenAI Whisper model weights (MIT).

---

## Formats defined by this phase

These formats are referenced by the steps. Implement them exactly.

### F1 — `tephra-query` grammar (Dataview-lite)

A query block is a fenced code block whose info string is exactly `tephra-query` or `dataview`. Keywords are **case-insensitive**
(`LIST`, `list` and `List` are the same). Whitespace includes newlines, so queries can span lines.

```ebnf
query          = ws , header , [ ws1 , from_clause ] , { ws1 , data_command } , ws ;

header         = list_header | table_header | task_header ;
list_header    = "LIST" , [ ws1 , "WITHOUT" , ws1 , "ID" ] , [ ws1 , expression ] ;
table_header   = "TABLE" , [ ws1 , "WITHOUT" , ws1 , "ID" ] , [ ws1 , column , { ws , "," , ws , column } ] ;
column         = expression , [ ws1 , "AS" , ws1 , ( string | identifier ) ] ;
task_header    = "TASK" ;

from_clause    = "FROM" , ws1 , source_or ;
source_or      = source_and , { ws1 , "OR" , ws1 , source_and } ;
source_and     = source_term , { ws1 , "AND" , ws1 , source_term } ;
source_term    = [ "-" ] , source_atom ;
source_atom    = tag_source | folder_source | link_source | "(" , ws , source_or , ws , ")" ;
tag_source     = "#" , tag_char , { tag_char } ;              (* tag_char: same rule as the Phase 1 tag parser *)
folder_source  = string ;                                     (* "Projects/Active" or "Projects/Plan.md" *)
link_source    = "[[" , link_target , "]]" ;                  (* notes that link TO this note *)

data_command   = where_cmd | sort_cmd | group_cmd | limit_cmd ;
where_cmd      = "WHERE" , ws1 , expression ;
sort_cmd       = "SORT" , ws1 , sort_key , { ws , "," , ws , sort_key } ;
sort_key       = expression , [ ws1 , ( "ASC" | "ASCENDING" | "DESC" | "DESCENDING" ) ] ;
group_cmd      = "GROUP" , ws1 , "BY" , ws1 , expression , [ ws1 , "AS" , ws1 , identifier ] ;
limit_cmd      = "LIMIT" , ws1 , integer ;

expression     = or_expr ;
or_expr        = and_expr , { ws , ( "or" | "||" ) , ws , and_expr } ;
and_expr       = not_expr , { ws , ( "and" | "&&" ) , ws , not_expr } ;
not_expr       = { "!" , ws } , comparison ;
comparison     = additive , [ ws , comp_op , ws , additive ] ;
comp_op        = "=" | "!=" | "<=" | ">=" | "<" | ">" ;
additive       = multiplicative , { ws , ( "+" | "-" ) , ws , multiplicative } ;
multiplicative = unary , { ws , ( "*" | "/" | "%" ) , ws , unary } ;
unary          = [ "-" ] , postfix ;
postfix        = primary , { ( "." , identifier ) | ( "[" , ws , expression , ws , "]" ) } ;
primary        = number | string | boolean | "null" | link_literal | list_literal
               | function_call | identifier | "(" , ws , expression , ws , ")" ;
function_call  = identifier , "(" , ws , [ expression , { ws , "," , ws , expression } ] , ws , ")" ;
link_literal   = "[[" , link_target , "]]" ;
list_literal   = "[" , ws , [ expression , { ws , "," , ws , expression } ] , ws , "]" ;
identifier     = ( letter | "_" ) , { letter | digit | "_" | "-" } ;   (* see rule R3 *)
string         = '"' , { string_char | "\\" , ( '"' | "\\" | "n" | "t" ) } , '"' ;
number         = digit , { digit } , [ "." , digit , { digit } ] ;
integer        = digit , { digit } ;
boolean        = "true" | "false" ;
ws             = { " " | "\t" | "\r" | "\n" } ;
ws1            = ( " " | "\t" | "\r" | "\n" ) , ws ;
```

Rules:
- **R1** Data commands run **in the order written** (like Dataview). `FROM` must come before any data command and at most once.
- **R2** At most one `GROUP BY` per query. After `GROUP BY`, each row is a group with fields `key` and `rows` (`rows` is the list of grouped rows).
  The group key field name is `key`, or the identifier after `AS`.
- **R3** A `-` directly between identifier characters with no spaces is part of the identifier (`due-date` is one field). Subtraction needs spaces (`a - b`).
- **R4** `letter` means any Unicode letter (`\p{L}`), so Bangla property names work.
- **R5** Unknown keywords or trailing text are a parse error with line and column.

**Evaluation model:** a parsed query is compiled to Bases `Expr` nodes and evaluated by `BaseEvaluator` with a `BaseRowContext` (06.17). Where this section and Phase 6 disagree on a detail of value semantics (comparison, truthiness, null handling, date arithmetic), **Phase 6 wins** — note the case in `PROGRESS.md`. DQL-specific names are mapped by the compiler (08.30).

**Value types:** `null`, `bool`, `number` (double), `string`, `date` (date-only or date-time, local time), `duration` (days + milliseconds),
`link` (target `VaultPath` + optional display text), `list`.

**Implicit fields for note rows:** `file.name` (stem), `file.path`, `file.folder` (parent path, `''` for root), `file.ext` (`md`),
`file.link` (link to the note), `file.size` (bytes), `file.ctime`, `file.mtime` (date-time), `file.cday`, `file.mday` (date-only),
`file.tags` (all tags with `#`, including parent tags: `#a/b` gives `#a` and `#a/b`), `file.etags` (explicit tags only), `file.aliases`,
`file.inlinks` (links to notes linking here), `file.outlinks` (resolved outgoing links), `file.tasks` (list of task rows), `file.day`
(date parsed from a `YYYY-MM-DD` in the file name, else frontmatter `date`, else `null`). Any other identifier is looked up in the note's
frontmatter: exact key first, then a case-insensitive match; missing → `null`.

**Task rows (`TASK` queries and `file.tasks`):** `text` (description without Tasks metadata), `status` (single char), `completed`
(status is `x` or `X`), `checked` (status is not a space), `line` (1-based), `path`, `tags`, `due`, `scheduled`, `start`, `completion`
(✅ date), `created`, `cancelled`, `priority` (`"highest"|"high"|"medium"|"low"|"lowest"|"none"`), `recurrence` (string or `null`),
and `file.*` of the containing note.

**Functions (exactly these 20):** `contains(container, value)`, `icontains(container, value)` (case-insensitive for strings),
`length(listOrString)`, `lower(s)`, `upper(s)`, `startswith(s, prefix)`, `endswith(s, suffix)`, `regexmatch(pattern, s)` (whole-string match),
`date(x)` (x is a string `YYYY-MM-DD[THH:mm[:ss]]`, a date, or one of the words `today`, `now`, `tomorrow`, `yesterday`),
`dur(s)` (e.g. `"3 days"`, `"1 week"`, `"2 months"`, `"1 year"`, `"4 hours"`, `"30 minutes"`; units singular or plural),
`number(s)`, `string(x)`, `default(x, fallback)` (fallback when x is null), `choice(cond, a, b)`, `round(n, digits?)`, `link(path)`,
`min(a, b, …)`, `max(a, b, …)`, `sum(list)`, `join(list, separator?)` (default separator `", "`).
In `date(today)` etc. the bare words are accepted as identifiers only inside `date(...)`.

**Semantics:**
- Truthiness: `null`, `false`, `0`, `""` and empty lists are false; everything else is true.
- `=`/`!=` compare by value; strings compare case-sensitively; a string compared with a date is parsed as a date if it is ISO-formatted.
  Comparing incompatible types gives `false` (for `=`) and `true` (for `!=`), and `false` for ordering operators.
- Frontmatter strings matching `^\d{4}-\d{2}-\d{2}(T\d{2}:\d{2}(:\d{2})?)?$` are dates; strings matching `^\[\[.+\]\]$` are links.
- Date arithmetic: date ± duration → date; date − date → duration; duration ± duration → duration. Months add with day clamping
  (Jan 31 + 1 month = Feb 28/29).
- `.field` on a list maps over the list ("swizzling"): `rows.file.name` is the list of names. `list[index]` is 0-based; out of range → `null`.
- Sorting uses the Phase 6 Bases comparator (06.18): stable; nulls last in ASC and first in DESC; mixed kinds ordered null < bool < num < date < str.
- `FROM #tag` matches the tag and its children (`#a` matches `#a/b`). `FROM "folder"` matches notes inside the folder or the exact file
  (with or without `.md`). `FROM [[Note]]` matches notes whose outgoing links resolve to `Note`. `-` negates. No `FROM` = all notes.
- Only Markdown notes are rows; `.tephraenc` files are never rows.

**Rendering:**
- `LIST`: bullet list; each item is the note link, followed by `: <value>` if an expression was given. `WITHOUT ID` shows only the value.
- `TABLE`: first column "File" (note link) unless `WITHOUT ID`; then one column per expression, titled with the `AS` name or the
  expression's source text. Dates render `yyyy-MM-dd` (date-time `yyyy-MM-dd HH:mm`), durations as "3 days", lists comma-joined,
  links as clickable link text, booleans as a check mark or an empty box, `null` as empty.
- `TASK`: tasks grouped by note (note link as group header), each with a checkbox that writes back through the task toggle service (08.25).
- With `GROUP BY`: one section per group with the key as a header; the table/list inside shows that group's rows.
- At most 1,000 rows/items are rendered; beyond that show "Showing the first 1,000 results".
- Parse errors render as a red error box with the message and `line:column`. A per-cell evaluation error renders `⚠` with a tooltip.

### F2 — Tasks-plugin task metadata

A task is a list item with a status (`- [ ] text`, `* [x] text`, `1. [/] text`). Tephra reads the Tasks-plugin emoji fields from the **end**
of the task text. Regular expressions (Dart, `unicode: true`; `\uFE0F` is the optional emoji variation selector):

| Field | Regex (anchored at the end with `\s*$` while parsing) | Value |
|---|---|---|
| priority | `(🔺\|⏫\|🔼\|🔽\|⏬)\uFE0F?` | 🔺 highest, ⏫ high, 🔼 medium, 🔽 low, ⏬ lowest; absent = none |
| start | `🛫\uFE0F? *(\d{4}-\d{2}-\d{2})` | date |
| created | `➕\uFE0F? *(\d{4}-\d{2}-\d{2})` | date |
| scheduled | `(?:⏳\|⌛)\uFE0F? *(\d{4}-\d{2}-\d{2})` | date |
| due | `(?:📅\|📆\|🗓)\uFE0F? *(\d{4}-\d{2}-\d{2})` | date |
| done | `✅\uFE0F? *(\d{4}-\d{2}-\d{2})` | date |
| cancelled | `❌\uFE0F? *(\d{4}-\d{2}-\d{2})` | date |
| recurrence | `🔁\uFE0F? *([a-zA-Z0-9, !]+)` | rule text, e.g. `every week when done` |
| block id | `\^[A-Za-z0-9-]+` | kept, never moved |
| trailing tag | `#[^\s#]+` | moved back into the description |

**Parsing algorithm** (`TaskMetadataParser.parse(String taskText)`):
1. `rest = taskText`. `trailingTags = []`. `blockId = null`.
2. If `rest` ends with ` ^id` (regex `\s+(\^[A-Za-z0-9-]+)\s*$`), store `blockId`, remove it.
3. Repeat at most 20 times: for each field regex above (in table order), test it with `\s*$` appended to the pattern against `rest`.
   On the first match: record the value (if the same field appears twice, keep the **last** one in the text, i.e. the first one found from the end),
   remove the match from `rest`, and restart the loop. If no field matches, try the trailing-tag regex with `\s*$`; if it matches, insert the
   tag at the front of `trailingTags`, remove it, restart. If nothing matches, stop.
4. `description = (rest.trimRight() + (trailingTags.isEmpty ? '' : ' ' + trailingTags.join(' '))).trim()`.
5. `metadataStart` = the UTF-16 offset in `taskText` where the first removed field began (or `taskText.length` if none) — used for edits.
6. Dates must be valid calendar dates; an invalid date (e.g. `2026-02-30`) leaves the token in the description.

**Write-back rules (minimal edits — never re-serialise the whole line):**
- Complete (`[ ]` or any non-`x` status except `-` → `[x]`): replace the status character. If the setting "Add done date" (default **on**) is on
  and there is no ✅ field: insert ` ✅ YYYY-MM-DD` (today) at the end of the line, **before** a trailing ` ^blockid` if present.
- If the task has a 🔁 rule, also insert the next occurrence **on the line above** (Tasks plugin default), same indentation and list marker,
  status `[ ]`, no ✅ and no ❌, dates shifted per the recurrence rules below, ➕ set to today if the original had ➕, block id **removed**
  (block ids must stay unique).
- Uncomplete (`[x]`/`[X]` → `[ ]`): replace the status character and remove the ✅ token together with one preceding space. The generated
  recurrence line (if any) is left alone.
- `[-]` (cancelled) tasks are not toggled from Tephra's dashboard (shown greyed).

**Recurrence (supported subset):** `every day`, `every week`, `every month`, `every year`, `every N days`, `every N weeks`,
`every N months`, `every N years` (N is 1–999), each optionally followed by ` when done`. Case-insensitive. Anything else is "unsupported":
the task is completed but no next occurrence is created, and the UI shows "This repeat rule isn't supported yet; no next task was created."
Next-date algorithm:
```
base    = due ?? scheduled ?? start                // the reference date of the task
if base == null: create the next task with no dates (keep the 🔁 text)
from    = whenDone ? today : base
newBase = advance(from, rule)                      // day: +N, week: +7N days, month: addMonths(N), year: addMonths(12N); month add clamps the day
for each of start, scheduled, due that is present:
  newDate = newBase + (date - base) days
```

### F3 — Kanban board (obsidian-kanban format)

A Kanban board is a normal `.md` note whose frontmatter has the key `kanban-plugin` with any non-empty value (seen in the wild: `board`, `basic`).

````markdown
---

kanban-plugin: board

---

## Backlog

- [ ] Write the spec
- [ ] Review with team #urgent @{2026-10-20}

## Doing

- [ ] Build the board view
	extra line that belongs to the card above

## Done

**Complete**
- [x] Ship v1


***

## Archive

- [x] Old card

%% kanban:settings
```
{"kanban-plugin":"board","list-collapse":[false,false,false]}
```
%%
````

Parsing rules (`KanbanParser.parse(String text) → KanbanBoard`):
1. The board is split into regions, each keeping its **exact original text** (`raw`):
   - `preamble`: everything from the start of the file up to (not including) the first `## ` heading line (this includes the frontmatter
     and any text before the first lane);
   - `lanes`: each lane starts at a line matching `^## (.*)$` and ends before the next `## ` line, the archive separator, or the settings block;
   - `archive`: if a line equal to `***` (thematic break) is followed (after optional blank lines) by `## Archive`, everything from `***` up to
     the settings block is the archive region (kept verbatim; cards in it are shown read-only in an "Archive" drawer);
   - `settings`: from the line `%% kanban:settings` to the closing `%%` line inclusive, kept **verbatim**, never edited;
   - `trailer`: anything after the settings block, kept verbatim.
2. Inside a lane: line 1 is the heading (`title` = text after `## `). A line exactly `**Complete**` marks the lane as auto-complete
   (`completeLane = true`). A card starts at a line matching `^- \[(.)\] (.*)$` (the plugin always writes `- `); following lines that are
   indented with a tab or at least 2 spaces, or are empty lines followed by an indented line, belong to the same card. Other lines inside the
   lane (paragraphs, comments) are kept as `LaneExtra` items in place.
3. Each card keeps `raw` (all its lines exactly) and `status` char and `title` (first line text). Dates `@{YYYY-MM-DD}`, times `@@{HH:mm}`,
   tags and wikilinks are displayed by the card renderer but never rewritten.
4. Each lane keeps `trailing` = the exact whitespace (blank lines) after its last item.

Serialisation (`KanbanSerializer.write(KanbanBoard) → String`):
- Untouched regions are emitted from `raw` byte-for-byte. Opening and saving a board without changes must produce identical text (round-trip test).
- A changed lane is emitted as: `## <title>\n` + `\n` + (`**Complete**\n` if `completeLane`) + each card's `raw` (joined with `\n`, each ending
  in `\n`) + the lane's original `trailing` (for a new lane: `\n\n`).
- Moving a card moves its `raw` text unchanged. Moving a card into a `completeLane` lane changes its status char to `x`; moving it out of
  such a lane changes `x` to space (this matches the plugin's behaviour). Moving within normal lanes never changes status.
- A new card is written as `- [ ] <text>`.
- A new board (command "New Kanban board") is written exactly as the latest obsidian-kanban plugin writes a new board; in 08.36 you capture a
  real new board from the plugin into `test_vaults/syntax/kanban/new-board-from-plugin.md` and use it as the template.
- `settings` is never modified by Tephra (lane widths and collapse states are plugin UI state). Tephra keeps its own lane collapse state in memory only.

### F4 — Flashcards and `.tephra/flashcards.json`

**Which notes:** only notes that have the tag `#flashcards` or a nested tag `#flashcards/<deck>` (inline or frontmatter). The deck is the tag path
(`flashcards/biology` → deck "biology"; plain `#flashcards` → deck "Default"). This matches the Obsidian Spaced Repetition plugin convention and
prevents random `::` text from becoming cards.

**Card syntax** (lines inside fenced code blocks, inline code and `%%comments%%` are ignored):
1. **Single-line:** a line containing ` :: ` (space, two colons, space): `Capital of France :: Paris`. Question = text before the first ` :: `,
   answer = text after it, both trimmed. (Dataview inline fields `key:: value` have no space before `::` and are **not** cards.)
2. **Multi-line:** a block of non-empty lines, then a line that is exactly `?`, then answer lines until the next blank line:
   ```
   What are the three parts of a cell?
   ?
   Membrane, cytoplasm, nucleus
   ```
3. **Cloze:** any non-card line (outside the two forms above) of a flashcards note that contains `==text==` highlights. Each highlight is one
   card: the question is the line with that highlight replaced by `[...]` (other highlights shown as plain text), the answer is the highlighted text.

**Card identity:** `cardId = "<vault path>#<hash>"` where `hash` is the first 16 lower-case hex characters of SHA-256 of:
`"basic\n" + normalise(question)` for single/multi-line cards, and `"cloze\n" + normalise(lineText) + "\n" + clozeIndex` for cloze cards
(`clozeIndex` is the 0-based index of the highlight in the line). `normalise` = trim, collapse runs of whitespace to one space.
Editing the answer keeps the review history; editing the question starts a new card (the old entry is garbage-collected, below).

**State file** `.tephra/flashcards.json` (UTF-8, pretty-printed with 2-space indentation, keys sorted for stable diffs):
```json
{
  "version": 1,
  "cards": {
    "Biology/Cells.md#3fa2c0d19be4a771": {
      "ef": 2.5,
      "reps": 3,
      "interval": 15,
      "due": "2026-10-26",
      "lapses": 1,
      "lastReview": "2026-10-11T09:14:00Z",
      "lastQuality": 4
    }
  }
}
```
- Cards with no entry are **new** (never reviewed).
- On note rename (`FileMoved`), keys with the old path prefix are rewritten to the new path. On note delete, entries are kept for 30 days
  (field `"orphanedAt": "<ISO>"` added), then removed at the next save. Entries whose card no longer exists in an existing note get the same treatment.
- Writes are atomic and debounced (2 s after the last review, and on app pause).
- **Sync conflicts:** if the sync engine produces a conflict copy matching `.tephra/flashcards (conflict *).json`, Tephra merges it automatically:
  for each card keep the entry with the later `lastReview`; then deletes the conflict copy (moved to trash per Phase 3 rules) and logs `info`.

**SM-2 scheduling** (`Sm2.review(CardState s, int quality, CivilDate today) → CardState`), quality `q` in 0–5:
```
if q >= 3:
    reps' = s.reps + 1
    interval' = reps' == 1 ? 1 : reps' == 2 ? 6 : round(s.interval * s.ef)
    ef' = max(1.3, s.ef + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02)))
    lapses' = s.lapses
else:
    reps' = 0
    interval' = 1
    ef' = s.ef                       // original SM-2: the E-Factor is not changed on a failed recall
    lapses' = s.lapses + 1
due' = today + interval' days
new card: ef = 2.5, reps = 0, interval = 0, lapses = 0
```
Buttons → quality: **Again = 1, Hard = 3, Good = 4, Easy = 5**. `round` is round-half-up to an integer, minimum 1.

### F5 — Sketch file `<name>.sketch.json`

```json
{
  "type": "tephra-sketch",
  "version": 1,
  "width": 1600,
  "height": 1200,
  "background": "#FFFFFF",
  "strokes": [
    {
      "id": "s-1728640000000-1",
      "tool": "pen",
      "color": "#1E1E1EFF",
      "size": 4.0,
      "points": [[120.5, 340.25, 0.42, 0], [121.0, 341.0, 0.47, 16]]
    }
  ]
}
```
- `width`/`height`: canvas size in logical pixels (default 1600 × 1200). `background`: `#RRGGBB` or `"transparent"`.
- `tool`: `"pen"` or `"highlighter"` (eraser and lasso are editing actions, not stored strokes).
- `color`: `#RRGGBBAA`. Highlighter strokes are stored with alpha `0x59` (35 %).
- `size`: base diameter in logical pixels (1–48).
- `points`: `[x, y, pressure, t]` — x/y rounded to 2 decimals, pressure 0.0–1.0 rounded to 2 decimals (`0.5` when the device reports no pressure),
  `t` = milliseconds since the stroke started (integer).
- `id`: unique within the file (`s-<epoch ms>-<counter>`).
- Unknown top-level keys and unknown stroke keys are preserved on save (keep the decoded maps and write them back).
- The PNG preview `<name>.sketch.png` has the same base name and folder and is always regenerated when the JSON is saved.
- New sketches are named `Sketch YYYYMMDDHHmmss` and saved in the attachment folder (conventions §6.7).

### F6 — Encrypted file format TENC v1 (`*.tephraenc`) and `.tephra/encrypted-areas.json`

Binary layout (all integers big-endian):

| Offset | Size | Field |
|---|---|---|
| 0 | 8 | magic ASCII `TPHRENC1` |
| 8 | 1 | format version = `1` |
| 9 | 1 | mode: `1` = standalone (own password), `2` = area member |
| 10 | … | mode 1: `u32 memoryKiB`, `u32 iterations`, `u8 parallelism`, 16-byte salt (25 bytes) — mode 2: 16-byte area id (UUID bytes) |
| next | 12 | AES-GCM nonce (random per write) |
| next | n | ciphertext |
| end | 16 | GCM tag |

- AAD = every byte from offset 0 up to and including the nonce. Any change to the header fails decryption.
- Plaintext payload = `u32 jsonLength` + UTF-8 JSON + raw file bytes. JSON: `{"name":"Meeting notes.md","mtime":"2026-10-11T09:00:00Z"}`.
  `name` is the original file name (the file name on disk is not trusted).
- Standalone key: `Argon2id(password, salt, memoryKiB, iterations, parallelism, length 32)`. Default parameters: reuse the Argon2id parameters
  Phase 3 calibrated for the vault password (find the constant or setting in `tephra_sync`); if none is found, use `memoryKiB 65536, iterations 3,
  parallelism 1`. The parameters are stored in each file, so files with other parameters still open.
- Area key: 32 random bytes, stored wrapped in `.tephra/encrypted-areas.json`; area files use it directly with a fresh random nonce per write.
- On-disk names: standalone encrypted note `X.md` becomes `X.tephraenc` in the same folder (title visible; option "Hide the title" uses a random
  name instead). Files in an encrypted area get random names `<16 lower-case hex>.tephraenc`; their real names are only inside the payload.
  **Folder names inside an area are not encrypted** (documented).

`.tephra/encrypted-areas.json`:
```json
{
  "version": 1,
  "areas": [
    {
      "id": "6f1c2d3e-4a5b-4c6d-8e9f-0a1b2c3d4e5f",
      "folder": "Private",
      "created": "2026-10-11T09:00:00Z",
      "kdf": { "alg": "argon2id", "memoryKiB": 65536, "iterations": 3, "parallelism": 1, "salt": "<base64>" },
      "wrappedKey": { "nonce": "<base64>", "ciphertext": "<base64 incl. tag>" },
      "recoveryWrappedKey": { "nonce": "<base64>", "ciphertext": "<base64 incl. tag>" }
    }
  ]
}
```
- `wrappedKey` = AES-256-GCM(key = Argon2id(password, salt), plaintext = area key, AAD = UTF-8 of `"tephra-area:" + id`).
- `recoveryWrappedKey` = AES-256-GCM(key = HKDF-SHA256(recoveryKeyBytes, info `"tephra-area-recovery"`, 32 bytes), plaintext = area key, same AAD).
  The recovery key is 32 random bytes shown once as 13 groups of 4 Crockford base32 characters (`XXXX-XXXX-…`).
- A wrong password fails the GCM tag check → `WrongPasswordException` (extends `CryptoException`).

### F7 — Transcript block

Inserted directly under the line that contains the audio embed:
```markdown
![[Voice note 20261011093000.wav]]
> [!quote]- Transcript
> First sentence of the transcript.
> Second sentence.
```
- One `> ` line per whisper segment (segment text trimmed; empty segments skipped).
- If the line after the embed already starts with `> [!quote]- Transcript`, the whole callout (all following lines starting with `>`) is replaced.
- `[!quote]` is a built-in Obsidian callout type; the `-` makes it collapsed by default in both apps.

---

## Steps

Every step ends with the standard checks from `GEMINI.md` §3 (format, analyze, tests of touched packages, tick `PROGRESS.md`, commit
`phase 08.S: <summary>`). They are not repeated in each Verify block below; the Verify blocks list the **extra** commands for that step.

Shorthand used in Verify blocks:
- "package tests for X" = `Push-Location packages/X; dart test; Pop-Location`
- "app tests for D" = `Push-Location app; flutter test test/D; Pop-Location`

---

## Block 8a — AI & semantic search (weeks 1–2)

### 08.1 Create `packages/tephra_ai`

**Purpose:** the pure-Dart home of all AI logic, with the dependency boundaries from conventions §3.

**Files:**
- `packages/tephra_ai/pubspec.yaml`
- `packages/tephra_ai/README.md`
- `packages/tephra_ai/lib/tephra_ai.dart`
- `packages/tephra_ai/lib/src/ai_cancel_token.dart`
- `packages/tephra_ai/lib/src/ai_exception.dart`
- `packages/tephra_ai/test/ai_cancel_token_test.dart`
- root `pubspec.yaml` (add `packages/tephra_ai` to `workspace:`)
- `app/pubspec.yaml` (add `tephra_ai: any` under dependencies — workspace resolution)

**Implementation:**
1. `pubspec.yaml`: `name: tephra_ai`, `description: "Tephra AI: Claude client, embeddings, semantic search."`, `publish_to: none`,
   `resolution: workspace`, `environment: sdk: ^3.13.0`. Dependencies: `tephra_core`, `tephra_markdown`, `tephra_index` (as `any`, resolved by the
   workspace), then `dart pub add http sqlite3 crypto path logging` and `dart pub add --dev test`.
2. `AiCancelToken`: `final class AiCancelToken { bool get isCancelled; void cancel(); Future<void> get whenCancelled; void throwIfCancelled(); }`
   — `throwIfCancelled` throws `AiCancelledException`.
3. `ai_exception.dart` (all extend `TephraException` from `tephra_core`):
   ```dart
   sealed class AiException extends TephraException { const AiException(super.message, {this.requestId}); final String? requestId; }
   final class AiAuthException extends AiException { ... }            // HTTP 401
   final class AiPermissionException extends AiException { ... }      // HTTP 403
   final class AiBillingException extends AiException { ... }         // HTTP 402
   final class AiInvalidRequestException extends AiException { final int statusCode; ... }   // 400, 404, 413
   final class AiRateLimitException extends AiException { final Duration? retryAfter; ... }  // 429 after retries
   final class AiOverloadedException extends AiException { ... }      // 529 after retries
   final class AiServerException extends AiException { final int statusCode; ... }           // 5xx after retries
   final class AiNetworkException extends AiException { ... }         // socket/TLS/timeout after retries
   final class AiStreamException extends AiException { final String errorType; ... }         // `event: error` mid-stream
   final class AiCancelledException extends AiException { ... }
   final class AiNotConfiguredException extends AiException { ... }   // no key / AI disabled
   ```
   (If `TephraException` cannot be extended by a `sealed` class in a different package, make `AiException` `abstract` instead and note it.)
4. `lib/tephra_ai.dart`: library doc comment + `export` lines only.
5. README: one paragraph on what the package does, the dependency rule, and "never log prompts, answers, note text or keys".

**Tests:** `ai_cancel_token_test.dart`: `cancel completes whenCancelled`, `throwIfCancelled throws AiCancelledException after cancel`,
`isCancelled is false initially`.

**Verify:** `flutter pub get` at the root; package tests for `tephra_ai`; `dart run tool/check_licenses.dart` passes.

**Pitfalls:** do not add `tephra_vault` or `tephra_search` as dependencies — conventions §3 allows only core, markdown, index.

---

### 08.2 SSE parser

**Purpose:** turn the streaming HTTP body into Server-Sent Events.

**Files:** `packages/tephra_ai/lib/src/llm/sse_event.dart`, `packages/tephra_ai/lib/src/llm/sse_parser.dart`, `packages/tephra_ai/test/llm/sse_parser_test.dart`.

**Implementation:**
1. `final class SseEvent { const SseEvent({required this.event, required this.data}); final String event; final String data; }` with value equality.
2. `abstract final class SseParser { static Stream<SseEvent> parse(Stream<List<int>> bytes); }`:
   - decode with `utf8.decoder` (handles multi-byte characters split across chunks) then `const LineSplitter()` (handles `\n`, `\r\n`, `\r`);
   - for each line: empty line → dispatch the pending event if it has data (event name defaults to `message`), then reset;
     line starting with `:` → comment, ignore; otherwise split at the first `:` into field and value, strip **one** leading space from the value;
     field `event` → set name; field `data` → append value (multiple `data` lines are joined with `\n`); fields `id`/`retry`/others → ignore;
   - at end of stream, dispatch a pending event that has data.

**Tests (named):** `parses a single event`, `joins multiple data lines with newline`, `ignores comment lines`, `handles CRLF line endings`,
`handles a UTF-8 Bangla character split across two chunks` (feed bytes of `"আমি"` split mid-character), `dispatches trailing event without final blank line`,
`defaults event name to message`, `parses the full Anthropic example stream` (fixture `test/fixtures/sse/basic_stream.txt` containing
`message_start`, `content_block_start`, two `content_block_delta`, `content_block_stop`, `message_delta`, `message_stop`, and one `ping`).

**Verify:** package tests for `tephra_ai`.

**Pitfalls:** never split on `\n` manually on raw bytes; always decode first.

---

### 08.3 Claude client — requests, streaming, usage

**Purpose:** call the Anthropic Messages API, streamed.

**Files:**
- `packages/tephra_ai/lib/src/llm/llm_client.dart`, `llm_request.dart`, `llm_message.dart`, `llm_event.dart`, `llm_usage.dart`, `llm_response.dart`
- `packages/tephra_ai/lib/src/llm/claude_client.dart`
- `packages/tephra_ai/test/llm/claude_client_test.dart`, fixtures under `test/fixtures/claude/`

**Implementation:**
1. Models:
   ```dart
   enum LlmRole { user, assistant }
   final class LlmMessage { const LlmMessage(this.role, this.text); final LlmRole role; final String text; }
   enum LlmEffort { low, medium, high }
   final class LlmRequest {
     const LlmRequest({required this.model, required this.messages, this.system, this.maxTokens = 16000, this.effort, this.featureTag = 'other'});
     final String model; final String? system; final List<LlmMessage> messages; final int maxTokens; final LlmEffort? effort;
     final String featureTag;   // 'ask-vault', 'summarise', ... used for the local usage ledger, never sent
   }
   final class LlmUsage { const LlmUsage({this.inputTokens = 0, this.outputTokens = 0, this.cacheReadInputTokens = 0, this.cacheCreationInputTokens = 0});
     final int inputTokens, outputTokens, cacheReadInputTokens, cacheCreationInputTokens; LlmUsage merge(LlmUsage later); }
   sealed class LlmEvent {}
   final class LlmStarted extends LlmEvent { final String messageId; final String model; final LlmUsage usage; }
   final class LlmTextDelta extends LlmEvent { final String text; }
   final class LlmFinished extends LlmEvent { final String? stopReason; final LlmUsage usage; }   // after message_stop
   final class LlmResponse { final String text; final String? stopReason; final LlmUsage usage; final String model; final String messageId; }
   abstract interface class LlmClient {
     Stream<LlmEvent> stream(LlmRequest request, {AiCancelToken? cancel});
     Future<LlmResponse> complete(LlmRequest request, {AiCancelToken? cancel});   // collects the stream
     Future<void> verifyKey();                                                     // throws AiAuthException on a bad key
   }
   ```
2. `ClaudeClient implements LlmClient`, constructor:
   `ClaudeClient({required String apiKey, http.Client? httpClient, Uri? baseUrl, Clock clock = const SystemClock(), Random? random,
   RateLimiter? rateLimiter, Future<void> Function(Duration) sleep = Future.delayed, Duration connectTimeout = const Duration(seconds: 15),
   Duration idleTimeout = const Duration(seconds: 60), bool fallbackOnRefusal = false})`. Default `baseUrl` is `https://api.anthropic.com`.
3. Request (`POST {baseUrl}/v1/messages`), headers exactly:
   ```
   x-api-key: <apiKey>
   anthropic-version: 2023-06-01
   content-type: application/json
   accept: text/event-stream
   ```
   Body (keys in this order; omit `system` when null; omit `output_config` when effort is null):
   ```json
   {
     "model": "claude-sonnet-5-5",
     "max_tokens": 16000,
     "stream": true,
     "system": "You are …",
     "messages": [ { "role": "user", "content": "…" } ],
     "output_config": { "effort": "medium" }
   }
   ```
   When `fallbackOnRefusal` is true **and** the model is in the catalog with `supportsServerFallback` (08.5), also add the header
   `anthropic-beta: server-side-fallback-2026-07-01` and the body field `"fallbacks": "default"`. Before implementing this, open the current
   Anthropic docs (Messages API reference and "Refusals and fallback") and confirm the header value and body shape; if they differ, follow the docs
   and note it in `PROGRESS.md`.
4. Use `http.Request` + `httpClient.send()` to get a `StreamedResponse`. If the status is not 200, read the whole body (it is JSON
   `{"type":"error","error":{"type":"…","message":"…"},"request_id":"…"}`) and map it (08.4). If 200, pipe `response.stream` through `SseParser`.
5. Event mapping (decode `data` with `jsonDecode`, cast to `Map<String, Object?>` immediately):
   - `message_start` → `LlmStarted(message.id, message.model, usage from message.usage)`;
   - `content_block_start` → remember `index → content_block.type`;
   - `content_block_delta` with `delta.type == 'text_delta'` **and** the block type is `text` → `LlmTextDelta(delta.text)`;
     all other delta types (`thinking_delta`, `signature_delta`, `input_json_delta`, `citations_delta`) → ignore;
   - `content_block_stop` → ignore;
   - `message_delta` → remember `delta.stop_reason`; merge `usage` (its `output_tokens` is cumulative: replace, do not add);
   - `message_stop` → emit `LlmFinished(stopReason, mergedUsage)` and close;
   - `ping` → ignore (but resets the idle timer);
   - `error` → throw `AiStreamException(error.type, error.message)` (e.g. `overloaded_error` mid-stream);
   - any other event name → ignore (forward compatibility).
   Content blocks of type `fallback` or `thinking` are skipped automatically by the rule above.
6. `stopReason == 'refusal'` is **not** an exception: the UI shows "Claude declined this request." (08.9). `max_tokens` → UI shows "The answer was cut off."
7. Idle timeout: if no SSE event arrives for `idleTimeout`, cancel the subscription and throw `AiNetworkException('stream stalled')`.
8. Cancellation: `cancel.whenCancelled` → cancel the stream subscription and call `httpClient.close()` only if the client was created internally;
   otherwise abort via the subscription; the stream then ends with `AiCancelledException`.
9. `verifyKey()`: `GET {baseUrl}/v1/models?limit=1` with the same headers (no cost). 200 → ok; 401 → `AiAuthException`; others mapped per 08.4.
10. Logging: `Logger('ai.claude')` logs at `fine`: model, featureTag, status, request id (`request-id` response header), token counts, duration.
    **Never** log the key, system prompt, messages or answer text.

**Tests (use `package:http/testing.dart` `MockClient.streaming`):**
`sends required headers and body`, `omits system when null`, `includes output_config effort when set`, `streams text deltas in order`,
`ignores thinking blocks and their deltas` (fixture with a `thinking` block at index 0 and `text` at index 1), `ignores unknown event types`,
`merges usage from message_start and message_delta`, `reports stop reason refusal without throwing`, `throws AiStreamException on error event`,
`throws AiNetworkException when stream stalls` (fake clock/short idle timeout), `complete collects full text`, `verifyKey succeeds on 200`,
`verifyKey throws AiAuthException on 401`, `adds fallback header and body only for supporting models when enabled`.
Live test (tag `live`, skipped unless `secrets/anthropic_api_key.txt` exists): `live: haiku answers a one-word prompt` using
`claude-haiku-5-5`, `max_tokens: 64`, prompt "Reply with the single word: pong". Run live tests with `dart test --run-skipped -t live` only when asked to.

**Verify:** package tests for `tephra_ai` (live tests skipped by default via `@Tags(['live'])` and a `dart_test.yaml` that skips tag `live` unless `--run-skipped`).

**Pitfalls:** decode JSON per event, never as one document. Do not send `temperature` (non-default sampling values are rejected on current models).
Do not send `thinking: {type: "disabled"}` (rejected on current models).

---

### 08.4 Errors, retries, rate limiting, cancellation

**Purpose:** robust behaviour for 401, 429 (with `retry-after`), 529, 5xx and network failures.

**Files:** `packages/tephra_ai/lib/src/llm/retry_policy.dart`, `rate_limiter.dart`, update `claude_client.dart`;
tests `test/llm/retry_policy_test.dart`, `test/llm/rate_limiter_test.dart`, extend `claude_client_test.dart`.

**Implementation:**
1. Status → exception mapping (from the error body's `error.type` and the HTTP status):
   400 `invalid_request_error` → `AiInvalidRequestException`; 401 → `AiAuthException`; 402 → `AiBillingException`; 403 → `AiPermissionException`;
   404 (e.g. unknown model id) → `AiInvalidRequestException(statusCode: 404)` whose message includes the model id; 413 → `AiInvalidRequestException(413)`;
   429 → retry, then `AiRateLimitException`; 500/502/503/504 → retry, then `AiServerException`; 529 → retry, then `AiOverloadedException`.
   Keep `request_id` from the body (or the `request-id` header) on every exception.
2. `RetryPolicy`:
   - Retries happen **only before the first SSE event has been delivered** to the caller. A failure after text started streaming is surfaced, never retried
     (otherwise the user would see duplicated text).
   - 429: if header `retry-after` is present (integer seconds), wait `min(retryAfter, 60 s)`; if it is above 60 s, do not retry and throw
     `AiRateLimitException(retryAfter: …)`. Without the header wait `2^attempt` seconds. Max **3 attempts** in total.
   - 500/502/503/504/529: wait 1 s, 2 s, 4 s (+ random jitter 0–250 ms from the injected `Random`), max **4 attempts** in total.
   - Network errors (`SocketException`, `HandshakeException`, `http.ClientException`, `TimeoutException` during connect): wait 1 s, 2 s; max **3 attempts**.
   - 400/401/402/403/404/413: never retried.
   - Every wait is cancellable through the `AiCancelToken`.
3. `RateLimiter` (client-side, protects the user's wallet and the API): token bucket, `capacity 10`, refill `10 per minute`, plus
   `maxConcurrent 2` in-flight requests. `Future<void> acquire({AiCancelToken? cancel})` waits for a token and a slot; `release()` frees the slot.
   One limiter instance is shared by all features (provided by the app).

**Tests:** `429 with retry-after 2 waits 2 seconds then succeeds` (fake `sleep` records durations), `429 with retry-after 120 throws immediately`,
`429 without header backs off exponentially`, `529 retried three times then AiOverloadedException`, `500 then 200 succeeds`,
`401 is not retried`, `network error retried twice`, `no retry after first text delta` (MockClient stream that errors after one delta),
`cancel during backoff throws AiCancelledException`, `rate limiter blocks 11th request within a minute`, `rate limiter allows max 2 concurrent`.

**Verify:** package tests for `tephra_ai`.

**Pitfalls:** use the injected `sleep` and `Clock` everywhere so tests run instantly.

---

### 08.5 Model catalog and cost

**Purpose:** model choices, prices and cost display from the response `usage`.

**Files:** `packages/tephra_ai/lib/src/llm/model_catalog.dart`, `cost_calculator.dart`, `test/llm/cost_calculator_test.dart`.

**Implementation:**
1. ```dart
   final class ModelInfo {
     const ModelInfo({required this.id, required this.label, required this.inputUsdPerMTok, required this.outputUsdPerMTok,
       required this.cacheReadUsdPerMTok, this.longPromptThresholdTokens, this.longInputUsdPerMTok, this.longOutputUsdPerMTok,
       this.supportsServerFallback = false, this.defaultEffort});
     ...
   }
   abstract final class ModelCatalog {
     static const defaultModelId = 'claude-sonnet-5-5';
     static const List<ModelInfo> builtIn = [ … ];
     static ModelInfo? byId(String id);
   }
   ```
2. Built-in entries (prices in USD per million tokens, as published on 2026-10-06 — **open the Anthropic pricing page and confirm before committing**;
   if they changed, use the current values and note the date):
   | id | label | input | output | cache read | notes |
   |---|---|---|---|---|---|
   | `claude-sonnet-5-5` | Claude Sonnet 5.5 (recommended) | 2.00 | 10.00 | 0.20 | `supportsServerFallback: true` |
   | `claude-opus-5-5` | Claude Opus 5.5 (most capable) | 4.00 | 20.00 | 0.20 | `supportsServerFallback: true` |
   | `claude-haiku-5-5` | Claude Haiku 5.5 (fastest, cheapest) | 0.10 | 0.50 | — (use input price) | long prompts > 100,000 input tokens: 0.50 / 2.50 |
3. `CostCalculator.estimateUsd(LlmUsage usage, ModelInfo? model) → double?` = input × in-price + output × out-price + cacheRead × cache price
   (+ cacheCreation × input price), per million; for Haiku use the long-prompt prices when `inputTokens > longPromptThresholdTokens`.
   Unknown (custom) model → `null` (UI shows tokens only).
4. `CostCalculator.estimateInputTokens(String text) → int` = `(text.runes.length / 3).ceil()` — used only for previews before sending (labelled "≈").

**Tests:** `sonnet cost for 1000 in and 500 out`, `haiku long prompt pricing applies above threshold`, `unknown model returns null`,
`estimateInputTokens for empty string is 0`, `byId finds default model`.

**Verify:** package tests for `tephra_ai`.

**Pitfalls:** prices change; the settings screen shows "Prices as of <date>" from a constant `ModelCatalog.pricesAsOf`.

---

### 08.6 Prompt templates with golden tests

**Purpose:** every prompt Tephra sends lives in one place, versioned and tested.

**Files:**
- `packages/tephra_ai/lib/src/prompts/prompt_template.dart`
- `packages/tephra_ai/lib/src/prompts/templates.dart` (all templates)
- `packages/tephra_ai/test/prompts/prompt_golden_test.dart`
- `packages/tephra_ai/test/goldens/prompts/<id>.txt` (one per template)

**Implementation:**
1. ```dart
   final class PromptTemplate {
     const PromptTemplate({required this.id, required this.version, required this.system, required this.user});
     final String id; final int version; final String system; final String user;
     RenderedPrompt render(Map<String, String> vars);   // replaces {{name}}; throws ArgumentError on a missing or unused variable
   }
   final class RenderedPrompt { final String system; final String user; }
   ```
   Placeholder regex `\{\{([a-zA-Z][a-zA-Z0-9_]*)\}\}`. No conditionals or loops — callers pre-format lists into strings.
2. Templates (ids and the exact variables each needs):
   | id | variables | output contract |
   |---|---|---|
   | `ask-vault` | `sources`, `question` | Markdown answer with `[[…]]` citations |
   | `ask-vault-cite-retry` | `sources`, `question`, `previousAnswer` | same as above |
   | `summarise` | `text`, `language` | Markdown summary |
   | `rewrite` | `text`, `style` | rewritten text only |
   | `translate` | `text`, `targetLanguage` | translation only |
   | `explain` | `text`, `noteTitle` | explanation in Markdown |
   | `continue` | `textBefore`, `noteTitle` | continuation text only (no repetition of the input) |
   | `suggest-tags` | `noteText`, `existingTags` | JSON `{"tags":["…"]}` |
   | `suggest-links` | `noteText`, `candidates` | JSON `{"links":[{"phrase":"…","target":"…"}]}` |
   | `flashcards` | `noteText`, `maxCards` | JSON `{"cards":[{"q":"…","a":"…"}]}` |
3. The `ask-vault` system prompt, verbatim:
   ```
   You are the assistant inside Tephra, a notes app. You answer questions using only the user's notes, which are given to you as numbered sources.
   Rules:
   1. Use only facts from the sources. Do not use outside knowledge.
   2. After every sentence that uses a source, add its citation exactly as written in that source's cite attribute, for example [[Project Alpha#Risks]].
   3. If the sources do not contain the answer, reply exactly: I could not find this in your notes.
   4. Never invent a citation. Cite only the sources given.
   5. Reply in the same language as the question.
   6. Use Markdown. Be concise.
   ```
   `ask-vault` user template, verbatim:
   ```
   <sources>
   {{sources}}
   </sources>

   Question: {{question}}
   ```
   Each source is formatted by the caller as:
   ```
   <source id="3" cite="[[Project Alpha#Risks]]">
   …chunk text…
   </source>
   ```
4. Write the other templates in the same style: a short system prompt with numbered rules, the output contract stated explicitly
   ("Reply with JSON only, in this exact shape: …", "Reply with the rewritten text only, no preamble"), and the user part wrapping input in
   tags (`<note>…</note>`, `<text>…</text>`). The tag/JSON templates must say "Do not wrap the JSON in code fences."
5. Golden test: for each template, render with fixed sample variables (defined in the test) and compare `system + "\n-----\n" + user` with
   `test/goldens/prompts/<id>.txt`. When the environment variable `UPDATE_GOLDENS=1` is set, the test writes the file instead of comparing.
   Bump `version` whenever a template's text changes.

**Tests:** `golden <id>` for all 10 templates, `render throws on missing variable`, `render throws on unused variable`,
`render does not touch single braces`, `all template ids are unique`.

**Verify:** `$env:UPDATE_GOLDENS='1'; dart test test/prompts; Remove-Item Env:UPDATE_GOLDENS` (inside the package) once to create goldens,
review them by reading the files, then package tests for `tephra_ai` without the variable.

**Pitfalls:** never put dates/times or random ids into prompts (keeps goldens stable and prompt caching possible later).

---

### 08.7 App: AI settings, key storage, usage ledger

**Purpose:** let the user enable AI, store the key securely, pick a model, and see what they spent.

**Files:**
- `app/lib/ai/providers.dart`
- `app/lib/ai/settings/ai_settings.dart` (model), `ai_settings_notifier.dart`, `ai_settings_screen.dart`
- `app/lib/ai/settings/api_key_store.dart`
- `app/lib/ai/usage/usage_ledger.dart`, `usage_screen.dart`
- settings navigation entry (the Phase 7 settings screen list)
- `app/lib/l10n/app_en.arb` (all strings)
- tests: `app/test/ai/settings/ai_settings_notifier_test.dart`, `api_key_store_test.dart`, `usage_ledger_test.dart`, `ai_settings_screen_test.dart`

**Implementation:**
1. `AiSettings` (immutable, `toJson`/`fromJson`, stored in the app-level `<appSupportDir>/settings.json` under key `"ai"` through the existing app
   settings service): `enabled` (false), `modelId` (`claude-sonnet-5-5`), `customModelId` (null), `effort` (`medium`), `maxTokens` (16000),
   `alwaysConfirm` (true), `fallbackOnRefusal` (true), `baseUrl` (null = default), `semanticProvider` (`local` | `voyage` | `off`, default `local`),
   `voyageModel` (`voyage-3.5-lite`), `relatedNotesEnabled` (true), `autoTranscribe` (false — used in 8c).
2. `ApiKeyStore` wraps `flutter_secure_storage`: keys `ai.anthropic.apiKey` and `ai.voyage.apiKey`. Methods `read`, `write`, `delete`, `hasKey`.
   Never cache the key in a provider that might be logged; read it when building the client.
3. Providers: `aiSettingsProvider` (NotifierProvider), `apiKeyStoreProvider`, `rateLimiterProvider` (one shared `RateLimiter`),
   `llmClientProvider` (FutureProvider: returns `ClaudeClient` or throws `AiNotConfiguredException` when disabled or no key).
4. Settings screen sections:
   - **AI assistant**: master switch (turning it on shows the privacy notice dialog once: "Tephra sends text to Anthropic only when you use an AI
     action. Each time, you'll see what will be sent. Your key is stored on this device only." with "Turn on" / "Cancel");
     API key field (obscured, paste button, "Test key" → `verifyKey()`, shows "Key works" or the mapped error), link "Get a key" → opens
     `https://console.anthropic.com/settings/keys` in the browser; model dropdown (catalog labels + "Custom…" which shows a text field);
     effort (Low / Medium / High); "Always confirm before sending" switch; "Fall back to another model if Claude declines" switch;
     advanced (collapsed): max output tokens (1,000–64,000), API base URL.
   - **Semantic search**: provider (On this device / Voyage AI / Off), model status and download button (wired in 08.15), Voyage key field.
   - **Usage**: this month's tokens and estimated cost, button "Usage details".
5. `UsageLedger`: appends one record per completed request to `<appSupportDir>/ai_usage.json`:
   `{"version":1,"records":[{"at":"ISO","model":"…","feature":"ask-vault","in":123,"out":456,"cacheRead":0,"usd":0.0034}]}` — no prompt or answer text.
   Keeps the last 13 months; atomic write. `UsageScreen` shows per-month totals and per-feature totals.

**Tests:** `settings round-trip to JSON`, `defaults are AI disabled and sonnet`, `api key store writes and reads via fake secure storage`
(override with an in-memory fake), `llmClientProvider throws AiNotConfiguredException when disabled`, `ledger appends and totals by month`,
`ledger prunes records older than 13 months`, widget test `turning AI on shows privacy notice`, `test key shows success on 200` (override client).

**Verify:** app tests for `ai`; manual: on Windows, `flutter run -d windows`, open Settings → AI, paste the key from `secrets/anthropic_api_key.txt`,
press "Test key" → "Key works". Repeat on Android.

**Pitfalls:** never put the key into `settings.json`, logs, crash reports or the clipboard (the paste button reads the clipboard; it never writes it).

---

### 08.8 Outbound preview and the AI request gateway

**Purpose:** one choke point through which every AI request passes: settings check, privacy preview, rate limit, usage ledger, error mapping.

**Files:**
- `packages/tephra_ai/lib/src/privacy/outbound_preview.dart` (model)
- `app/lib/ai/gateway/ai_gateway.dart`
- `app/lib/ai/gateway/outbound_preview_sheet.dart`
- `app/lib/ai/gateway/ai_error_messages.dart`
- tests: `packages/tephra_ai/test/privacy/outbound_preview_test.dart`, `app/test/ai/gateway/ai_gateway_test.dart`, `outbound_preview_sheet_test.dart`

**Implementation:**
1. ```dart
   final class OutboundItem { const OutboundItem({required this.label, this.path, this.heading, required this.charCount, required this.snippet}); ... }
   final class OutboundPreview {
     const OutboundPreview({required this.featureLabel, required this.modelId, required this.items, required this.extraUserText});
     int get totalChars; int get estimatedInputTokens;   // via CostCalculator.estimateInputTokens over everything sent
     double? estimatedMaxCostUsd(ModelInfo? model, int maxTokens);
   }
   ```
   `snippet` = first 160 characters of the item text with newlines replaced by spaces.
2. `AiGateway` (provided by `aiGatewayProvider`) with one method:
   ```dart
   Stream<LlmEvent> run({required BuildContext context, required OutboundPreview preview, required LlmRequest request, AiCancelToken? cancel});
   ```
   Order: (a) settings enabled + key present, else throw `AiNotConfiguredException` (UI offers "Open AI settings");
   (b) if `alwaysConfirm`, show `OutboundPreviewSheet` and wait; Cancel → `AiCancelledException`; (c) `rateLimiter.acquire`;
   (d) stream from `llmClient`; (e) on `LlmFinished`, append to `UsageLedger` and update a `lastRequestUsageProvider` (for the cost chip);
   (f) `rateLimiter.release` in `finally`.
3. `OutboundPreviewSheet` (bottom sheet on phone layout, dialog on desktop layout): title "Send to Claude?", the feature name, model label,
   a list of items ("<note title> › <heading>", char count, snippet), the extra text the user typed, "≈ N tokens, at most $X.XX", a checkbox
   "Always ask before sending" (unchecking sets `alwaysConfirm=false` after the send), buttons **Send** and **Cancel**.
   When `alwaysConfirm` is off, the UI instead shows a small chip "Sent 5 items to Claude" after sending; tapping it opens the same list read-only.
4. `aiErrorMessage(AppLocalizations l10n, Object error) → String` maps every `AiException` subclass to a plain sentence, e.g.
   401 → "Your API key was rejected. Check it in Settings → AI.", 429 → "Too many requests right now. Try again in a minute.",
   529 → "Claude is overloaded at the moment. Try again shortly.", network → "Can't reach Anthropic. Check your internet connection.",
   404 → "The model \"{model}\" isn't available for your key.", 402 → "Your Anthropic account has a billing problem.".

**Tests:** `preview totals chars and tokens`, `snippet is 160 chars single line`, gateway: `throws not configured when disabled`,
`shows preview when alwaysConfirm`, `skips preview when alwaysConfirm is false`, `cancel in preview sends nothing` (fake client records zero calls),
`records usage after finish`, `releases rate limiter on error`; widget test of the sheet showing items.

**Verify:** app tests for `ai`.

**Pitfalls:** every later AI feature must call `AiGateway.run`; never call `LlmClient` directly from a widget.

---

### 08.9 Selection actions

**Purpose:** summarise, rewrite, translate, explain and continue on selected text.

**Files:**
- `packages/tephra_ai/lib/src/features/selection_actions.dart`
- `app/lib/ai/selection/selection_action_commands.dart`, `selection_result_panel.dart`, `providers.dart`
- `app/lib/editor/…` (add a context-menu/toolbar entry that calls the commands — find where the Phase 1 editor builds its context menu)
- tests: `packages/tephra_ai/test/features/selection_actions_test.dart`, `app/test/ai/selection/selection_result_panel_test.dart`

**Implementation:**
1. `enum SelectionAction { summarise, rewrite, translate, explain, continueWriting }` and
   `LlmRequest buildSelectionRequest({required SelectionAction action, required String selectedText, required String noteTitle, required String modelId,
   String? style, String? targetLanguage, String? textBefore, String language = 'the same language as the text', int maxTokens = 16000, LlmEffort? effort})`.
   `continueWriting` uses the 2,000 characters before the cursor as `textBefore` when nothing is selected.
2. Limits: selected text above 40,000 characters → refuse with "Select less text (max 40,000 characters)."
3. Commands (conventions §7.8, ids): `ai.summarise-selection`, `ai.rewrite-selection`, `ai.translate-selection`, `ai.explain-selection`,
   `ai.continue-writing`. `isAvailable`: AI enabled and an editor is focused. Rewrite asks for a style (Clearer / Shorter / More formal / Friendlier);
   translate asks for a target language (English, বাংলা (Bangla), or free text; last choice remembered).
4. `SelectionResultPanel`: streams the answer as Markdown (reading renderer); buttons **Replace selection** (one undoable edit),
   **Insert below**, **Copy**, **Discard**, **Stop** (cancels while streaming). Shows the usage chip "1,234 in · 456 out · $0.006" after finishing.
   Refusal → "Claude declined this request."; `max_tokens` → "The answer was cut off." with a "Continue" button that is **not** implemented
   in this phase (do not add it).
5. The preview item for selection actions is labelled "Selected text from <note title>".

**Tests:** `builds summarise request with template text`, `continue uses text before cursor`, `refuses over 40k chars`,
`rewrite passes style variable`, widget: `replace selection applies one undo step`, `stop cancels stream`.

**Verify:** app tests for `ai`; manual on both platforms: select a paragraph → Summarise → preview → Send → streamed result → Replace → Ctrl+Z restores.

**Pitfalls:** never apply a result automatically.

---

### 08.10 Note chunker

**Purpose:** split notes into heading-based chunks of ~300–500 tokens with overlap, deterministically.

**Files:** `packages/tephra_ai/lib/src/chunk/note_chunk.dart`, `note_chunker.dart`, `token_estimate.dart`, `test/chunk/note_chunker_test.dart`, fixtures in `test/fixtures/notes/`.

**Implementation:**
1. ```dart
   final class NoteChunk {
     final VaultPath path; final int ordinal; final List<String> headingPath;   // ['Project', 'Risks']; empty for text before the first heading
     final int start; final int end;          // UTF-16 offsets into the normalised note text
     final String text;                       // note text [start, end)
     final String embedText;                  // what is embedded (see 6)
     final String textHash;                   // lower-case hex SHA-256 of embedText
   }
   abstract final class NoteChunker { static List<NoteChunk> chunk(VaultPath path, ParsedNote note, {ChunkerOptions options = const ChunkerOptions()}); }
   final class ChunkerOptions { const ChunkerOptions({this.targetTokens = 400, this.maxTokens = 500, this.minTokens = 80, this.overlapTokens = 50}); }
   int estimateTokens(String s) => (s.runes.length / 3).ceil();
   ```
   The estimate is intentionally independent of the tokenizer so chunk boundaries never depend on whether a model is downloaded.
2. Body = text after the frontmatter (`MdFrontmatter.contentStart`, or 0). Skip notes whose body is shorter than 20 characters (no chunks).
3. Sections: split the body at every heading (`ParsedNote.headings`, any level). A section = heading line + content up to the next heading.
   `headingPath` = the texts of the enclosing headings (H1 › H2 › current). Text before the first heading is a section with an empty path.
4. Merge: a section with `estimateTokens < minTokens` is merged into the **following** section if the merged estimate ≤ `maxTokens`
   (the merged chunk keeps the first section's heading path); a tiny last section merges into the previous one under the same rule.
5. Split: a section with estimate > `maxTokens` is split at top-level block boundaries (AST block nodes of the section) by greedy packing up to
   `targetTokens`; a single block above `maxTokens` is split at sentence ends (regex `(?<=[.!?।])\s+`; `।` is the Bangla danda), and a sentence
   above `maxTokens` is split into windows of `maxTokens * 3` runes. Every piece after the first in the same section starts with an overlap: the last
   `overlapTokens * 3` runes of the previous piece, moved forward to the next whitespace (so words are not cut). `start` points at the overlap start.
6. `embedText = 'passage: ' + noteTitle + (headingPath.isEmpty ? '' : ' > ' + headingPath.join(' > ')) + '\n' + text.trim()`
   where `noteTitle` = `path.stem`. (The `passage: ` prefix is required by e5 models; other providers strip it, see 08.12.)
7. Code blocks are kept (they carry meaning); `%%comments%%` are removed from `embedText` (not from offsets).

**Tests:** `short note gives one chunk`, `splits at headings with heading path`, `merges tiny sections`, `long section split with overlap`,
`overlap does not cut a word`, `Bangla sentences split at danda`, `frontmatter excluded`, `comments removed from embedText`,
`deterministic: same input same hashes`, `offsets slice back to text` (for every chunk `note.text.substring(start, end) == text`).

**Verify:** package tests for `tephra_ai`.

**Pitfalls:** offsets are UTF-16 (Dart `String` indices) — use `runes` only for size estimates, never for offsets.

---

### 08.11 Unigram (XLM-R) tokenizer

**Purpose:** tokenise text for multilingual-e5-small in pure Dart from `tokenizer.json`.

**Files:**
- `packages/tephra_ai/lib/src/embed/unigram_tokenizer.dart`
- `tool/gen_tokenizer_fixtures.py`
- `tool/fetch_ai_test_assets.dart`
- `packages/tephra_ai/test/embed/unigram_tokenizer_test.dart`
- `packages/tephra_ai/test/fixtures/e5_tokens.json` (generated, committed — small)
- `.gitignore`: add `packages/tephra_ai/test/fixtures/model/`

**Implementation:**
1. `tool/fetch_ai_test_assets.dart` downloads `tokenizer.json` (and in 08.15 the model) from the pinned URLs in 08.15 into
   `packages/tephra_ai/test/fixtures/model/` and verifies SHA-256. (For this step, first look up the current commit of
   `https://huggingface.co/Xenova/multilingual-e5-small` on its "Files and versions" page, use the URL form
   `https://huggingface.co/Xenova/multilingual-e5-small/resolve/<commit>/tokenizer.json`, download it once, compute the hash with
   `Get-FileHash -Algorithm SHA256`, and write commit + hash as constants into `tool/fetch_ai_test_assets.dart`.)
2. `UnigramTokenizer.fromJson(Map<String, Object?> tokenizerJson)`:
   - read `model.type` (must be `Unigram`), `model.vocab` (list of `[piece, score]`), `model.unk_id`;
   - build a trie (or a `Map<String, int>` plus max piece length) over pieces;
   - special tokens: `<s>` = 0, `<pad>` = 1, `</s>` = 2, `<unk>` = 3 (read the ids from `added_tokens` rather than hard-coding; assert they match).
3. `List<int> encode(String text, {int maxLength = 512})`:
   - normalise: replace runs of whitespace (`\s+`) with a single space, trim (the model's precompiled charsmap normalisation is not reproduced;
     the fixtures in step 5 show the remaining difference is negligible for normal text — record any mismatch);
   - pre-tokenise like Metaspace: replace each space with `▁` (U+2581) and prepend `▁` to the whole text;
   - split into words at `▁` boundaries (each word starts with `▁`);
   - Viterbi per word: `best[i]` = best score for prefix of length i (in UTF-16 units, but only at code-point boundaries); for every vocab piece that
     matches at position j, `best[j+len] = max(best[j] + score)`; if no piece covers a code point, use `unk_id` with score `min_score - 10`;
     backtrack to get piece ids; merge consecutive unknowns into one `unk`;
   - result `[0] + ids + [2]`, truncated so the total length is ≤ `maxLength` (keep `</s>` at the end).
4. `tool/gen_tokenizer_fixtures.py`: reads the downloaded `tokenizer.json` with `tokenizers.Tokenizer.from_file`, encodes each sentence in a fixed list
   of 30 inputs (English prose, a Markdown heading, a wikilink, code, numbers and dates, emoji, Bangla sentences — at least 8 —, mixed Bangla/English,
   multiple spaces, an empty string) and writes `[{"text": …, "ids": […]}]` to `packages/tephra_ai/test/fixtures/e5_tokens.json`.
   Run: `python tool/gen_tokenizer_fixtures.py packages/tephra_ai/test/fixtures/model/tokenizer.json packages/tephra_ai/test/fixtures/e5_tokens.json`.
5. Test compares Dart output with the fixture ids.

**Tests (tag `model`, skipped with a clear message when `test/fixtures/model/tokenizer.json` is missing):**
`matches reference ids for all fixture sentences` (required: ≥ 28 of 30 exactly equal; the test prints the mismatching sentences; any mismatch
must be in the emoji/symbol cases, not in English or Bangla prose), `adds bos and eos`, `truncates to maxLength keeping eos`,
`empty string gives [0, 2]`, `unknown character maps to unk`.

**Verify:** `dart run tool/fetch_ai_test_assets.dart`; then inside the package `dart test test/embed -t model`.

**Pitfalls:** do not commit `tokenizer.json` (≈17 MB). CI must run `dart run tool/fetch_ai_test_assets.dart` before tagged model tests
(add that step to `.github/workflows/ci.yml`, nightly job only).

---

### 08.12 Embedding interfaces, e5 helpers and Voyage

**Purpose:** a provider-neutral embedding interface.

**Files:**
- `packages/tephra_ai/lib/src/embed/embedding_model.dart`
- `packages/tephra_ai/lib/src/embed/e5_math.dart`
- `packages/tephra_ai/lib/src/embed/voyage_embedding_model.dart`
- tests: `test/embed/e5_math_test.dart`, `test/embed/voyage_embedding_model_test.dart`

**Implementation:**
1. ```dart
   enum EmbedKind { query, passage }
   abstract interface class EmbeddingModel {
     String get id;                 // 'local:multilingual-e5-small@<sha8>' or 'voyage:voyage-3.5-lite'
     int get dimensions;            // 384 for e5-small
     double get minUsefulScore;     // results below this are hidden (tuned in 08.18)
     Future<List<Float32List>> embed(List<String> texts, {required EmbedKind kind, AiCancelToken? cancel});   // L2-normalised vectors
     Future<void> dispose();
   }
   ```
   Callers pass texts **with** the `passage: `/`query: ` prefix produced by `NoteChunker` and `queryText(String q) => 'query: ' + q.trim()`.
   Providers that do not want prefixes strip them (`stripE5Prefix`).
2. `e5_math.dart`: `Float32List meanPool(Float32List hidden, List<int> attentionMask, int seqLen, int dim)` (mean over positions with mask 1),
   `void l2NormaliseInPlace(Float32List v)`, `double dot(Float32List a, Float32List b)` using `Float32x4List` views when the length is a multiple of 4
   (scalar loop otherwise).
3. `VoyageEmbeddingModel implements EmbeddingModel`: `POST https://api.voyageai.com/v1/embeddings`, headers `Authorization: Bearer <key>`,
   `content-type: application/json`; body `{"input": [...stripped texts], "model": "voyage-3.5-lite", "input_type": "document" | "query"}`;
   response `{"data":[{"embedding":[…],"index":0}],"usage":{"total_tokens":N}}` — order results by `index`. Batch ≤ 128 texts per request.
   Retry 429/5xx like 08.4 (reuse `RetryPolicy`). `dimensions` = length of the first returned vector (default 1024). **Before coding, open the
   Voyage API docs and confirm the endpoint, field names and current model names**; record what you used.
   Privacy: Voyage receives every chunk of the vault when indexing. The app shows a consent dialog before enabling it (08.16).

**Tests:** `meanPool ignores padding`, `l2 normalised vector has unit length`, `dot of identical normalised vectors is 1`,
`dot matches scalar reference on random vectors (seeded)`, Voyage: `sends bearer auth and input_type`, `orders by index`, `batches 300 texts into 3 requests`,
`strips e5 prefixes`. Live test (tag `live`, needs `secrets/voyage_api_key.txt`): `live: voyage embeds two texts`.

**Verify:** package tests for `tephra_ai`.

**Pitfalls:** vectors must be L2-normalised by every provider so cosine = dot product.

---

### 08.13 Vector store and in-memory vector index

**Purpose:** persist vectors (D6) and search them fast (D7).

**Files:** `packages/tephra_ai/lib/src/vector/vector_store.dart`, `vector_index.dart`, `semantic_hit.dart`;
tests `test/vector/vector_store_test.dart`, `test/vector/vector_index_test.dart`.

**Implementation:**
1. `VectorStore.open(String file)` (uses `package:sqlite3` `sqlite3.open`; on Android the native library is already bundled by `sqlite3_flutter_libs`
   from Phase 2). Pragmas: `journal_mode=WAL`, `synchronous=NORMAL`, `foreign_keys=ON`. Schema (version 1, stored in `meta`):
   ```sql
   CREATE TABLE IF NOT EXISTS meta(key TEXT PRIMARY KEY, value TEXT NOT NULL);
   CREATE TABLE IF NOT EXISTS chunks(
     id INTEGER PRIMARY KEY,
     path TEXT NOT NULL, ordinal INTEGER NOT NULL, heading TEXT NOT NULL,
     start_offset INTEGER NOT NULL, end_offset INTEGER NOT NULL,
     text_hash TEXT NOT NULL, note_hash TEXT NOT NULL,
     UNIQUE(path, ordinal));
   CREATE INDEX IF NOT EXISTS chunks_path ON chunks(path);
   CREATE TABLE IF NOT EXISTS chunk_vectors(
     chunk_id INTEGER PRIMARY KEY REFERENCES chunks(id) ON DELETE CASCADE,
     model_id TEXT NOT NULL, dims INTEGER NOT NULL, vector BLOB NOT NULL);   -- float32 little-endian, L2-normalised
   ```
   `heading` = `headingPath.join(' › ')`. Chunk text is **not** stored (read from the note when needed, so it is always current).
2. API: `String? get modelId` (from `meta`), `void resetForModel(String modelId, int dims)` (deletes everything, sets meta),
   `Map<String, String> noteHashes()` (path → note_hash), `void replaceNote(String path, String noteHash, List<NoteChunk> chunks, List<Float32List> vectors)`
   (one transaction: delete the path's chunks, insert new rows), `void removeNote(String path)`, `Iterable<StoredVector> all()` (streams rows),
   `List<ChunkRow> chunksFor(String path)`, `Float32List? vectorFor(int chunkId)`, `void close()`.
   `replaceNote` reuses existing vectors when a new chunk has the same `text_hash` as an old chunk of that path (the caller only embeds new hashes —
   see 08.14).
3. `VectorIndex` (in memory, worker isolate only):
   - holds `Int8List data` (n × dims), `Float32List scales` (per row: max |x| / 127), `Int32List chunkIds`, plus `Map<String, List<int>> rowsByPath`;
   - `void load(Iterable<StoredVector>)`, `void upsertPath(String path, List<(int chunkId, Float32List v)>)`, `void removePath(String path)`
     (removal marks rows dead and compacts when > 20 % dead);
   - `List<SemanticHit> search(Float32List query, {int k = 20, Set<String> excludePaths = const {}, int rerank = 100})`:
     first pass: quantise the query the same way, integer dot product per row (`int` accumulator), score = dot × qScale × rowScale;
     keep the best `rerank` rows in a bounded min-heap; second pass: exact float32 dot via `VectorStore.vectorFor` for those rows (cache the float
     vectors of re-ranked rows in an LRU of 2,000 entries); return top `k` sorted descending.
   - `SemanticHit { String path; int chunkId; int ordinal; String heading; int start; int end; double score; }`.

**Tests:** store: `creates schema and meta`, `replaceNote replaces rows in one transaction`, `removeNote cascades vectors`, `resetForModel clears data`,
`noteHashes returns latest`; index: `exact match ranks first`, `excludePaths are skipped`, `int8 first pass + rerank equals brute-force float top-10
on 5,000 random vectors (seeded)`, `removePath then search never returns that path`, `benchmark: 30,000 × 384 search under 150 ms on Windows`
(prints the time; tag `bench`).

**Verify:** package tests for `tephra_ai`; `dart test -t bench` once and record the number in `PROGRESS.md`.

**Pitfalls:** use `ByteData`/`Float32List.view` with `Endian.little` explicitly when encoding blobs.

---

### 08.14 Semantic indexer

**Purpose:** keep vectors in step with the vault, incrementally.

**Files:** `packages/tephra_ai/lib/src/semantic/semantic_indexer.dart`, `semantic_progress.dart`; test `test/semantic/semantic_indexer_test.dart`.

**Implementation:**
1. ```dart
   final class SemanticIndexer {
     SemanticIndexer({required VectorStore store, required VectorIndex index, required EmbeddingModel model, int batchSize = 16});
     ReconcilePlan plan(Map<String, String> currentNoteHashes);   // which paths to embed and which to remove
     Future<void> upsertNote(VaultPath path, String noteHash, String text, {AiCancelToken? cancel});
     void removeNote(VaultPath path);
     Future<List<SemanticHit>> search(String query, {int k = 20, Set<String> excludePaths = const {}});
     Future<List<SemanticHit>> related(VaultPath path, {int k = 10});
   }
   final class ReconcilePlan { final List<String> toEmbed; final List<String> toRemove; }
   ```
2. On construction: if `store.modelId != model.id`, call `store.resetForModel(model.id, model.dimensions)`. Then `index.load(store.all())`.
3. `upsertNote`: parse with `MarkdownParser.parse(text)`, chunk with `NoteChunker`, find chunks whose `textHash` is not already stored for this path,
   embed only those (in batches of `batchSize`, checking `cancel` between batches), then `store.replaceNote` and `index.upsertPath`.
4. `plan`: compare the given map (path → content hash, Markdown notes only, `.tephraenc` excluded) with `store.noteHashes()`.
5. `search`: embed `queryText(query)` with `EmbedKind.query`, `index.search`, drop hits below `model.minUsefulScore`.
6. `related(path)`: mean of that note's stored vectors (normalised) as the query; exclude the note itself; aggregate hits per note by max score;
   return the top `k` notes (one hit per note, the best chunk).

**Tests (fake `EmbeddingModel` that maps text to deterministic vectors via hashing):** `plan finds new, changed and deleted notes`,
`unchanged chunks are not re-embedded` (count embed calls), `model change resets store`, `search returns best matching note`,
`related excludes the note itself`, `cancel stops between batches`.

**Verify:** package tests for `tephra_ai`.

**Pitfalls:** this class runs inside the worker isolate (08.16); keep it free of Flutter imports and global state.

---

### 08.15 App: model download manager and ONNX embedder

**Purpose:** download the e5 model on demand and run it with ONNX Runtime on Windows and Android.

**Files:**
- `app/lib/ai/models/model_catalog_local.dart` (pinned URLs, sizes, SHA-256)
- `app/lib/ai/models/model_download_service.dart`, `model_download_tile.dart`
- `app/lib/ai/semantic/onnx_e5_embedder.dart`
- tests: `app/test/ai/models/model_download_service_test.dart`; integration test `app/integration_test/onnx_e5_test.dart`

**Implementation:**
1. Pin the model files. Use the same Hugging Face commit as 08.11 and the URL form `https://huggingface.co/Xenova/multilingual-e5-small/resolve/<commit>/<file>`
   for `onnx/model_quantized.onnx` and `tokenizer.json`. Download each once, compute SHA-256 and size, and write them as constants:
   ```dart
   const e5Model = LocalModelSpec(
     id: 'multilingual-e5-small-q8', displayName: 'Multilingual (e5-small, 118 MB)', licence: 'MIT',
     files: [ModelFile(name: 'model_quantized.onnx', url: '…/<commit>/onnx/model_quantized.onnx', sha256: '…', bytes: …),
             ModelFile(name: 'tokenizer.json', url: '…/<commit>/tokenizer.json', sha256: '…', bytes: …)]);
   ```
   The model id used for vectors is `local:multilingual-e5-small@<first 8 hex of the onnx sha256>`.
2. `ModelDownloadService`: downloads into `<appSupportDir>/models/<spec.id>/<file>.part` with HTTP `Range` resume, verifies SHA-256 while streaming,
   renames to the final name only when the hash matches (mismatch → delete `.part`, error "Download damaged, please retry").
   Exposes `Stream<ModelDownloadState>` (notDownloaded, downloading(received, total), verifying, ready, failed(message)); `delete()` removes the folder.
   Before starting, a dialog states the size ("Downloads 135 MB. Use Wi-Fi if you pay for mobile data.").
3. `OnnxE5Embedder implements EmbeddingModel` (lives in the app because `onnxruntime` is a Flutter plugin):
   - load `tokenizer.json` → `UnigramTokenizer`; create the session from the model file (check the `onnxruntime` README for the current API:
     at the time of writing `OrtEnv.instance.init()`, `OrtSessionOptions()`, `OrtSession.fromFile(file, options)` or `fromBuffer`); set intra-op threads
     to `min(4, Platform.numberOfProcessors)`;
   - inspect `session.inputNames`: feed `input_ids` and `attention_mask` (int64, shape `[batch, seqLen]`), plus `token_type_ids` (all zeros) **only if present**;
   - batch size 8, pad to the longest sequence in the batch with `<pad>` = 1 and mask 0; max length 512;
   - output `last_hidden_state` `[batch, seqLen, 384]` → `meanPool` with the mask → `l2NormaliseInPlace`;
   - release all `OrtValue`s after each run (`release()`), and the session in `dispose()`;
   - `minUsefulScore` starts at `0.78` (tuned in 08.18).
4. On Android, ONNX Runtime ships native libraries per ABI; confirm `flutter build apk --release --split-per-abi` still builds and measure the arm64 APK
   size; record it in `PROGRESS.md`. If the arm64 APK exceeds 40 MB, write it down — Phase 9 handles size, but report it to the human now.

**Tests:** download service with a fake HTTP server (`HttpServer.bind` on port 0 serving a small file): `downloads and verifies`, `resumes from part file`,
`rejects wrong hash`, `delete removes files`. Integration test (Windows, requires the model in `<appSupportDir>` or `packages/tephra_ai/test/fixtures/model/`):
`embeds query and passage with 384 dims`, `cosine of a paraphrase pair > unrelated pair` (pairs: "How do I bake bread?" vs "passage: Bread recipe: flour,
water, yeast" and vs "passage: The stock market fell today"; plus one Bangla pair), `batch of 20 under 2 s on Windows`.

**Verify:** app tests for `ai/models`; `Push-Location app; flutter test integration_test/onnx_e5_test.dart -d windows; Pop-Location`;
then on the Android phone `flutter test integration_test/onnx_e5_test.dart -d <device-id>` (model downloaded through the UI first) and record timings.

**Pitfalls:** never bundle the model in assets. If the `onnxruntime` plugin fails to build on the current Flutter, stop and tell the human (options: fork
and patch the plugin, or another MIT/Apache ONNX binding); do not switch to a non-permissive package.

---

### 08.16 App: embedding worker isolate and semantic service

**Purpose:** run indexing and vector search off the UI isolate (D8) and keep it up to date.

**Files:**
- `app/lib/ai/semantic/embedding_worker.dart` (isolate entry + message types)
- `app/lib/ai/semantic/semantic_service.dart`, `semantic_status.dart`, `providers.dart`
- `app/lib/ai/semantic/semantic_status_tile.dart` (settings + status bar item)
- tests: `app/test/ai/semantic/semantic_service_test.dart`

**Implementation:**
1. Worker messages (sealed classes, sent over `SendPort`; the worker is spawned with `Isolate.spawn` in the same isolate group, so plain Dart objects can be sent):
   `WorkerInit(vectorDbPath, modelSpec | voyageConfig, RootIsolateToken token)`, `WorkerUpsert(path, noteHash, text)`, `WorkerRemove(path)`,
   `WorkerPlan(Map<String,String> hashes)`, `WorkerSearch(requestId, query, k, excludePaths)`, `WorkerRelated(requestId, path, k)`, `WorkerShutdown`;
   replies `WorkerReady`, `WorkerPlanResult`, `WorkerProgress(done, total)`, `WorkerSearchResult(requestId, hits)`, `WorkerError(message)`.
   In the worker call `BackgroundIsolateBinaryMessenger.ensureInitialized(token)` first (needed if the ONNX plugin uses platform channels).
2. `SemanticService` (main isolate, one per open vault, created by a provider that depends on the vault session and `aiSettingsProvider`):
   - starts only when `semanticProvider != off` **and** (local model ready **or** Voyage enabled with key and consent);
   - `start()`: spawn worker → `WorkerPlan(index note hashes)` where hashes come from `NoteIndex.allNotes()` (`NoteSummary` content hash; if the summary has
     no hash, compute `contentHash` from the file bytes) excluding `.tephraenc` and excluded folders → for each path in `toEmbed`, read text via
     `VaultFileSystem.readText` and send `WorkerUpsert` (at most 4 in flight); send `WorkerRemove` for `toRemove`;
   - listens to `NoteIndex.changes` (`IndexEvent.changedPaths`; on `fullRebuild` it re-runs the plan) and re-sends changed notes,
     debounced 2 s per path;
   - pauses sending work when the app is in the background on Android (`AppLifecycleState.paused`) and resumes on `resumed`;
   - `search`, `related` return `Future<List<SemanticHit>>`;
   - unloads the ONNX session after 2 minutes without work (worker message `WorkerIdle` handled inside the worker) and reloads on demand;
   - exposes `Stream<SemanticStatus>` (off, needsModel, indexing(done,total), ready(chunkCount), error(message)).
3. Status: a status-bar item on desktop layout ("Semantic index 3,210/10,000") and a line in Settings → AI → Semantic search on both layouts.
4. Voyage consent dialog (shown when the user selects Voyage): "Indexing sends the text of every note (except encrypted notes) to Voyage AI.
   About N chunks will be sent." with **Send and enable** / **Cancel**.

**Tests:** service with a fake worker (inject a `WorkerLauncher` interface; the fake runs in the same isolate): `sends upserts for planned paths`,
`does not start when provider off`, `skips tephraenc files`, `debounces repeated changes`, `pauses on app paused`.

**Verify:** app tests for `ai/semantic`; manual on Windows with the 10k bench vault (`dart run tool/gen_bench_vault.dart` if not present):
download the model, watch indexing progress while typing in a note (UI must stay smooth). Record the total indexing time (budget: Windows < 15 min,
Android < 90 min for 10k notes; record both).

**Pitfalls:** the worker must never touch the drift index database. Kill the worker on vault close (`WorkerShutdown`, then `Isolate.kill` after 2 s).

---

### 08.17 Related notes panel

**Purpose:** show notes similar in meaning to the current note.

**Files:** `app/lib/ai/related/related_notes_panel.dart`, `related_notes_provider.dart`; register the panel in the right sidebar (desktop) and the
phone drawer like the Phase 2 backlinks panel; test `app/test/ai/related/related_notes_panel_test.dart`.

**Implementation:**
1. `relatedNotesProvider.family(VaultPath)` → `semanticService.related(path, k: 10)`; refresh when the active note changes or its index entry changes (debounce 1 s).
2. Each row: note title, best heading, a small similarity bar (score mapped from `minUsefulScore..1.0` to 0–100 %), and a "linked" badge if the current
   note already links to it (from `NoteIndex.outgoing`). Tap opens the note at the heading; long-press / right-click: "Insert link here" (inserts `[[Title]]`
   at the cursor).
3. Empty states: semantic off → "Turn on semantic search in Settings → AI"; model missing → "Download the model"; indexing → progress text; none found → "No related notes yet".
4. Command `ai.show-related-notes` opens the panel.

**Tests:** `shows rows from provider`, `shows linked badge`, `empty state when semantic off`, `insert link inserts wikilink`.

**Verify:** app tests for `ai/related`; manual on both platforms in the bench vault.

**Pitfalls:** never call the worker on every keystroke; only on note switch or index change.

---

### 08.18 Semantic mode in the search panel

**Purpose:** search by meaning, offline.

**Files:** modify the Phase 2 search panel (`app/lib/search/…`); add `app/lib/search/semantic_results_view.dart`; tests `app/test/search/semantic_mode_test.dart`.

**Implementation:**
1. A toggle chip **"Meaning"** next to the search field (also command `search.toggle-semantic-mode`). Off by default; remembered per device.
2. In semantic mode: the query is passed as plain text to `semanticService.search(query, k: 50)`; hits are grouped by note (best chunk per note);
   each result shows the note title, heading and the first 200 characters of the chunk text (read from the note via offsets; if the note's hash changed,
   show the heading only). Search operators are not interpreted; if the query contains `:` operators or quotes, show the hint "Operators are ignored in Meaning mode."
3. Results appear after 300 ms debounce. A model/indexing state replaces the list with the same empty states as 08.17.
4. Tune `minUsefulScore`: run 20 queries on the bench vault and on `test_vaults/real` (10 English, 5 Bangla, 5 paraphrases of note titles), note the scores
   of clearly relevant and clearly irrelevant results, and set `minUsefulScore` midway (keep it a constant in `onnx_e5_embedder.dart`). Record the table in
   `docs/decisions/semantic-threshold.md`.
5. Works offline: no network is used in local mode (verify in 08.23 with networking disabled).

**Tests:** `toggle switches to semantic results`, `operator hint shown`, `groups hits by note`, `debounces input`.

**Verify:** app tests for `search`; manual: airplane mode on the phone, Meaning search returns results. Budget: semantic query on 10k notes
< 200 ms Windows, < 500 ms Android (from keystroke-debounce end to results, model already loaded); record numbers.

**Pitfalls:** do not mix FTS and semantic results in this panel (hybrid is only for Ask your vault).

---

### 08.19 Retriever, citations and the Ask-your-vault service

**Purpose:** retrieval-augmented answers that always cite notes.

**Files:**
- `packages/tephra_ai/lib/src/rag/retriever.dart`, `retrieved_source.dart`, `citation.dart`, `citation_parser.dart`, `ask_vault_service.dart`
- tests: `test/rag/retriever_test.dart`, `citation_parser_test.dart`, `ask_vault_service_test.dart`

**Implementation:**
1. `RetrievedSource { int number; VaultPath path; String heading; String text; String cite; double score; }`.
   `cite` = `[[<target>#<heading>]]` where `<target>` = note stem if the stem is unique in the vault, otherwise the path without `.md`; `<heading>` = last
   heading in the path with the characters `# | [ ] ^` replaced by spaces; no heading → `[[<target>]]`.
2. `Retriever` (pure Dart; the app supplies callbacks so the package does not depend on the vault):
   ```dart
   Retriever({
     required Future<List<SemanticHit>> Function(String q, int k)? semanticSearch,   // null when semantic is off
     required Future<List<FtsHit>> Function(String ftsQuery, int limit) fullText,     // NoteIndex.fullText
     required Future<String?> Function(VaultPath path) readNoteText,                   // null if missing or encrypted
     required bool Function(String stem) isStemUnique,
     int k = 8, int maxCharsTotal = 24000, int maxPerNote = 2,
   });
   Future<List<RetrievedSource>> retrieve(String question);
   ```
   Algorithm: (a) semantic top 30 hits; (b) FTS: words of the question with ≥ 3 letters (Unicode), at most 12, each wrapped in double quotes, joined with
   ` OR `, `limit 30`; for each FTS note pick its chunk (re-chunk the note text with `NoteChunker`) containing the most query words;
   (c) reciprocal rank fusion: `score = Σ 1 / (60 + rank)` over both lists (rank starts at 1); (d) sort, keep at most `maxPerNote` per note, stop at `k` sources
   or when total text would exceed `maxCharsTotal`; (e) number sources 1..n. If both lists are empty, return `[]`.
3. `CitationParser.parse(String answer) → List<Citation>` with regex `\[\[([^\[\]|#^]+)(?:#([^\[\]|]+))?(?:\|[^\[\]]*)?\]\]`;
   `validate(List<Citation>, List<RetrievedSource>)` marks each citation valid when target and heading (case-insensitive, trimmed, inner whitespace collapsed)
   equal a source's cite parts.
4. `AskVaultService`:
   ```dart
   Stream<AskEvent> ask(String question, {required Stream<LlmEvent> Function(LlmRequest) send, required String modelId, LlmEffort? effort});
   sealed class AskEvent {}  // AskSources(List<RetrievedSource>), AskDelta(String), AskReplaced(String fullText), AskDone(AskResult)
   final class AskResult { final String answer; final List<Citation> citations; final bool hasValidCitation; final bool notFound; final LlmUsage usage; }
   ```
   Flow: retrieve → if no sources, `AskDone(answer: "I could not find anything related in your notes.", notFound: true)` without calling Claude → else render the
   `ask-vault` template (sources formatted per 08.6) → stream deltas → at the end parse and validate citations.
   **Citation rule:** if the answer is not exactly the not-found sentence and has **zero valid citations**, send one follow-up with `ask-vault-cite-retry`
   (same sources, the previous answer) and replace the text (`AskReplaced`). If the retry still has zero valid citations, finish with `hasValidCitation: false`
   (UI shows a warning banner). Usage of both requests is summed.

**Tests:** retriever: `fuses semantic and fts ranks`, `respects maxPerNote and maxCharsTotal`, `works with semantic null`, `cite uses path when stem not unique`,
`sanitises heading characters`; citations: `parses target and heading`, `ignores alias part`, `validates case-insensitively`, `invalid citation flagged`;
service (fake send): `no sources returns not found without calling send`, `valid citations finish normally`, `zero citations triggers exactly one retry`,
`retry still uncited sets hasValidCitation false`, `usage summed over retry`.

**Verify:** package tests for `tephra_ai`.

**Pitfalls:** never pass encrypted note text (the app's `readNoteText` returns null for `.tephraenc`).

---

### 08.20 Ask-your-vault panel

**Purpose:** the assistant panel UI.

**Files:** `app/lib/ai/ask/ask_vault_panel.dart`, `ask_vault_controller.dart`, `ask_sources_list.dart`, `providers.dart`;
tests `app/test/ai/ask/ask_vault_controller_test.dart`, `ask_vault_panel_test.dart`.

**Implementation:**
1. Panel location: right sidebar tab "Assistant" on desktop layout; full-screen page from the phone drawer/toolbar. Command `ai.ask-vault` (default shortcut
   `Ctrl+Shift+A`) focuses its input.
2. Controller (`AsyncNotifier`): holds the conversation of this session (questions + answers in memory only; cleared on vault close; nothing written to disk).
   Each question is answered independently (no multi-turn context in this phase — simpler and cheaper; say so in the UI hint "Each question is answered from
   your notes on its own").
3. Before sending: retrieval runs first, then the gateway preview lists the sources (label "<note> › <heading>", snippet) plus the question.
4. Answer view: streaming Markdown through the reading renderer; wikilink citations are tappable (open note, scroll to heading); invalid citations render with a
   warning colour and tooltip "Not one of the sources"; banner when `hasValidCitation == false`: "This answer doesn't cite your notes. Treat it with care."
5. Sources list under each answer: numbered, title › heading, snippet, tap to open. A usage chip shows tokens and estimated cost.
6. Buttons: **Stop** while streaming; **Copy answer**; **Insert into note** (inserts the answer at the cursor of the last active editor, citations kept as wikilinks).

**Tests:** `question flows through retrieval then gateway` (fakes), `stop cancels`, `invalid citation styled`, `banner shown when uncited`, `sources list opens note`.

**Verify:** app tests for `ai/ask`; manual on both platforms with the real API key on `test_vaults/real`: ask 5 questions whose answers are in the vault and 2 that are not;
every in-vault answer has ≥ 1 valid citation, the 2 others reply "I could not find this in your notes." Record the 7 questions and results in `PROGRESS.md`.

**Pitfalls:** keep the panel usable while semantic indexing is still running (FTS-only retrieval works).

---

### 08.21 Suggest tags and links

**Purpose:** AI suggestions the user accepts one by one.

**Files:** `packages/tephra_ai/lib/src/features/suggestions.dart`; `app/lib/ai/suggest/suggestions_sheet.dart`, `suggestions_controller.dart`;
tests `packages/tephra_ai/test/features/suggestions_test.dart`, `app/test/ai/suggest/suggestions_controller_test.dart`.

**Implementation:**
1. `parseJsonObject(String reply) → Map<String, Object?>`: take the substring from the first `{` to the last `}`; `jsonDecode`; throw `AiInvalidReplyException`
   (new `AiException` subclass) on failure.
2. Tags: input = note text (first 12,000 characters, frontmatter included) + up to 300 existing vault tags by count (`NoteIndex.tags()`), formatted
   `#tag (count)` one per line. Reply `{"tags":[…]}` → normalise (strip `#`, trim), keep only valid tags per the Phase 1 tag rules, drop tags the note already has,
   max 10.
3. Links: candidates = up to 50 note titles: `semanticService.related(path, k: 50)` if available, otherwise notes sharing the most tags; reply
   `{"links":[{"phrase":"…","target":"…"}]}` → keep only when `phrase` occurs in the note body outside code, links and frontmatter, and `target` is a candidate.
   Max 15.
4. UI: command `ai.suggest-tags-links` opens a sheet with two sections; each suggestion has ✓ (accept) and ✕ (dismiss).
   - Accepting a tag adds it to frontmatter `tags` via `yaml_edit` (create the frontmatter block if the note has none; if `tags` is a string, convert it to a list
     keeping the existing value first).
   - Accepting a link replaces the **first** matching occurrence of the phrase with `[[Target]]` when the phrase equals the target title case-insensitively,
     otherwise `[[Target|phrase]]`. Each acceptance is one undoable edit (applied through the open editor if the note is open, otherwise via an atomic file write).

**Tests:** `parses json with surrounding text`, `rejects invalid tag`, `drops existing tags`, `link phrase must exist outside code`, `accept tag creates frontmatter`,
`accept tag converts string tags to list`, `accept link uses alias when phrase differs`.

**Verify:** package + app tests; manual on both platforms.

**Pitfalls:** nothing is changed until the user presses ✓ on that specific suggestion.

---

### 08.22 Generate flashcards from a note

**Purpose:** create review cards in Format F4.

**Files:** `packages/tephra_ai/lib/src/features/flashcard_generator.dart`; `app/lib/ai/flashcards/generate_flashcards_sheet.dart`;
tests `packages/tephra_ai/test/features/flashcard_generator_test.dart`, `app/test/ai/flashcards/generate_flashcards_sheet_test.dart`.

**Implementation:**
1. Input: the note text (first 20,000 characters), `maxCards` = 15. Reply `{"cards":[{"q":"…","a":"…"}]}`; drop empty or duplicate questions.
2. `String formatCards(List<GeneratedCard> cards)`: single-line `q :: a` when both are single-line and neither contains ` :: `; otherwise multi-line form
   (`q` lines, `?`, `a` lines) followed by a blank line.
3. UI (command `ai.generate-flashcards`): list with a checkbox per card (all checked), editable text fields; **Add N cards** appends to the end of the note:
   a blank line, `## Flashcards` (only if the note has no heading named exactly "Flashcards"; otherwise append under the existing one at its end), the cards;
   and ensures the note has tag `flashcards` in frontmatter (`yaml_edit`, as in 08.21). One undoable edit.

**Tests:** `formats single-line cards`, `uses multi-line form when answer has newlines`, `avoids :: inside text`, `appends under existing Flashcards heading`,
`adds flashcards tag`.

**Verify:** package + app tests; manual: generate cards from a note, then (after 8b) they appear in the review screen.

**Pitfalls:** the cards must parse back with the 8b parser — add a test in 08.34 that round-trips `formatCards` output.

---

### 08.23 Block 8a check

**Purpose:** prove the 8a exit criteria.

**Files:** `PROGRESS.md` (results), `docs/decisions/semantic-threshold.md` (from 08.18).

**Implementation / checks:**
1. Offline semantic search: phone in airplane mode and Windows with Wi-Fi off — Meaning search and Related notes work; any AI action shows the network error message.
2. Citations: the 7-question test from 08.20 passes on both platforms.
3. Privacy: with "Always confirm" on, every AI action shows the preview; turning AI off makes all AI commands unavailable; grep the app log file for the API key
   and for a sentence from a sent note — 0 matches (`Select-String -Path <log> -Pattern <first 12 chars of key>`).
4. Phase 2 budgets with semantic indexing finished and the model unloaded (cold start, typing latency, search, quick switcher, memory) — record numbers.
   Memory while the model is loaded may be up to 200 MB above budget; it must fall back under budget within 3 minutes of idle (record).
5. APK arm64 size recorded.

**Tests:** run all package and app tests.

**Verify:** all checks recorded in `PROGRESS.md` under "Block 8a check".

**Pitfalls:** if a budget is missed by > 25 %, stop and tell the human (GEMINI §5).

---

## Block 8b — Productivity (weeks 3–4)

### 08.24 Tasks metadata parser

**Purpose:** parse Format F2 from task text.

**Files:** `packages/tephra_markdown/lib/src/tasks/civil_date.dart`, `task_metadata.dart`, `task_metadata_parser.dart`, `recurrence_rule.dart`;
export from `lib/tephra_markdown.dart`; tests `test/tasks/task_metadata_parser_test.dart`, `test/tasks/civil_date_test.dart`.

**Implementation:**
1. `CivilDate` (date without time zone): `const CivilDate(int year, int month, int day)`, `static CivilDate? tryParse(String yyyyMmDd)` (rejects invalid
   calendar dates), `CivilDate addDays(int n)`, `CivilDate addMonths(int n)` (clamps the day), `int daysUntil(CivilDate other)`, `compareTo`,
   `toString()` → `YYYY-MM-DD`, `static CivilDate fromDateTime(DateTime local)`. Implement via `DateTime.utc(y, m, d)` arithmetic to avoid DST problems.
   (If Phase 1–7 already created an equivalent date-only type in `tephra_core` or `tephra_markdown`, use it instead and note it.)
2. `enum TaskPriority { highest, high, medium, none, low, lowest }` (this order = sort order).
3. `TaskMetadata { String description; TaskPriority priority; CivilDate? start, created, scheduled, due, done, cancelled; String? recurrence;
   String? blockId; int metadataStart; }` (immutable, value equality).
4. `TaskMetadataParser.parse(String taskText) → TaskMetadata` exactly per F2 (regexes as `static final` fields with `unicode: true`).
5. `RecurrenceRule.tryParse(String text) → RecurrenceRule?` for the F2 subset: fields `unit` (`day|week|month|year`), `every` (int), `whenDone` (bool);
   `CivilDate advance(CivilDate from)`.

**Tests:** one test per field (`parses due date`, `parses scheduled with hourglass variant ⌛`, `parses due with 📆 variant`, `parses all priorities`, `parses start`,
`parses created`, `parses done`, `parses cancelled`, `parses recurrence`), `fields in any order`, `variation selector FE0F accepted`, `trailing tags kept in description`,
`block id preserved`, `invalid date left in description`, `duplicate field keeps the last one`, `description with emoji in the middle is untouched`
(`Buy 📅 calendar for office 📅 2026-10-20` → description `Buy 📅 calendar for office`, due 2026-10-20), `metadataStart offset`, recurrence: `every day`,
`every 3 weeks when done`, `Every Month` (case), `every monday is unsupported` (returns null), `addMonths clamps Jan 31 to Feb 28 in 2027 and Feb 29 in 2028`.

**Verify:** package tests for `tephra_markdown`.

**Pitfalls:** emoji are surrogate pairs in UTF-16; build regexes with `unicode: true` and never index into the string by "character count".
The Phase 2 index already extracts `📅` into `TaskRecord.due`; leave that code as is (it must agree with this parser — add a test in `tephra_index` that both give the same due date for the fixture tasks).

---

### 08.25 Task edit service: toggle, done date, recurrence

**Purpose:** minimal, safe write-back of task changes (F2 write-back rules).

**Files:** `packages/tephra_markdown/lib/src/tasks/task_line_editor.dart` (pure text edits); `app/lib/tasks/task_edit_service.dart`, `app/lib/tasks/providers.dart`;
tests `packages/tephra_markdown/test/tasks/task_line_editor_test.dart`, `app/test/tasks/task_edit_service_test.dart`.

**Implementation:**
1. Pure function:
   ```dart
   final class TaskToggleResult { final List<String> newLines; final String? message; }
   TaskToggleResult toggleTaskLine(String line, {required CivilDate today, required bool addDoneDate});
   ```
   `newLines` is 1 line (no recurrence) or 2 lines (next occurrence first, then the completed line). The list-marker/indent prefix is matched with
   `^(\s*(?:[-*+]|\d+[.)])\s+\[)(.)(\]\s?)(.*)$`.
2. `TaskEditService` (app):
   ```dart
   final class TaskRef { const TaskRef({required this.path, required this.line, required this.expectedLineText}); final VaultPath path; final int line; final String expectedLineText; }
   Future<void> toggle(TaskRef ref);   // line is 0-based
   ```
   - If the note is open in an editor tab, apply the change through that editor as one undoable transaction (reuse the Phase 2 Live Preview checkbox-toggle path).
   - Otherwise: `readText` → split lines on `\n` → if `lines[line] != expectedLineText`, search for exactly one line equal to `expectedLineText`; none or several →
     throw `TaskStaleException` (UI: "This task changed. Refresh and try again.") → replace → `writeText` (atomic; BOM and line ending preserved by `TextDocument`).
   - Encrypted notes (8d) are never edited by this service.
3. Reading view, Live Preview and query results (08.31) call this service for checkbox taps. If older direct toggling code exists from Phase 1/2, route it through this service
   so there is one implementation (keep the old tests passing).

**Tests:** `complete adds done date`, `complete without done date when setting off`, `complete keeps block id last`, `uncomplete removes done date`,
`recurrence creates next line above with shifted dates`, `when done uses today`, `next occurrence drops block id and done`, `created set to today when present`,
`unsupported rule completes with message`, `cancelled task not toggled`, `ordered list marker kept`, service: `stale line found elsewhere`, `stale line ambiguous throws`,
`open editor gets one undo step`.

**Verify:** package tests for `tephra_markdown`; app tests for `tasks`; the Phase 1 round-trip suite still passes.

**Pitfalls:** never re-serialise the task from `TaskMetadata`; only splice text.

---

### 08.26 Tasks dashboard

**Purpose:** every task in the vault, filterable.

**Files:** `app/lib/tasks/tasks_dashboard_page.dart`, `tasks_query.dart`, `tasks_filter_bar.dart`, `task_tile.dart`; command `tasks.open-dashboard` (ribbon/drawer entry "Tasks");
tests `app/test/tasks/tasks_query_test.dart`, `tasks_dashboard_page_test.dart`; fixture `test_vaults/syntax/tasks-plugin.md`.

**Implementation:**
1. Data: `NoteIndex.tasks()` → parse each `TaskRecord.text` with `TaskMetadataParser` → `DashboardTask { TaskRecord record; TaskMetadata meta; }`.
   Refresh on `NoteIndex.changes` (debounced 500 ms). Parse in `Isolate.run` when there are more than 2,000 tasks.
2. Filters (chips, combinable; defaults **Open** + **All dates**):
   - status: Open (status `' '` or `/`), Done (`x`/`X`), All;
   - date: **Today** (due or scheduled == today), **Overdue** (open and due < today), **Upcoming** (due or scheduled in today+1 … today+14), **No date** (no start,
     scheduled or due), All dates;
   - tag: picker from tags in task descriptions plus the containing note's tags;
   - path: folder picker (task's note inside the folder);
   - text box (case-insensitive substring of the description).
3. Grouping: by date bucket (Overdue, Today, Upcoming by day, No date, Done) — default; alternative "By note". Sort inside a group: priority, due, path, line.
4. Tile: checkbox (`TaskEditService.toggle`), description as inline Markdown, priority icon, chips for 📅 ⏳ 🛫 🔁, note name; tap opens the note at the task line.
5. Phone: list with a horizontally scrolling filter row; desktop: filter column left of the list.
6. Fixture `test_vaults/syntax/tasks-plugin.md`: 20 tasks covering every F2 field and three recurrences. If `test_vaults/syntax` is generated by `tool/gen_test_vaults.dart`
   (Phase 0), add the note to that generator instead of writing the file by hand, then regenerate.

**Tests:** `today filter matches due or scheduled today`, `overdue excludes done`, `upcoming window 14 days`, `no date filter`, `tag filter`, `path filter`, `group order`,
widget: `tapping checkbox calls edit service`.

**Verify:** app tests for `tasks`; manual on both platforms. Budget: 10,000 tasks load in < 300 ms Windows / < 800 ms Android (record).

**Pitfalls:** clock injection — "today" comes from the app `Clock` provider so tests are deterministic.

---

### 08.27 Task reminders

**Purpose:** due-date notifications through the Phase 4 `NotificationService`.

**Files:** `app/lib/tasks/task_reminder_scheduler.dart`; settings entries in the Tasks section; tests `app/test/tasks/task_reminder_scheduler_test.dart`.

**Implementation:**
1. Settings: "Due-date reminders" (default **off**), "Reminder time" (default 09:00), "Add done date when completing" (default on, used by 08.25).
   Enabling calls `requestNotificationPermission()` and `requestExactAlarmPermission()`; if either is denied the switch returns to off with an explanation.
2. Scheduler (on enable, app start, and `NoteIndex.changes` debounced 10 s): open tasks with a due date in [today, today + 14] whose reminder instant
   (due date at reminder time, local) is in the future; earliest 64; for each `ScheduledReminder(id: taskReminderId, at: instant.toUtc(), title: <l10n "Task due">,
   body: description (max 120 chars), payload: 'task:<path>:<line>')`. Cancel ids no longer in the set (last set persisted in `<appSupportDir>/task_reminders.json`).
3. `taskReminderId` = (first 30 bits of SHA-256 of `'task|' + path + '|' + lineText`) | `0x40000000` — bit 30 set so task ids never collide with Phase 4 sticky ids
   (check the Phase 4 id scheme; if it already sets bit 30, use bit 29 and note it).
4. Notification tap (`taps` / `launchPayload`) with a `task:` payload opens the note at the line.

**Tests:** `schedules due tasks at reminder time`, `skips done tasks`, `caps at 64 earliest`, `cancels removed tasks`, `ids are stable and have bit 30`, `nothing when disabled`.

**Verify:** app tests; manual: Android with the app killed — a task due today with reminder time 2 minutes ahead fires; same on Windows (toast).

**Pitfalls:** convert local times to UTC only at the end (DST).

---

### 08.28 DQL lexer and parser

**Purpose:** parse Format F1.

**Files:** `packages/tephra_search/lib/src/query/dql_token.dart`, `dql_lexer.dart`, `dql_ast.dart`, `dql_parser.dart`, `dql_syntax_exception.dart`;
export `DqlParser`, `DqlQuery`, `DqlSyntaxException` from `lib/tephra_search.dart`; tests `test/query/dql_lexer_test.dart`, `dql_parser_test.dart`.

**Implementation:**
1. `DqlSyntaxException extends ParseException` with `line`, `column` (1-based).
2. Tokens: statement keywords (case-insensitive, whole words): `LIST TABLE TASK WITHOUT ID FROM WHERE SORT GROUP BY LIMIT AS ASC ASCENDING DESC DESCENDING AND OR`;
   expression operators `= != < <= > >= + - * / % ! && || ( ) [ ] , .`; `and`/`or` in any case inside expressions are operators; `[[…]]` link literal (one token);
   `#tag` (only valid in FROM); strings `"…"`; numbers; identifiers (R3, R4); `true false null`.
3. AST:
   ```dart
   enum DqlKind { list, table, task }
   final class DqlQuery { final DqlKind kind; final bool withoutId; final List<DqlColumn> columns; final DqlSource? from; final List<DqlCommand> commands; }
   final class DqlColumn { final DqlExpr expr; final String? alias; final String sourceText; }
   sealed class DqlSource {}   // DqlTagSource(tag), DqlFolderSource(path), DqlLinkSource(target), DqlNotSource(inner), DqlAndSource(l, r), DqlOrSource(l, r)
   sealed class DqlCommand {}  // DqlWhere(expr), DqlSort(List<DqlSortKey>), DqlGroupBy(expr, keyName), DqlLimit(n)
   sealed class DqlExpr {}     // DqlNum, DqlStr, DqlBool, DqlNull, DqlIdent(name), DqlMember(target, name), DqlIndex(target, index),
                               // DqlCall(name, args), DqlUnary(op, x), DqlBinary(op, l, r), DqlListLit(items), DqlLinkLit(target)
   ```
   Every node keeps its source range (column titles and error positions).
4. Recursive descent per the EBNF precedence. In `LIST <expr>` and `TABLE` columns, the expression ends at the next top-level statement keyword. Enforce R1, R2, R5.

**Tests:** `LIST minimal`, `LIST WITHOUT ID expression`, `TABLE with AS aliases`, `TASK`, `FROM tag and folder with AND OR and negation`, `FROM link`, `parenthesised sources`,
`WHERE precedence and or not`, `SORT multiple keys`, `GROUP BY with AS`, `LIMIT`, `commands keep written order`, `keywords case-insensitive`,
`hyphenated identifier vs subtraction`, `Bangla identifier`, errors: `missing header`, `two FROM`, `two GROUP BY`, `unterminated string reports line and column`, `trailing garbage`.

**Verify:** package tests for `tephra_search`.

**Pitfalls:** in `FROM "a" AND -#b` the `-` is source negation, not subtraction.

---

### 08.29 Query dataset: note rows and task rows

**Purpose:** the rows a query runs over, reusing the Phase 6 Bases dataset.

**Files:** `packages/tephra_search/lib/src/query/query_dataset.dart`; `app/lib/query/query_data_provider.dart` (new feature folder `app/lib/query/`);
tests `packages/tephra_search/test/query/query_dataset_test.dart`.

**Implementation:**
1. `QueryDataset { BaseDataset base; List<QueryTask> tasks; }` (sendable). `QueryTask { VaultPath path; int line; String statusChar; String rawLine; TaskMetadata meta; }`
   built from `NoteIndex.tasks()` + `TaskMetadataParser` (`tephra_search` may import `tephra_markdown`, §3). `rawLine` is the full source line (read from the
   note text using `TaskRecord.start/end` line range when building, in the isolate) — it is the `expectedLineText` for toggles.
2. `QueryDataProvider` (app) reuses the dataset built by the Phase 6 `BaseDataProvider` (do not query the index twice), adds the task list, caches per vault and is invalidated
   together with it.
3. Row contexts:
   - note row → the Phase 6 `BaseRowContext` for that `FileRef`;
   - task row → a `BaseRowContext` whose `file` is the containing note and whose `properties` map is
     `{text, status, completed, checked, line (1-based), path, tags, due, scheduled, start, completion, created, cancelled, priority, recurrence}`
     (dates as `YYYY-MM-DD` strings, typed as `date` in the row's `propertyTypes` so Bases converts them to `BDate`).
   Only Markdown notes are note rows; `.tephraenc` files never appear.

**Tests:** `builds task rows with metadata`, `task dates are BDate in evaluation`, `excludes non-markdown files from note rows`, `rawLine equals the source line`.

**Verify:** package tests for `tephra_search`.

**Pitfalls:** keep everything sendable (no closures, no `RegExp` objects).

---

### 08.30 DQL compiler and executor

**Purpose:** run a parsed query by compiling it to Bases expressions.

**Files:** `packages/tephra_search/lib/src/query/dql_compiler.dart`, `dql_executor.dart`, `dql_result.dart`; tests `test/query/dql_compiler_test.dart`, `dql_executor_test.dart`.

**Implementation:**
1. Name mapping (rewrite `DqlIdent`/`DqlMember` chains to Bases AST):
   | DQL | Bases |
   |---|---|
   | `file.name` | the stem field of Bases `file` (Bases `file.name` includes the extension — use `file.basename`; check 06.17's FileRef field list) |
   | `file.path`, `file.folder`, `file.ext`, `file.size`, `file.ctime`, `file.mtime`, `file.tags` | same name on `file` |
   | `file.cday` / `file.mday` | `file.ctime.date()` / `file.mtime.date()` |
   | `file.etags` | `file.tags` (documented deviation) |
   | `file.aliases` | `note.aliases` |
   | `file.link` | `file.asLink()` |
   | `file.inlinks` / `file.outlinks` | `file.backlinks` / `file.links` |
   | `file.tasks` | special identifier resolved by the executor to the list of that note's task objects |
   | `file.day` | date from the file name (`\d{4}-\d{2}-\d{2}`), else `note.date` |
   | any other identifier | Bases identifier resolution (note property) |
2. Operators/functions: `=` → `==`; `and`/`or` → `&&`/`||`; `contains(a,b)` → `a.contains(b)`; `icontains(a,b)` → lower-cased contains (element-wise for lists);
   `length(x)` → `x.length`; `lower(s)` → `s.lower()`; `upper(s)` → `s.upper()` (add `upper()` to the Bases string methods with a test if 06.17 lacks it);
   `startswith`/`endswith` → `startsWith`/`endsWith`; `regexmatch(p, s)` → whole-string match; `date(today|now|tomorrow|yesterday|x)` → `today()`, `now()`,
   `today() + "1d"`, `today() - "1d"`, `date(x)`; `dur(s)` → `duration(s)`; `number(x)` → `number(x)`; `string(x)` → `x.toString()`; `default(x, y)` → `if(x == null, y, x)`;
   `choice(c, a, b)` → `if(c, a, b)`; `round(n, d)` → `n.round(d)`; `link(p)` → `link(p)`; `min`/`max` → same; `join(l, s)` → `l.join(s)` (default `", "`);
   `sum(l)` → executor helper.
3. `DqlResult runDql(DqlQuery q, QueryDataset data, {required VaultPath thisPath, required DateTime now})`: rows = note rows (LIST/TABLE) or task rows (TASK) → FROM
   (tags via `file.hasTag`, folders via `file.inFolder` or exact path with/without `.md`, links via backlinks of the resolved target, negation, and/or) → data commands in
   written order (WHERE keep truthy; SORT Bases comparator; GROUP BY partition by `displayValue(key)`; LIMIT) → `DqlResult { DqlKind kind; List<String> headers;
   List<DqlRow> rows; List<DqlGroup> groups; int total; List<String> errors; }` (sendable; `BRegex` → string).
4. Run in `Isolate.run` when the dataset has more than 1,000 notes.

**Tests (hand-built dataset: 15 notes, 20 tasks):** `LIST FROM tag includes nested tags`, `LIST FROM folder`, `FROM link returns backlinks`, `negated source`,
`TABLE headers use AS`, `WITHOUT ID removes file column`, `WHERE on frontmatter number`, `WHERE date(today) comparison`, `SORT desc then asc`, `GROUP BY status`,
`LIMIT after sort`, `written order matters` (LIMIT before SORT differs), `TASK WHERE !completed and due <= date(today)`, `file.name maps to stem`,
`contains on list property`, `unknown function gives cell error`, bench `10k notes simple WHERE` (tag `bench`; budget < 300 ms Windows, record Android).

**Verify:** package tests for `tephra_search`; bench recorded.

**Pitfalls:** if a Bases function needed by the mapping is missing, add it to the Bases library (with a test) instead of special-casing it here.

---

### 08.31 Query block rendering

**Purpose:** render ` ```tephra-query ` and ` ```dataview ` blocks in reading view and Live Preview, live-updating.

**Files:** `app/lib/query/query_block_widget.dart`, `query_result_table.dart`, `query_result_list.dart`, `query_result_tasks.dart`, `providers.dart`;
registration where Phase 2 registers the ` ```query ` block renderer; tests `app/test/query/query_block_widget_test.dart`; fixture `test_vaults/syntax/queries.md` (10 queries, one per feature).

**Implementation:**
1. `queryResultProvider.family((String source, VaultPath thisPath))`: parse (errors → error box) → dataset → run → `DqlResult`. Invalidated with the dataset, so visible
   blocks update live after edits.
2. Rendering per F1 "Rendering": table with horizontal scroll and header row; lists; task groups; group sections; 1,000-row cap.
3. TASK checkboxes call `TaskEditService.toggle(TaskRef(path, line - 1, rawLine))`.
4. Live Preview: widget when the cursor is outside the block, source when inside (same mechanism as other special blocks).
5. Footer: "N results · updated HH:mm" and a refresh button; progress indicator while running.

**Tests:** `renders table headers and rows`, `renders parse error with line and column`, `task checkbox calls service`, `updates when dataset changes`, `dataview fence rendered too`.

**Verify:** app tests for `query`; manual on both platforms with `queries.md`.

**Pitfalls:** never run a query synchronously on the UI isolate for large vaults.

---

### 08.32 Kanban parser and serializer

**Purpose:** Format F3, lossless.

**Files:** `packages/tephra_markdown/lib/src/kanban/kanban_board.dart`, `kanban_parser.dart`, `kanban_serializer.dart`, `kanban_ops.dart`;
fixtures `packages/tephra_markdown/test/fixtures/kanban/` (at least 8: basic, multi-line cards, complete lane, archive, long settings JSON, extra paragraph inside a lane,
empty lanes, a board with text before the first lane); tests `test/kanban/kanban_roundtrip_test.dart`, `kanban_ops_test.dart`.

**Implementation:**
1. Model: `KanbanBoard { String preamble; List<KanbanLane> lanes; String? archive; String? settings; String trailer; bool isBoard; }`;
   `KanbanLane { String id; String title; bool completeLane; List<KanbanItem> items; String trailing; String? rawIfUnchanged; }`;
   `sealed class KanbanItem` → `KanbanCard { String id; String raw; String status; String title; }`, `LaneExtra { String raw; }`. `id`s are in-memory only.
2. `KanbanParser.parse` per F3 (text is already `\n`-normalised by `TextDocument`). `isBoard` from the frontmatter key.
3. `KanbanSerializer.write` per F3; untouched lanes from `rawIfUnchanged`.
4. Pure ops returning a new board: `moveCard(cardId, toLaneId, toIndex)`, `addCard(laneId, text)`, `editCardText(cardId, newFirstLineText)` (only the text after
   `- [c] ` on the first line), `toggleCard(cardId)`, `deleteCard(cardId)`, `addLane(title)`, `renameLane(laneId, title)`, `moveLane(laneId, toIndex)`,
   `deleteLane(laneId)` (only when empty).

**Tests:** `round-trip of every fixture is byte-identical`, `move card keeps raw text`, `move into complete lane checks card`, `move out unchecks`, `multi-line card moves as a unit`,
`settings untouched after edits`, `archive untouched`, `extra paragraph stays in place`, `new lane formatting`, `rename lane rewrites only the heading line`.

**Verify:** package tests for `tephra_markdown`.

**Pitfalls:** find the settings block by its first line `%% kanban:settings` and the next line that is exactly `%%` — the JSON may contain backticks.

---

### 08.33 Kanban board view

**Purpose:** drag-and-drop board UI that writes Markdown back.

**Files:** `app/lib/kanban/kanban_view.dart`, `kanban_lane_widget.dart`, `kanban_card_widget.dart`, `kanban_controller.dart`, `providers.dart`; commands `kanban.new-board`,
`kanban.toggle-markdown-view`; tests `app/test/kanban/kanban_controller_test.dart`, `kanban_view_test.dart`.

**Implementation:**
1. Opening a note with `kanban-plugin` frontmatter shows the board by default; `kanban.toggle-markdown-view` switches the tab to the editor and back.
2. Desktop: lanes 272 px wide in a horizontal scroll view. Phone: one lane per page (`PageView`) with lane tabs.
3. Drag and drop: `LongPressDraggable` for touch, `Draggable` for mouse; drop targets between cards and at lane ends; lanes reorder by dragging their header.
   Phone: holding a dragged card at the screen edge for 600 ms flips to the neighbouring lane.
4. Card: checkbox, first line as inline Markdown (links, tags, `@{date}` as a date chip), extra lines collapsed. Tap = inline edit of the first line; menu: Edit,
   Open linked note (when the card is a single `[[link]]`), Move to lane…, Delete.
5. "Add card" per lane, "Add lane" at the end.
6. Each change: op → serialise → save through the normal document save path (debounced 500 ms, atomic, round-trip rules). External changes reload the board keeping scroll position.
7. `kanban.new-board` creates `Untitled Kanban.md` (numbered if taken) in the new-note location from the plugin template captured in 08.36; until then from F3's example without cards.

**Tests:** `move card saves expected markdown`, `external change reloads`, `add card appends`, widget `drag card to another lane`, `phone shows one lane per page`.

**Verify:** app tests for `kanban`; manual on both platforms: 3 lanes, 6 cards, drag, close, reopen — intact.

**Pitfalls:** save on drop, not on every drag frame.

---

### 08.34 Flashcard parser, SM-2 and state store

**Purpose:** Format F4.

**Files:** `packages/tephra_markdown/lib/src/flashcards/flashcard.dart`, `flashcard_parser.dart`, `sm2.dart`, `card_state.dart`, `flashcard_store_codec.dart`;
`app/lib/flashcards/flashcard_store.dart`, `flashcard_collector.dart`, `providers.dart`; tests `packages/tephra_markdown/test/flashcards/`, `app/test/flashcards/flashcard_store_test.dart`.

**Implementation:**
1. `Flashcard { String id; VaultPath path; String deck; FlashcardKind kind; String question; String answer; int line; }` with `enum FlashcardKind { basic, cloze }`.
2. `FlashcardParser.parse(VaultPath path, ParsedNote note) → List<Flashcard>`; `[]` unless the note has a `flashcards` tag; uses AST ranges to skip code, inline code and comments.
3. `Sm2.review` per F4; `CardState` JSON per F4; `FlashcardStoreCodec` writes sorted keys, 2-space indent, `\n`.
4. `FlashcardStore` (app): loads `.tephra/flashcards.json` (missing → empty; corrupt → rename to `.tephra/flashcards.json.bad-<yyyyMMddHHmmss>`, start empty, log `warning`);
   `review(cardId, quality)`; debounced atomic save; handles renames/deletes per F4; merges sync conflict copies per F4.
5. `FlashcardCollector`: cards from notes tagged `flashcards` (index tag query + `readText` + parse) in `Isolate.run`; refresh on `NoteIndex.changes`.
6. Round-trip test promised in 08.22: `formatCards` output parses back to the same pairs.

**Tests:** `single-line card`, `inline field key:: value is not a card`, `multi-line card`, `cloze with two highlights gives two cards`, `cards in code blocks ignored`,
`note without flashcards tag has no cards`, `deck from nested tag`, `id stable when answer edited`, SM-2: `first good review interval 1`, `second good review interval 6`,
`third review interval rounds I x EF`, `again resets reps and keeps EF`, `EF never below 1.3`, `easy raises EF by 0.1`, store: `rename rewrites keys`, `delete marks orphaned`,
`orphan older than 30 days removed`, `conflict copy merged by lastReview`, `corrupt file backed up`, `generator output round-trips`.

**Verify:** package tests for `tephra_markdown`; app tests for `flashcards`.

**Pitfalls:** never write review data into notes.

---

### 08.35 Review screen and statistics

**Purpose:** study cards and see progress.

**Files:** `app/lib/flashcards/deck_list_page.dart`, `review_page.dart`, `review_session.dart`, `stats_page.dart`; commands `flashcards.open-decks`, `flashcards.review-all`;
tests `app/test/flashcards/review_session_test.dart`, `review_page_test.dart`.

**Implementation:**
1. Deck list: per deck New / Due / Total; "Review" per deck; "Review all".
2. Session: due cards (due ≤ today) in due order, then new cards up to "New cards per day" (setting, default 20, per deck per day).
3. Review page: question as Markdown; **Show answer** (Space); **Again (1)**, **Hard (2)**, **Good (3)**, **Easy (4)** (keys 1–4), each labelled with its next interval
   ("1d", "6d", "15d"); "Open note"; progress "12 / 30"; "Undo last" (one step).
4. Stats: counts (new; learning = reps < 2; mature = interval ≥ 21), reviews per day for 30 days (bar chart with `CustomPainter`, data in `.tephra/cache/flashcard-log.json`),
   due forecast for 14 days.

**Tests:** `due before new`, `new card cap per day`, `Good schedules per SM-2`, `undo restores previous state`, widget `space shows answer`, `key 3 rates good`.

**Verify:** app tests; manual on both platforms with a 10-card note.

**Pitfalls:** keyboard-only use on Windows; ≥ 48 dp buttons on phones.

---

### 08.36 Block 8b check (Obsidian plugin compatibility)

**Purpose:** prove that query, task and Kanban files written by Tephra work with the Dataview, Tasks, Kanban and Spaced Repetition plugins.

**Files:** `docs/compat/phase-08-obsidian-plugins.md`, `test_vaults/syntax/kanban/new-board-from-plugin.md`, `PROGRESS.md`.

**Implementation / checks (needs the human prerequisite "Obsidian desktop with plugins"):**
1. Copy `test_vaults/syntax/queries.md`, `tasks-plugin.md`, a Tephra-made board and a flashcards note into `D:\tmp\obsidian-compat`. In `queries.md` every query appears
   twice: once as ` ```tephra-query ` and once as ` ```dataview `.
2. Ask the human to create a new empty board with the Obsidian Kanban plugin and copy its file to `test_vaults/syntax/kanban/new-board-from-plugin.md`;
   make `kanban.new-board` produce exactly that text.
3. Write, in `docs/compat/phase-08-obsidian-plugins.md`, the rows Tephra shows for each of the 10 queries. Ask the human to compare with Dataview's output and to report:
   (a) query differences; (b) whether the Tephra board opens as a board in Obsidian, and whether a card moved in Obsidian still opens in Tephra; (c) whether Tasks shows the
   same due dates and completes `every week` the same way; (d) whether Spaced Repetition counts the same number of cards.
4. Fix every difference except documented unsupported features (inline fields, `file.etags`); document those.
5. Quick re-check of the Phase 2 budgets; record.

**Tests:** all package and app tests.

**Verify:** compat document filled; "Block 8b check" in `PROGRESS.md`.

**Pitfalls:** never write into `.obsidian/` of the compat vault.

---

## Block 8c — Media intelligence (weeks 5–6)

### 08.37 Attachment text in the index and in search

**Purpose:** make text found in images and PDFs searchable.

**Files:** `packages/tephra_index/lib/src/db/tables.dart` (or wherever Phase 2 put the drift tables), `fts.dart`, `index_database.dart`, `note_index.dart` (+ the worker request
types); `packages/tephra_search/lib/src/search_engine.dart` (attachment hits); tests `packages/tephra_index/test/attachment_text_test.dart`,
`packages/tephra_search/test/attachment_search_test.dart`.

**Implementation:**
1. New drift table:
   ```dart
   @DataClassName('AttachmentTextRow')
   class AttachmentText extends Table {
     IntColumn get id => integer().autoIncrement()();            // rowid for fts_attachments
     TextColumn get path => text().unique()();
     TextColumn get contentHash => text()();                      // hash of the attachment bytes the text came from
     TextColumn get engine => text()();                           // 'mlkit' | 'winocr' | 'pdf-text' | 'pdf-ocr'
     TextColumn get body => text()();
     DateTimeColumn get updated => dateTime()();
   }
   ```
   FTS: `CREATE VIRTUAL TABLE IF NOT EXISTS fts_attachments USING fts5(body, content='', contentless_delete=1, tokenize="unicode61 remove_diacritics 2 categories 'L* N* Co M*'")`
   (same tokenizer as `fts_words`). Bump `schemaVersion` to the next number (Phase 2 rule: a schema change rebuilds the index — acceptable because OCR text is
   re-supplied from the OCR cache, 08.40).
2. `NoteIndex` additions:
   ```dart
   Future<void> putAttachmentText(VaultPath path, String contentHash, String engine, String body);   // upsert row + FTS
   Future<void> removeAttachmentText(VaultPath path);
   Future<Map<VaultPath, String>> attachmentTextHashes();                                          // path → contentHash
   Future<List<AttachmentHit>> fullTextAttachments(String ftsQuery, {int limit = 100});            // AttachmentHit { VaultPath path; double rank; String snippet; }
   ```
   Deleting/moving an attachment (`onChange`) deletes/moves its row (move keeps the text). `snippet` = FTS5 `snippet()` is not available on contentless tables:
   compute it in Dart from `body` (first match ±60 characters).
3. Search engine: for queries that consist only of plain terms/phrases (no operators), also run `fullTextAttachments` and emit `SearchResult`s for attachments with a
   single match whose snippet comes from the attachment text; the result row shows an "In image"/"In PDF" badge. Setting "Include text in images and PDFs"
   (search settings, default on). Operators like `file:`/`path:` still apply to attachment paths; `tag:`, `task:`, `line:`, `section:`, `[prop]` exclude attachments.

**Tests:** `put and query attachment text`, `move keeps text`, `delete removes text`, `hashes map`, `Bangla text searchable`, search: `plain term finds image text`,
`operator query excludes attachments except file and path`, `setting off hides attachment hits`.

**Verify:** package tests for `tephra_index` and `tephra_search`; Phase 2 index fuzz test still passes.

**Pitfalls:** keep the FTS tokenizer identical to `fts_words` so search behaves the same for notes and attachments.

---

### 08.38 OCR interface and Android ML Kit engine

**Purpose:** OCR on Android.

**Files:** `app/lib/media/ocr/ocr_engine.dart` (interface + `NoopOcrEngine`), `ocr_result.dart`, `mlkit_ocr_engine.dart`, `providers.dart`;
`app/android/app/build.gradle.kts` (only if the plugin README requires changes); tests `app/test/media/ocr/ocr_engine_provider_test.dart`;
integration test `app/integration_test/ocr_android_test.dart`; fixture images `app/integration_test/assets/ocr/` (3 PNGs: printed English text, a receipt photo, a screenshot).

**Implementation:**
1. Interface (in `app/lib/core/platform/` style, conventions §5.9):
   ```dart
   abstract interface class OcrEngine {
     String get id;                                   // 'mlkit' | 'winocr' | 'none'
     Future<bool> isAvailable();
     Future<List<String>> languages();               // BCP-47 tags the engine can read now
     Future<OcrResult> recognizeFile(String absolutePath, {String? languageTag});   // throws OcrException
     Future<void> dispose();
   }
   final class OcrResult { final String text; final List<OcrLine> lines; }
   ```
   Provider picks `MlKitOcrEngine` on Android, `WinOcrEngine` (08.39) on Windows, `NoopOcrEngine` elsewhere (and when the human declined the ML Kit terms).
2. `MlKitOcrEngine`: `TextRecognizer(script: TextRecognitionScript.latin)` created once; `processImage(InputImage.fromFilePath(path))`; `text` = `RecognizedText.text`;
   `languages()` returns `['und-Latn']`; `close()` in `dispose`. Do **not** add the Chinese/Devanagari/Japanese/Korean model dependencies (APK size).
3. Images larger than 4,096 px on the longest side: downscale first to a temp PNG (use `dart:ui` `instantiateImageCodec` with `targetWidth`/`targetHeight`).

**Tests:** provider: `android picks mlkit`, `declined terms picks noop`; integration (Android device): `recognises printed English fixture` (contains "Tephra OCR test"),
`receipt fixture returns non-empty text`.

**Verify:** app tests; `Push-Location app; flutter test integration_test/ocr_android_test.dart -d <android-id>; Pop-Location`.

**Pitfalls:** document in the user guide (Phase 9) and in Settings → OCR: "Text recognition reads Latin-script text (English and other European languages). Bangla is not supported yet."

---

### 08.39 Windows OCR FFI plugin (`tephra_win_ocr`)

**Purpose:** OCR on Windows with `Windows.Media.Ocr`.

**Files:**
- `app/plugins/tephra_win_ocr/` created with `flutter create --template=plugin_ffi --platforms=windows --org com.tephra tephra_win_ocr` (run inside `app/plugins/`)
- `app/plugins/tephra_win_ocr/src/tephra_win_ocr.cpp`, `tephra_win_ocr.h`, `CMakeLists.txt`
- `app/plugins/tephra_win_ocr/lib/tephra_win_ocr.dart` (hand-written bindings)
- `app/lib/media/ocr/win_ocr_engine.dart`
- root `pubspec.yaml` (workspace member), `app/pubspec.yaml` (path dependency `tephra_win_ocr: {path: plugins/tephra_win_ocr}`)
- integration test `app/integration_test/ocr_windows_test.dart`

**Implementation:**
1. Check installed OCR languages first (record the output in `PROGRESS.md`):
   ```powershell
   Get-WindowsCapability -Online | Where-Object Name -like 'Language.OCR*' | Select-Object Name, State
   ```
   Confirm whether any `Language.OCR~~~bn-*` capability exists; if none, the Bangla limitation (D11) stands.
2. C API (`tephra_win_ocr.h`, `extern "C"`, `__declspec(dllexport)` via the template's `FFI_PLUGIN_EXPORT`):
   ```c
   // Returns 0 on success. *out_json is malloc'd UTF-8 JSON {"text":"...","lines":["..."]}; free with tephra_ocr_free.
   int32_t tephra_ocr_recognize_file(const wchar_t* path, const wchar_t* language_tag /* NULL = user profile languages */, char** out_json);
   // Returns 0 on success. *out_json = ["en-US","de-DE"] of AvailableRecognizerLanguages.
   int32_t tephra_ocr_languages(char** out_json);
   void tephra_ocr_free(char* p);
   ```
   Error codes: 1 = file not found/unreadable, 2 = decode failed, 3 = no OCR engine for the language, 4 = other (HRESULT logged to `OutputDebugStringW`).
3. Implementation with C++/WinRT (headers ship with the Windows SDK): include `<winrt/Windows.Foundation.h>`, `<winrt/Windows.Storage.h>`,
   `<winrt/Windows.Storage.Streams.h>`, `<winrt/Windows.Graphics.Imaging.h>`, `<winrt/Windows.Media.Ocr.h>`, `<winrt/Windows.Globalization.h>`.
   In each exported function: `winrt::init_apartment(winrt::apartment_type::multi_threaded)` inside `try` (ignore `RPC_E_CHANGED_MODE`); then
   `StorageFile::GetFileFromPathAsync(path).get()` → `OpenAsync(FileAccessMode::Read).get()` → `BitmapDecoder::CreateAsync(stream).get()`;
   if width or height > `OcrEngine::MaxImageDimension()`, use `BitmapTransform` with `ScaledWidth/ScaledHeight` keeping aspect ratio;
   `GetSoftwareBitmapAsync(BitmapPixelFormat::Bgra8, BitmapAlphaMode::Premultiplied, transform, ExifOrientationMode::RespectExifOrientation, ColorManagementMode::DoNotColorManage).get()`;
   engine = language tag ? `OcrEngine::TryCreateFromLanguage(Language(tag))` : `OcrEngine::TryCreateFromUserProfileLanguages()`; null → code 3;
   `engine.RecognizeAsync(bitmap).get()`; collect `result.Text()` and each `line.Text()`; convert to UTF-8 (`winrt::to_string`); escape JSON strings properly (quotes,
   backslashes, control characters). Catch `winrt::hresult_error` and `std::exception` → code 4. Never let an exception cross the C boundary.
4. `CMakeLists.txt`: C++17 (`target_compile_features(... cxx_std_17)`), `/EHsc`, `/permissive-`, link `WindowsApp.lib`. Build only on Windows (the template's
   Windows-only plugin already ensures this).
5. Dart bindings (`dart:ffi` + `package:ffi`): `DynamicLibrary.open('tephra_win_ocr.dll')`; `Utf16` for paths; free the returned string with `tephra_ocr_free`.
6. `WinOcrEngine.recognizeFile` runs the call in `Isolate.run` (blocking WinRT `.get()` must not run on the UI/platform thread).
7. Settings → OCR (Windows) shows the language dropdown from `languages()` with "Use my Windows languages" as default.

**Tests:** integration (Windows): `recognises printed English fixture`, `languages lists at least one language`, `missing file returns error code 1 mapped to OcrException`,
`8000 px wide image is scaled and recognised`.

**Verify:** `Push-Location app; flutter build windows --debug; flutter test integration_test/ocr_windows_test.dart -d windows; Pop-Location`.

**Pitfalls:** do not call `.get()` on an STA thread (it throws); the Dart isolate's worker thread is not STA once you initialise MTA. Do not ship `vcruntime` here; Phase 9 handles runtime DLLs.

---

### 08.40 OCR queue, OCR cache and PDF handling

**Purpose:** OCR attachments in the background, once per content version, and index PDF text.

**Files:** `app/lib/media/ocr/ocr_queue.dart`, `ocr_cache.dart`, `pdf_text_extractor.dart`, `ocr_settings.dart`; tests `app/test/media/ocr/ocr_queue_test.dart`, `ocr_cache_test.dart`.

**Implementation:**
1. `OcrCache`: SQLite file `<appSupportDir>/ocr/<vaultId>.sqlite` (use `package:sqlite3`; add it to the app if not already a dependency) with table
   `ocr(content_hash TEXT PRIMARY KEY, engine TEXT, body TEXT, created TEXT, status TEXT /* ok | failed | skipped */, error TEXT)`. Keyed by **content hash**, so renamed or
   duplicated attachments are not re-OCR'd and index rebuilds do not lose OCR work.
2. Candidates: attachments with extensions `png jpg jpeg webp bmp` (images) and `pdf`, not inside excluded folders, not `.tephraenc`, size ≤ 30 MB (images) / 200 MB (PDF).
3. `OcrQueue` (one per open vault; starts 30 s after the vault opens):
   - builds the work list: for each candidate compute content hash (read bytes in `Isolate.run`); if `OcrCache` has the hash with status `ok` → `putAttachmentText` if
     `attachmentTextHashes()[path] != hash`; if `failed`/`skipped` → skip; else enqueue;
   - processes one item at a time; on Android pauses when the app is paused and resumes on resume; never runs while a sync is uploading (check the sync status provider, wait);
   - on `NoteIndex.changes`/vault changes for candidate paths: re-check that path;
   - on an `IndexEvent` with `fullRebuild`: re-push every cached text for current paths (no OCR);
   - writes results to the cache, then `putAttachmentText`;
   - progress shown in Settings → OCR ("Recognised 120 of 340 images").
4. PDFs (`PdfTextExtractor`, uses `pdfrx` — check its current API for opening a document and loading page text): for each page (max 300 pages; setting) load the text layer;
   if the trimmed page text has ≥ 20 characters, use it (`engine: 'pdf-text'`); otherwise render the page to an image at 2× scale (max 3,000 px on the longest side), save a temp PNG
   in `<cache>/ocr-tmp/`, OCR it (`engine: 'pdf-ocr'`), delete the temp file. Join pages with `\n\f\n`. If any page needed OCR the engine is `pdf-ocr`.
5. Settings → OCR: "Recognise text in images and PDFs" (default on), "Only while charging" (Android, default off — uses the battery state from the existing platform
   service if present; otherwise omit this option and note it), language (Windows), "Re-run OCR" button (clears the cache).

**Tests:** `cache hit skips OCR`, `renamed attachment reuses cache`, `failed items not retried until content changes`, `full rebuild re-pushes cached text`, `pdf with text layer uses text`,
`pdf page without text gets OCR` (fake engine), `pauses on app paused`.

**Verify:** app tests for `media/ocr`; manual on both platforms: a vault with 20 photos and 2 scanned PDFs — after the queue finishes, search finds a word from a photo and a word from a
scanned page. Record time per image (Android and Windows).

**Pitfalls:** OCR must never block UI or indexing; one item at a time, with yields between items.

---

### 08.41 whisper.cpp plugin: vendoring and native build

**Purpose:** a native speech-to-text library for Windows and Android.

**Files:**
- `app/plugins/tephra_whisper/` created with `flutter create --template=plugin_ffi --platforms=android,windows --org com.tephra tephra_whisper` (inside `app/plugins/`)
- `app/plugins/tephra_whisper/src/whisper.cpp/` (vendored source)
- `app/plugins/tephra_whisper/src/tephra_whisper.c` → rename to `tephra_whisper.cpp`, `tephra_whisper.h`, `CMakeLists.txt`
- `app/plugins/tephra_whisper/android/build.gradle` (ABI filters), `windows/CMakeLists.txt` (as generated)
- `tool/vendor_whisper.dart`, `tool/extra_notices.json`, change to `tool/check_licenses.dart`
- root `pubspec.yaml` (workspace member), `app/pubspec.yaml` (path dependency)

**Implementation:**
1. Pick the latest whisper.cpp release tag from `https://github.com/ggml-org/whisper.cpp/releases` (at writing: `v1.9.5`). `tool/vendor_whisper.dart <tag>` downloads
   `https://github.com/ggml-org/whisper.cpp/archive/refs/tags/<tag>.zip`, extracts only `include/`, `src/`, `ggml/`, `CMakeLists.txt`, `cmake/`, `LICENSE` into
   `app/plugins/tephra_whisper/src/whisper.cpp/`, and writes `VENDORED_VERSION` with the tag and the zip's SHA-256. Commit the vendored source (MIT).
2. Wrapper C API (`tephra_whisper.h`):
   ```c
   typedef struct tw_ctx tw_ctx;
   FFI_PLUGIN_EXPORT int32_t tw_cpu_supported(void);                 // Windows: 1 if AVX2 is available (IsProcessorFeaturePresent(PF_AVX2_INSTRUCTIONS_AVAILABLE)); Android: 1
   FFI_PLUGIN_EXPORT tw_ctx* tw_init(const char* model_path_utf8);   // NULL on failure
   // pcm: mono float32 at 16 kHz. language: "auto", "en", "bn", ... abort_flag/progress: shared ints the caller may read/write.
   // Returns malloc'd UTF-8 JSON {"language":"bn","segments":[{"t0":0,"t1":2300,"text":"..."}]} or NULL on failure/abort.
   FFI_PLUGIN_EXPORT char* tw_transcribe(tw_ctx* ctx, const float* pcm, int32_t n_samples, const char* language, int32_t n_threads,
                                         volatile int32_t* abort_flag, volatile int32_t* progress_percent);
   FFI_PLUGIN_EXPORT void tw_free_string(char* s);
   FFI_PLUGIN_EXPORT void tw_free(tw_ctx* ctx);
   ```
   Implementation: `whisper_context_default_params()` (use_gpu = false) + `whisper_init_from_file_with_params`; `whisper_full_default_params(WHISPER_SAMPLING_GREEDY)` with
   `language`, `n_threads`, `translate = false`, `print_progress = false`, `print_realtime = false`, `print_timestamps = false`, `abort_callback` reading `*abort_flag`,
   `progress_callback` writing `*progress_percent`; `whisper_full(...)`; iterate `whisper_full_n_segments`, `whisper_full_get_segment_text`, `whisper_full_get_segment_t0/t1`
   (centiseconds → ms ×10); `whisper_full_lang_id` + `whisper_lang_str` for the detected language. **Open `include/whisper.h` of the vendored tag and confirm every function
   and field name before writing the wrapper.**
3. `src/CMakeLists.txt`: `set(GGML_NATIVE OFF)`, `set(WHISPER_BUILD_TESTS OFF)`, `set(WHISPER_BUILD_EXAMPLES OFF)`, `set(BUILD_SHARED_LIBS OFF)`;
   on Windows x64 `set(GGML_AVX ON)`, `set(GGML_AVX2 ON)`, `set(GGML_FMA ON)`, `set(GGML_F16C ON)`; `add_subdirectory(whisper.cpp)`; the plugin's shared library
   `tephra_whisper` links `whisper` statically. Release optimisation `-O3`/`/O2` even in debug builds of the app (set `CMAKE_BUILD_TYPE` override for this target only)
   because unoptimised whisper is unusably slow.
4. Android: in the plugin's `android/build.gradle` set `ndk { abiFilters 'arm64-v8a', 'armeabi-v7a', 'x86_64' }` and `externalNativeBuild { cmake { path "../src/CMakeLists.txt" } }`
   (the template already wires CMake; keep its NDK version). ggml uses NEON on ARM automatically.
5. `tool/extra_notices.json`: `{"components":[{"name":"whisper.cpp","version":"<tag>","licence":"MIT","licenseFile":"app/plugins/tephra_whisper/src/whisper.cpp/LICENSE"},
   {"name":"ONNX Runtime","version":"<version bundled by the onnxruntime plugin>","licence":"MIT","licenseUrl":"https://github.com/microsoft/onnxruntime/blob/main/LICENSE"},
   {"name":"multilingual-e5-small","licence":"MIT","licenseUrl":"https://huggingface.co/intfloat/multilingual-e5-small"},
   {"name":"OpenAI Whisper model weights","licence":"MIT","licenseUrl":"https://github.com/openai/whisper/blob/main/LICENSE"}]}`.
   Extend `tool/check_licenses.dart`: after the Dart packages, append a section "## Native and model components" listing these entries (with the licence text from
   `licenseFile` when given, else the URL). Add a test in `tool/test/` for the new section. (This changes our own tool, not a contract; record it in `PROGRESS.md`.)

**Tests:** build smoke tests in 08.42.

**Verify:** `Push-Location app; flutter build windows --release; flutter build apk --release --split-per-abi; Pop-Location` both succeed; record the arm64 APK size and
the size of `tephra_whisper.dll`.

**Pitfalls:** a debug Android build of ggml without optimisation can take minutes per second of audio — always build the native part optimised.

---

### 08.42 Transcription service, Dart bindings and model download

**Purpose:** transcribe WAV files on-device in a background isolate.

**Files:** `app/plugins/tephra_whisper/lib/tephra_whisper.dart` (bindings), `app/lib/media/transcribe/wav_reader.dart`, `transcription_service.dart`,
`whisper_models.dart` (pinned model specs, reusing 08.15's `ModelDownloadService`), `providers.dart`; tests `app/test/media/transcribe/wav_reader_test.dart`,
`transcription_service_test.dart`; integration `app/integration_test/whisper_test.dart`; fixtures `app/integration_test/assets/audio/en_hello.wav`, `bn_sample.wav`
(record 5-second clips yourself with the app's recorder or a TTS tool; licence-free).

**Implementation:**
1. Models (pin URLs at a fixed commit of `https://huggingface.co/ggerganov/whisper.cpp`, compute SHA-256 and size yourself as in 08.15):
   `ggml-base-q5_1.bin` ("Fast — good for English", default) and `ggml-small-q5_1.bin` ("Accurate — recommended for Bangla"). Settings → Voice: model choice, download/delete,
   language (Auto / English / বাংলা / other ISO code), "Transcribe new voice notes automatically" (`autoTranscribe`).
2. `WavReader.readMono16k(Uint8List bytes) → Float32List`: parse RIFF/WAVE chunks (skip unknown chunks; `fmt ` and `data` required); support PCM 16-bit (format 1),
   PCM 24/32-bit, IEEE float 32-bit (format 3), and `WAVE_FORMAT_EXTENSIBLE` (0xFFFE) wrapping those; any channel count (average to mono); any sample rate
   (linear resampling to 16,000 Hz after a 2-tap averaging low-pass when downsampling). Max 60 minutes; longer → `TranscriptionException('too long')`.
3. `TranscriptionService.transcribe(VaultPath wavPath, {String language = 'auto'}) → Stream<TranscriptionProgress>` (`progress(percent)`, `done(TranscriptResult)`, `failed(message)`):
   - check `tw_cpu_supported()` (Windows without AVX2 → "Your processor doesn't support on-device transcription.");
   - read bytes, decode in `Isolate.run`;
   - allocate `abort` and `progress` ints with `calloc<Int32>()` in the main isolate; spawn a worker isolate (`Isolate.spawn`) passing the model path, the PCM data
     (as `TransferableTypedData`), language, `n_threads = min(4, Platform.numberOfProcessors)` and the two pointer **addresses** (`pointer.address`);
     the worker calls `tw_init`/`tw_transcribe`/`tw_free` and sends the JSON back; the main isolate polls `progress.value` every 500 ms; cancel sets `abort.value = 1`;
     free both pointers after the worker exits.
   - one transcription at a time; queued jobs persist in `.tephra/cache/transcribe-queue.json` (vault cache, not synced) so a killed app resumes them on next start.
4. Performance notes for Android (write them in `docs/decisions/transcription.md` with your measured numbers): use `base-q5_1` by default; `small-q5_1` is ~3–4× slower;
   keep the screen-on wake lock only while the transcription page is visible (do not add a foreground service in this phase); if the app is backgrounded and killed, the queue resumes.

**Tests:** wav reader: `16-bit stereo 44.1k becomes mono 16k with expected length`, `float32 mono 16k passes through`, `extensible format`, `skips LIST chunk`, `rejects non-wave`;
service (fake native layer behind an interface): `progress then done`, `cancel sets abort flag`, `queue persists and resumes`. Integration (Windows and Android):
`transcribes English fixture containing "hello"`, `Bangla fixture returns non-empty Bengali text with small model` (Windows only if the small model is downloaded).

**Verify:** app tests; integration tests on both platforms; record real-time factor (processing time / audio length) for base and small on both platforms.

**Pitfalls:** never pass Dart heap pointers to native code across isolates; only `calloc`'d memory addresses.

---

### 08.43 Voice notes and transcript insertion

**Purpose:** record a voice note and put the transcript below its embed (Format F7).

**Files:** `app/lib/media/transcribe/voice_note_command.dart`, `transcript_inserter.dart`, `transcribe_embed_action.dart`; tests `app/test/media/transcribe/transcript_inserter_test.dart`.

**Implementation:**
1. Command `media.record-voice-note` (mobile toolbar + palette): records with the Phase 7 recorder service but with `RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1)`
   (check the `record` package's current API; if the Phase 7 recorder wraps it, add a `format` parameter there). File name `Voice note YYYYMMDDHHmmss.wav` in the attachment
   folder (§6.7); inserts `![[Voice note YYYYMMDDHHmmss.wav]]` at the cursor; if `autoTranscribe` is on and a model is downloaded, enqueues transcription.
2. On any audio embed of a `.wav` file (reading view and Live Preview players from Phase 6/7), add the action "Transcribe" (menu). Non-WAV files show "Transcription needs a WAV recording."
3. `TranscriptInserter.insert(String noteText, String embedTarget, List<String> segments) → String?`: find the first line containing `![[<embedTarget>` (exact file name match,
   allowing `|size`); build the F7 block; if the next line starts with `> [!quote]- Transcript`, replace that callout (all following consecutive lines starting with `>`);
   else insert after the embed line. Returns null if the embed line is not found.
4. Applying: if the note is open → one undoable editor transaction; else atomic file write with a content-hash check (if the file changed since reading, re-read and retry once).
5. A snackbar "Transcript added" with "Undo" when applied through the editor.

**Tests:** `inserts below embed`, `replaces existing transcript`, `handles embed with size`, `skips empty segments`, `returns null when embed missing`, `CRLF note round-trips`
(via `TextDocument`).

**Verify:** app tests; manual on both platforms: record 20 s of speech → transcript appears below the embed; open the note in Obsidian → collapsed quote callout.

**Pitfalls:** the recorder must not overwrite an existing file (append `-1`, `-2` if the name exists).

---

### 08.44 Sketch model and file I/O

**Purpose:** Format F5.

**Files:** `app/lib/sketch/sketch_document.dart`, `sketch_stroke.dart`, `sketch_codec.dart`, `sketch_file_service.dart`; tests `app/test/sketch/sketch_codec_test.dart`,
`sketch_file_service_test.dart`.

**Implementation:**
1. Immutable `SketchDocument { int version; double width; double height; String background; List<SketchStroke> strokes; Map<String, Object?> extra; }` and
   `SketchStroke { String id; SketchTool tool; Color color (stored as #RRGGBBAA); double size; List<SketchPoint> points; Map<String, Object?> extra; }`,
   `SketchPoint { double x, y, pressure; int t; }`.
2. `SketchCodec.decode(String json)` validates `type == "tephra-sketch"` and `version == 1` (higher version → `ParseException('Made with a newer Tephra')`, opened read-only);
   keeps unknown keys in `extra`; `encode` writes keys in a fixed order (`type, version, width, height, background, strokes`, then extras) with numbers rounded per F5.
3. `SketchFileService`: `create()` → picks the name `Sketch YYYYMMDDHHmmss` in the attachment folder; `save(VaultPath jsonPath, SketchDocument doc, Uint8List png)` writes the JSON
   then the PNG (both atomic); `load(VaultPath)`; `pngPathFor(jsonPath)` / `jsonPathFor(pngPath)` (`.sketch.json` ↔ `.sketch.png`).

**Tests:** `round-trip preserves unknown keys`, `numbers rounded to 2 decimals`, `newer version rejected`, `path pairing`, `create picks unique name`.

**Verify:** app tests for `sketch`.

**Pitfalls:** `Color` → `#RRGGBBAA` conversion: Flutter stores ARGB; convert explicitly.

---

### 08.45 Sketch editor

**Purpose:** drawing UI with stylus pressure, tools and undo/redo.

**Files:** `app/lib/sketch/sketch_editor_page.dart`, `sketch_canvas.dart`, `sketch_painter.dart`, `sketch_controller.dart`, `sketch_toolbar.dart`, `lasso.dart`;
tests `app/test/sketch/sketch_controller_test.dart`, `lasso_test.dart`, `sketch_editor_page_test.dart`; golden `app/test/sketch/goldens/sketch_basic.png` (`@Tags(['golden'])`).

**Implementation:**
1. Input via `Listener` (raw pointer events). Pressure: `event.pressure` normalised with `(p - pressureMin) / (pressureMax - pressureMin)`; when `pressureMin == pressureMax`
   (mouse, most fingers) store 0.5 and render with `simulatePressure: true`; for `PointerDeviceKind.stylus` render with `simulatePressure: false`.
2. Palm rejection: setting "Draw with stylus only" (auto-enabled the first time a stylus event is seen on Android); then touch input pans/zooms instead of drawing.
3. Tools: **Pen** (8 preset colours + custom, size 1–24), **Highlighter** (size ×3, alpha 35 %, drawn under pen strokes), **Eraser** (stroke eraser: removes every stroke with any
   segment within 10 px / zoom of the eraser path), **Lasso** (closed polygon; selects strokes with ≥ 50 % of their points inside, ray-casting test; selected strokes can be moved by
   dragging, deleted, or recoloured).
4. Rendering: `perfect_freehand` `getStroke(points, options: StrokeOptions(size, thinning 0.6, smoothing 0.5, streamline 0.5, simulatePressure))` → outline polygon → `Path` →
   `canvas.drawPath`. Cache each finished stroke's `Path`; only the live stroke is recomputed per frame. Canvas inside `InteractiveViewer` (two-finger pan/zoom, mouse wheel zoom),
   fixed logical size from the document.
5. Undo/redo: command stack (`AddStroke`, `RemoveStrokes`, `MoveStrokes`, `RecolorStrokes`), max 200 entries; Ctrl+Z / Ctrl+Y / Ctrl+Shift+Z on Windows; toolbar buttons.
6. Save: on "Done", on back navigation, and every 30 s while dirty. PNG: `PictureRecorder` → paint background + strokes at scale 1 → `picture.toImage(width, height)` →
   `toByteData(format: ImageByteFormat.png)`; run encoding off the critical path (it is async).
7. Phone layout: toolbar at the bottom, tools as icons; desktop: toolbar on top with keyboard shortcuts P (pen), H (highlighter), E (eraser), L (lasso).

**Tests:** `add stroke then undo removes it`, `redo restores`, `eraser removes intersecting strokes only`, `lasso selects strokes mostly inside`, `move selected shifts points`,
`pressure normalisation`, `mouse input uses simulated pressure`, golden `sketch_basic` (3 known strokes).

**Verify:** app tests (goldens on Windows); manual: Android with stylus (pressure visibly changes width) and with finger; Windows with mouse and pen if available.
Performance: drawing a stroke over a sketch with 2,000 strokes stays at 60 fps on Windows and ≥ 50 fps on the phone (DevTools performance overlay; record).

**Pitfalls:** do not rebuild all stroke paths on every pointer move.

---

### 08.46 Sketch embedding and tap-to-edit

**Purpose:** create sketches from notes and edit them from their preview.

**Files:** `app/lib/sketch/sketch_commands.dart`, `sketch_embed_handler.dart`; changes in the reading-view image widget and Live Preview image widget, and in the rename/delete
services from Phase 2; tests `app/test/sketch/sketch_embed_handler_test.dart`.

**Implementation:**
1. Command `sketch.new` (palette + mobile toolbar): creates the files (empty sketch, PNG of the background), inserts `![[Sketch YYYYMMDDHHmmss.sketch.png]]` at the cursor, opens the editor.
2. Image widgets: when the embedded file name ends with `.sketch.png` and the sibling `.sketch.json` exists, tap (reading view) or the "Edit sketch" button (Live Preview, shown on hover/selection)
   opens the sketch editor; long-press / right-click menu also offers "Edit sketch". After saving, the image cache for that PNG is evicted so the new preview shows.
3. Rename/move/delete: when Tephra renames/moves/deletes a `.sketch.png` or `.sketch.json`, it applies the same operation to the partner file (in the same undoable vault operation).
   Link updates for the PNG work as for any attachment (Phase 2 rename).

**Tests:** `new sketch inserts embed`, `tap opens editor only when json exists`, `rename moves partner`, `delete trashes partner`.

**Verify:** app tests; manual on both platforms; open the note in Obsidian → PNG shows.

**Pitfalls:** an orphan `.sketch.png` without JSON is just an image (no edit button).

---

### 08.47 Block 8c check

**Purpose:** prove 8c.

**Checks (record in `PROGRESS.md` "Block 8c check"):**
1. OCR: search finds text from 5 different photos and 1 scanned PDF on both platforms; OCR queue does not affect typing latency (measure typing budget while the queue runs).
2. Transcription: a 1-minute English voice note transcribes on both platforms; record real-time factors; Bangla with the small model produces Bengali text (quality noted).
3. Sketch: create, edit, rename, sync to the other device (Phase 3 sync), open on the other device and edit.
4. Phase 2 budgets (full set) re-measured; APK arm64 size recorded.
5. Limitations written in `docs/decisions/media-intelligence-limits.md`: no Bangla OCR; WAV-only transcription; whisper requires AVX2 on Windows.

**Tests:** all package and app tests; integration tests of 8c on both platforms.

**Verify:** results recorded.

**Pitfalls:** if the arm64 APK is above 40 MB, report it now with the size breakdown (`flutter build apk --analyze-size --target-platform android-arm64`).

---

## Block 8d — Security (weeks 7–8)

### 08.48 TENC codec

**Purpose:** Format F6 encryption/decryption, pure Dart.

**Files:** `packages/tephra_vault/lib/src/crypto/tenc_codec.dart`, `tenc_header.dart`, `kdf_params.dart`, `area_key_wrap.dart`, `recovery_key.dart`,
`wrong_password_exception.dart`; export from `lib/tephra_vault.dart`; tests `packages/tephra_vault/test/crypto/tenc_codec_test.dart`, `area_key_wrap_test.dart`, `recovery_key_test.dart`.

**Implementation:**
1. Add `cryptography` to `tephra_vault` (`dart pub add cryptography`) unless present. Use `AesGcm.with256bits()`, `Argon2id(memory:, parallelism:, iterations:, hashLength: 32)`,
   `Hkdf(hmac: Hmac.sha256(), outputLength: 32)`. If Phase 3 put faster platform implementations behind an abstraction (e.g. `cryptography_flutter` in the app), accept an injected
   `Cipher`/`KdfAlgorithm` so the app can pass the same fast implementations.
2. `KdfParams { int memoryKiB; int iterations; int parallelism; Uint8List salt; }`; `KdfParams.defaults()` = Phase 3's calibrated values if exposed (search `tephra_sync` for the
   Argon2id parameters), else `65536 / 3 / 1`, salt 16 random bytes (`Random.secure()`).
3. ```dart
   abstract final class TencCodec {
     static bool looksEncrypted(List<int> bytes);                                          // magic check
     static TencHeader readHeader(List<int> bytes);                                        // throws ParseException
     static Future<Uint8List> encryptStandalone({required String password, required KdfParams kdf, required String name, required DateTime mtime, required List<int> content});
     static Future<Uint8List> encryptWithKey({required SecretKey key, required Uint8List areaId, required String name, required DateTime mtime, required List<int> content});
     static Future<TencPayload> decryptStandalone(List<int> bytes, String password);      // WrongPasswordException on tag failure
     static Future<TencPayload> decryptWithKey(List<int> bytes, SecretKey key);
     static Future<SecretKey> deriveStandaloneKey(TencHeader header, String password);   // lets the app cache the key for a session
   }
   final class TencPayload { final String name; final DateTime mtime; final Uint8List content; }
   ```
   Header byte layout, AAD and payload exactly per F6. Nonce: 12 random bytes from `Random.secure()` per encryption.
4. `AreaKeyWrap`: `wrap(areaKey, password, kdf, areaId)` / `unwrap(...)` and `wrapWithRecovery` / `unwrapWithRecovery` per F6.
5. `RecoveryKey.generate()` → 32 bytes; `format(bytes)` → 13 groups of 4 Crockford base32 chars (52 chars, last group padded) joined with `-`; `parse(text)` tolerant of case,
   spaces and `-`, mapping `O→0`, `I/L→1`.
6. Zeroisation: after use, overwrite password-derived key bytes with zeros where the API allows (`SecretKeyData.bytes` list) — best effort; document it.

**Tests:** `standalone round-trip`, `key round-trip`, `wrong password throws WrongPasswordException`, `tampered header byte fails`, `tampered ciphertext fails`,
`different nonce each encryption`, `payload name and mtime preserved`, `empty content`, `10 MB content` (timing printed), `known-vector test` (fixed key, nonce and plaintext →
exact bytes; create the vector once and assert it stays stable), `recovery key format and parse round-trip`, `recovery unwrap`, `looksEncrypted false for markdown`.

**Verify:** package tests for `tephra_vault`.

**Pitfalls:** never use `Random()` (non-secure) for salts or nonces.

---

### 08.49 Encrypted-areas registry and unlock sessions

**Purpose:** manage areas (F6 JSON) and in-memory keys with auto-lock.

**Files:** `app/lib/security/encryption/encrypted_areas_registry.dart`, `encryption_session.dart`, `unlock_dialog.dart`, `providers.dart`;
tests `app/test/security/encryption/encrypted_areas_registry_test.dart`, `encryption_session_test.dart`.

**Implementation:**
1. `EncryptedAreasRegistry`: load/save `.tephra/encrypted-areas.json` (atomic; sorted, pretty JSON); `areaForPath(VaultPath)` (the area whose `folder` contains the path),
   `areaById(id)`, `add(area)`, `updateFolder(id, newFolder)`, `remove(id)`. Folder renames/moves done by Tephra update `folder` in the same vault operation (hook into the
   Phase 2 rename service). Confirm that `.tephra/encrypted-areas.json` is included by the Phase 3 sync (it syncs `.tephra/` except `cache/` — check the include rules; if it is
   excluded, stop and ask the human).
2. `EncryptionSession` (app-wide, per vault): `Map<String areaId, SecretKey>` and `Map<VaultPath, SecretKey>` (standalone notes), `unlockArea(id, password)`,
   `unlockAreaWithRecovery(id, recoveryKey)`, `unlockStandalone(path, password)`, `isUnlocked(path)`, `keyFor(path)`, `lockAll()`, `Stream<void> changes`.
   Auto-lock: setting "Lock encrypted notes after" (1, 5 (default), 15, 30, 60 minutes of inactivity; and "when the app goes to the background", default on).
   Inactivity = no edit/scroll/open of an encrypted note. `lockAll` saves open encrypted editors first, then zero-fills key bytes, clears the maps, closes encrypted tabs and
   clears the decrypted-name cache.
3. While anything is unlocked on Android, set `FLAG_SECURE` on the activity (hides content in the app switcher and blocks screenshots): add a small method channel
   `com.tephra.app/secure_window` in `MainActivity.kt` with `setSecure(bool)`. Clear it after `lockAll`.
4. `UnlockDialog`: password field, "Use recovery key" link, error "Wrong password" on `WrongPasswordException`, attempt counter with 1 s, 2 s, 4 s … (max 60 s) delay after 3 failures.

**Tests:** `registry round-trip`, `areaForPath picks containing folder`, `folder rename updates registry`, `unlock with wrong password fails`, `auto-lock after timeout` (fake clock),
`lock on background`, `lockAll zero-fills and clears`.

**Verify:** app tests for `security`.

**Pitfalls:** never persist keys or passwords; never log area folder names at `info` level or above.

---

### 08.50 Encrypt and decrypt flows

**Purpose:** encrypt a note or a folder; remove encryption.

**Files:** `app/lib/security/encryption/encrypt_note_flow.dart`, `encrypt_folder_flow.dart`, `decrypt_flow.dart`, `set_password_dialog.dart`, `recovery_key_dialog.dart`;
commands `security.encrypt-note`, `security.encrypt-folder`, `security.remove-encryption`, `security.lock-now`; tests `app/test/security/encryption/encrypt_flows_test.dart`.

**Implementation:**
1. Set-password dialog: password + repeat, minimum 10 characters, a simple strength hint (length and character classes), checkbox "I understand that if I forget this password and
   lose the recovery key, these notes cannot be recovered" (required).
2. **Encrypt note** (`X.md`): read bytes → `encryptStandalone` (option "Hide the title" → random file name) → write `X.tephraenc` (atomic) → **verify** by decrypting and comparing
   the content hash → delete the plaintext with `TrashMode.permanent` → purge local history snapshots of `X.md` in `.tephra/history/` (Phase 3 local snapshots) → links to `X` now resolve to nothing
   (they show as unresolved) — the confirmation dialog says so.
3. **Encrypt folder**: create area (random id, area key, KDF, wrapped key, recovery-wrapped key) → show the recovery key once (copy button, "I saved it" checkbox) → for every file
   in the folder recursively (notes and attachments): encrypt with the area key to `<16 hex>.tephraenc` in the same sub-folder, verify, then permanently delete the plaintext and purge its
   local history snapshots. Runs in a background isolate with progress; it is resumable: before starting, write `.tephra/cache/encrypt-job-<areaId>.json` (list of remaining paths)
   and update it after each file; on app start an unfinished job resumes after asking for the password.
4. **Why permanent delete here:** moving plaintext to `.trash/` or keeping snapshots would defeat the purpose. This is the only place in Tephra that deletes without trash, it happens
   only after the encrypted copy is verified, and the dialog states: "The unencrypted files will be permanently removed from this device. Copies in Google Drive sync history remain
   (encrypted with your vault key) until history expires. On SSDs, removed data may remain recoverable with special tools."
5. **Remove encryption** (requires unlocked): reverse — decrypt each file to its original name (if the name exists, append ` (decrypted)`), verify, then delete the `.tephraenc`
   through the normal trash (ciphertext is safe to keep in trash); remove the area from the registry when the folder has no `.tephraenc` left.
6. Files dropped into an area folder from outside (e.g. Obsidian): detected on vault scan; banner "3 unencrypted files in encrypted folder 'Private'. Encrypt now?" (requires unlock).
7. Moving a file into an area folder in Tephra's explorer: if unlocked, "Encrypt and move"; if locked, the move is refused with an explanation. Moving out: "Decrypt and move" (unlocked only).

**Tests:** `encrypt note writes tephraenc and removes plaintext`, `verification failure keeps plaintext` (inject a corrupting writer), `history snapshots purged`, `encrypt folder resumes after interruption`,
`hide title uses random name`, `remove encryption restores names`, `name collision gets suffix`, `move into locked area refused`.

**Verify:** app tests; manual on both platforms with a copy of a test vault: encrypt a folder of 50 notes + 5 images; inspect the folder in Explorer — only `.tephraenc` files; open the vault in
Obsidian — files shown as unknown, no plaintext.

**Pitfalls:** never encrypt files inside `.tephra/`, `.obsidian/` or `.trash/`.

---

### 08.51 Working with encrypted notes: explorer, editor, search, sync

**Purpose:** use unlocked encrypted notes almost like normal notes, without plaintext ever touching disk.

**Files:** `app/lib/security/encryption/encrypted_document_source.dart`, `encrypted_names_cache.dart`, `unlocked_content_search.dart`; changes in explorer item rendering,
the editor document loader/saver (Phase 1.5), search panel, embed resolution, index/sync/OCR/AI exclusion points; tests `app/test/security/encryption/encrypted_document_source_test.dart`,
`unlocked_content_search_test.dart`, `exclusions_test.dart`.

**Implementation:**
1. Explorer: `.tephraenc` files show a lock icon. Locked: area files show "Locked note" + the first 6 hex characters; standalone files show their stem. Unlocked: the decrypted `name`
   from the payload (kept in `EncryptedNamesCache`, memory only). Tapping a locked file opens the unlock dialog.
2. Editor: the document loader detects `.tephraenc`, decrypts to a `TextDocument` in memory (payload bytes decoded with `TextDocument.decode`), opens a normal editor tab titled with the
   decrypted name and a lock badge. Saving encodes the `TextDocument`, encrypts (fresh nonce, same key/area, same name, new mtime) and `writeBytes` atomically — the temp file contains
   ciphertext only. Autosave works the same. Paste/drop of attachments into an encrypted note is refused: "Attachments can't be added to encrypted notes yet."
3. Embeds inside an unlocked encrypted note that point to files of the same area resolve by decrypted name (via the names cache) and render from decrypted bytes in memory
   (`Image.memory`); embeds to normal vault files work as usual.
4. Search: the index never contains encrypted content (`.tephraenc` is a non-note file; make sure `NoteIndex` does not FTS it and OCR skips it). `UnlockedContentSearch` scans
   decrypted texts of unlocked notes in memory for plain-term queries (all terms, case-insensitive) and the search panel appends those results with a lock badge. Operators are not
   applied to encrypted content (hint shown). Nothing from encrypted notes goes to the semantic index, AI features, Bases/queries, tasks dashboard, flashcards or graph.
5. Local history: Phase 3 snapshots of `.tephraenc` files store the ciphertext bytes (check the snapshot code reads file bytes, not editor text; if it snapshots editor text, add a branch that
   snapshots the encrypted bytes).
6. Sync: `.tephraenc` files sync as normal binary files (already end-to-end encrypted by Phase 3 too). A both-sides change produces a binary conflict copy (keep both) — documented.
7. Exclusion test: one test that builds a vault with an unlocked encrypted note containing the word `zebracorn` and asserts it appears in none of: index FTS, semantic store, OCR cache,
   AI preview items, query results, task list, flashcards, graph nodes' labels (graph may show the file node by its on-disk name only).

**Tests:** `open decrypts in memory`, `save writes only ciphertext` (spy file system records all writes; none contains the plaintext bytes), `locked file opens unlock dialog`,
`unlocked search finds term`, `exclusions_test zebracorn`.

**Verify:** app tests; manual: open, edit and save an encrypted note on both platforms; search the vault folder on disk for a word from it
(`Select-String -Path <vault>\* -Pattern <word> -Recurse`) → 0 matches.

**Pitfalls:** never cache decrypted text in providers that outlive the session; dispose them on `lockAll`.

---

### 08.52 App lock

**Purpose:** PIN and biometric/Windows Hello lock for the app UI.

**Files:** `app/lib/security/app_lock/app_lock_settings.dart`, `pin_hasher.dart`, `app_lock_service.dart`, `lock_screen.dart`, `providers.dart`; `app/lib/app.dart` (overlay in
`MaterialApp.builder`); `app/android/app/src/main/AndroidManifest.xml` (`USE_BIOMETRIC`); `app/android/app/src/main/kotlin/.../MainActivity.kt` (must extend `FlutterFragmentActivity`
for `local_auth` — check the plugin README); tests `app/test/security/app_lock/pin_hasher_test.dart`, `app_lock_service_test.dart`, `lock_screen_test.dart`.

**Implementation:**
1. `flutter pub add local_auth` (+ the Windows implementation is endorsed; confirm `local_auth_windows` comes in automatically).
2. Settings → Security → App lock: switch (default off); set PIN (4–8 digits, entered twice); "Use fingerprint/face" (Android) or "Use Windows Hello" (Windows) — shown only when
   `canCheckBiometrics || isDeviceSupported()`; "Lock after" (Immediately, 1, 5 (default), 15, 60 minutes in background); "Lock now" command `security.lock-app`.
3. `PinHasher`: Argon2id (`memory 19456 KiB, iterations 2, parallelism 1`, 32 bytes, 16-byte salt) → stored in secure storage key `security.appLock.pin` as JSON
   `{"v":1,"salt":"…","hash":"…","m":19456,"t":2,"p":1}`; constant-time comparison.
4. `AppLockService`: locked at cold start when enabled; records the time when the app goes to background (`AppLifecycleState.paused` on Android, `inactive`+window minimised/hidden on Windows)
   and locks on resume if the elapsed time ≥ "Lock after". Failed PIN attempts: after 5 failures, wait 30 s, doubling up to 15 minutes (persist the counter in secure storage so a restart
   does not reset it).
5. `LockScreen`: full-screen opaque overlay above the whole app (including dialogs: put it in `MaterialApp.builder`'s `Stack` above the navigator), PIN pad, "Use biometrics" button that calls
   `LocalAuthentication.authenticate(localizedReason: <l10n>, options: AuthenticationOptions(biometricOnly: false, stickyAuth: true))` — `biometricOnly` is not supported on Windows,
   so keep it false. Windows sticky windows (Phase 4) show a "Tephra is locked" placeholder while locked. Android home widgets and bubbles: setting "Hide sticky content on the home screen
   while locked" (default on) makes widgets show "Tephra is locked".
6. "Forgot PIN?": explains that app lock protects only the app screen, and that the PIN can be reset by turning off app lock after authenticating with biometrics; if biometrics are not
   available, the user must clear the app's data (Android: Settings → Apps → Tephra → Storage → Clear storage; Windows: delete `<appSupportDir>\secure` per the secure-storage
   location) — vault files are not affected. Show the exact path from `path_provider` in the dialog.

**Tests:** `pin hash verifies correct pin`, `rejects wrong pin`, `constant-time compare used`, `locks after timeout in background`, `does not lock before timeout`, `backoff after 5 failures persists`,
widget `lock screen blocks underlying taps`, `biometric button hidden when unsupported`.

**Verify:** app tests; manual: Android with fingerprint; Windows with Windows Hello PIN/face; app switcher on Android shows no content when locked.

**Pitfalls:** the app lock is not encryption; the settings text must say so ("App lock hides Tephra behind a PIN. It doesn't encrypt your notes — use encrypted folders for that.").

---

### 08.53 Block 8d check

**Checks (record in `PROGRESS.md` "Block 8d check"):**
1. Encrypted folder of 50 notes: no plaintext on disk (search the vault folder for 5 distinctive words → 0 matches), none in the index DB file, vectors DB, OCR cache, logs
   (`Select-String` over `<appSupportDir>` recursively → 0 matches).
2. Auto-lock fires after the configured time; background lock works on both platforms.
3. Wrong password and tampered file (flip one byte with a hex editor or a tiny Dart script) both show a clear error and never crash.
4. Recovery key unlocks an area after the password is "forgotten".
5. App lock: PIN and biometrics on Android; Windows Hello on Windows.
6. Sync: an encrypted note edited on the phone appears (still encrypted) on Windows and opens with the same password.

**Tests:** all package and app tests.

**Verify:** results recorded.

**Pitfalls:** if any plaintext leak is found, fix it before continuing — it is a release blocker.

---

### 08.54 Phase 8 wrap-up: budgets, size, docs

**Purpose:** confirm the phase did not regress performance or size, and document the new features.

**Files:** `PROGRESS.md`, `README.md` (feature list), `docs/decisions/` notes created in this phase, `app/lib/l10n/app_en.arb` (all new strings present).

**Implementation:**
1. Re-measure every conventions §10 budget on the mid-range Android phone and Windows (profile builds, 10k bench vault) with: AI enabled, semantic index complete (model unloaded),
   OCR queue finished, one encrypted area unlocked. Record numbers next to the Phase 7 numbers.
2. `flutter build apk --release --split-per-abi` and record per-ABI sizes; `flutter build apk --analyze-size --target-platform android-arm64` → save the summary to `docs/release/size-phase-08.md`.
3. Grep for hard-coded user-visible strings in new folders (every `Text('…')` literal must be an l10n key) and fix.
4. `dart run tool/check_licenses.dart` — all allowed, notices include the native components.
5. Update `README.md` feature list (one line per feature).

**Tests:** full test suite on both platforms; integration tests of this phase on both platforms.

**Verify:** all numbers recorded; size and budgets compared.

**Pitfalls:** if any budget fails by > 25 %, stop and report (GEMINI §5).

---

## Demo script

Run on the real Android phone **and** on Windows with a copy of your real vault (and the 10k bench vault for the budget parts):

1. Settings → AI: turn on, paste key, Test key → "Key works". Download the semantic model; watch indexing progress while typing in a note.
2. Select a paragraph → Summarise → preview lists "Selected text from …" → Send → streamed summary → Replace → Ctrl+Z (undo) restores the paragraph.
3. Assistant: ask a question answered in your notes → streamed answer with `[[Note#Heading]]` citations → tap one → note opens at the heading. Ask an unrelated question → "I could not find this in your notes."
4. Turn on airplane mode / disable Wi-Fi: Meaning search for a paraphrase of a note title finds that note; Related notes panel shows similar notes.
5. Suggest tags and links on a note → accept one tag and one link → frontmatter and body updated; generate flashcards → accept 5.
6. Open a note with a ` ```tephra-query ` TABLE → edit a property in another note → the table updates. Tick a task in a TASK query → the source note gets `[x]` and `✅ <today>`.
7. Tasks dashboard → Overdue filter → complete a `🔁 every week` task → next occurrence appears with dates +7 days.
8. Create a Kanban board → 3 lanes → drag cards → open the same file in Obsidian's Kanban plugin → same board.
9. Review flashcards: Again / Good / Easy → stats page shows today's reviews.
10. Search for a word that only appears in a photo and in a scanned PDF → both found.
11. Record a voice note → transcript appears below it as a collapsed "Transcript" callout.
12. New sketch with stylus (pressure visible) → Done → PNG appears in the note → tap → edit → Done → preview updates.
13. Encrypt a folder → recovery key shown → folder contains only `.tephraenc` → open a note (password) → edit → wait for auto-lock → note closes.
14. Turn on app lock → background the app for longer than the lock time → resume → PIN / biometrics required.

## Exit gate

- [ ] **8a:** every Ask-your-vault answer in the 7-question test cites at least one source note with a valid `[[…]]` link, and out-of-vault questions reply "I could not find this in your notes." (both platforms).
- [ ] **8a:** semantic search and Related notes work fully offline with the local model (airplane mode / Wi-Fi off), both platforms.
- [ ] **8a:** no AI request is sent without a user action; with "Always confirm" on, every request shows the preview first; the API key and note text never appear in logs.
- [ ] **8a:** 401, 429 (with `retry-after`), 529 and network errors each produce the specified plain-language message (unit tests green).
- [ ] **8b:** the 10 queries in `queries.md` give the same rows in Tephra and in Obsidian Dataview, except documented unsupported features.
- [ ] **8b:** Kanban boards written by Tephra open as boards in the Obsidian Kanban plugin, and plugin-written boards round-trip byte-for-byte through Tephra when unchanged.
- [ ] **8b:** Tasks completion adds `✅ YYYY-MM-DD` and simple recurrences create the next task exactly like the Tasks plugin for the fixture tasks.
- [ ] **8b:** SM-2 unit tests green; review screen usable with keyboard only (Windows) and touch (Android).
- [ ] **8c:** text in photos (Latin script) and in scanned/text PDFs is found by search on both platforms; Bangla OCR limitation documented.
- [ ] **8c:** a 1-minute voice note is transcribed on-device on both platforms; real-time factors recorded.
- [ ] **8c:** sketches with stylus pressure save as `.sketch.json` + `.sketch.png`, render in Obsidian as the PNG, and reopen for editing in Tephra.
- [ ] **8d:** no plaintext of encrypted notes on disk, in the index, vectors DB, OCR cache or logs (search check = 0 matches).
- [ ] **8d:** auto-lock, wrong-password handling, tamper detection and recovery key all verified on both platforms.
- [ ] **8d:** app lock works with PIN and biometrics on Android and with Windows Hello on Windows.
- [ ] All conventions §10 performance budgets still met (numbers recorded in `PROGRESS.md`); release APK per ABI < 40 MB **or** the overrun reported to the human with a size breakdown.
- [ ] `flutter analyze --fatal-infos` clean, all tests green, `dart run tool/check_licenses.dart` passes.

## Hand-off

When the gate is fully checked:
1. Update `PROGRESS.md`: all 54 steps ticked, the four block-check sections, budget numbers, APK sizes, "Contract additions (Phase 8)" list, open limitations
   (no Bangla OCR, WAV-only transcription, AVX2 requirement, inline fields unsupported, `file.etags` = `file.tags`, encrypted folder names not encrypted).
2. `git checkout main; git merge --no-ff phase-08; git tag v0.08.0`.
3. Report to the human: what was built, gate results, APK size status, the contract additions to fold into `00-conventions.md`, and the decisions they need to know about
   (ML Kit terms, permanent deletion of plaintext when encrypting).
4. Stop and wait for "continue". The next phase is `instructions/phase-09-release.md`. Phase 9 relies on: the AI settings privacy text (for the privacy policy),
   the list of network destinations (Anthropic, Voyage, Hugging Face model downloads, Google Drive), and the APK size breakdown from 08.54.

