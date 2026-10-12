# Platform Spike: Drift + SQLite FTS5 (Step 00.17)

## Purpose & Overview
Evaluate SQLite FTS5 full-text search integrated via `drift` and `drift_flutter` on Windows and Android.
The spike tests:
1. Presence of SQLite FTS5 (`ENABLE_FTS5`).
2. Insert performance for 10,000 deterministic notes.
3. Query performance against a 50 ms budget across common and complex query types (`AND`, phrase search `"..."`, prefix `top*`, `OR`, `NOT`).
4. Bengali (বাংলা) support and substring search behavior using `unicode61 remove_diacritics 2` vs `trigram` tokenizers.

## Environment & Versions
- **Drift**: `2.35.2`
- **drift_flutter**: `0.3.1` (bundles native SQLite via `sqlite3` 3.x build hooks; `sqlite3_flutter_libs` is obsolete and omitted)
- **path_provider**: `2.1.6`
- **SQLite Version**: `3.53.4`
- **FTS5 Enabled**: Confirmed via `PRAGMA compile_options` (`ENABLE_FTS5` is present).
- **Licence Check**: 61 packages inspected, 0 disallowed.

## Database Schema
- **Unicode61 Table**:
  ```sql
  CREATE VIRTUAL TABLE notes_fts USING fts5(
    path,
    body,
    tokenize = 'unicode61 remove_diacritics 2'
  );
  ```
- **Trigram Table**:
  ```sql
  CREATE VIRTUAL TABLE notes_trigram USING fts5(
    path,
    body,
    tokenize = 'trigram'
  );
  ```

## Ingestion Performance (10,000 Notes)
Each row contains `path: note-<i>.md` and 150–450 deterministic words generated with `Random(1)`, containing `topic<i % 100>`, with 2% containing `quick brown fox` and 1% containing `বাংলা লেখা`.

| Platform & Mode | unicode61 Insert Time | trigram Insert Time | Notes |
|---|---|---|---|
| **Windows 11 (Profile Mode)** | **12,235.3 ms** (~12.2s) | **21,797.7 ms** (~21.8s) | Single transaction |
| **Android x86_64 Emulator (Debug Mode)** | ~1,471,080 ms (~24.5 min)* | N/A (unbatched loop) | *Marked `emulator/debug — not valid for the gate`. Debug isolate IPC overhead with 10k awaits; batching in chunks or `INSERT INTO ... SELECT` eliminates this overhead. |

## Query Performance (10,000 Notes)
5 runs per query, keeping median and maximum latencies. Target budget: **< 50 ms**.

### unicode61 Tokenizer Results
| Query | Expected Matches | Windows Profile Median (ms) | Windows Profile Max (ms) | Android Emulator Debug* Median (ms) | Android Emulator Debug* Max (ms) |
|---|---|---|---|---|---|
| `topic42` | 100 | **2.29 ms** | 11.32 ms | 129.19 ms | 210.45 ms |
| `quick AND brown` | 189 | **2.58 ms** | 14.99 ms | 180.19 ms | 245.80 ms |
| `"quick brown fox"` | 189 | **5.71 ms** | 16.54 ms | 159.35 ms | 215.12 ms |
| `top*` | 200 | **8.83 ms** | 16.05 ms | 299.85 ms | 350.21 ms |
| `বাংলা` | 106 | **3.25 ms** | 9.73 ms | 130.07 ms | 185.34 ms |
| `লেখা` | 106 | **2.13 ms** | 5.67 ms | 112.10 ms | 160.42 ms |
| `topic7 OR topic8` | 200 | **4.87 ms** | 14.52 ms | 231.24 ms | 310.88 ms |
| `topic2 NOT topic3` | 100 | **1.65 ms** | 4.85 ms | 163.76 ms | 220.15 ms |

*\*Android figures marked `emulator/debug — not valid for the gate`.*

### trigram Tokenizer Results (Windows Profile)
| Query | Expected Matches | Median Latency | Max Latency | Substring Match Notes |
|---|---|---|---|---|
| `topic42` | 100 | **4.27 ms** | 11.21 ms | Standard match |
| `quick AND brown` | 189 | **3.91 ms** | 8.33 ms | Standard match |
| `"quick brown fox"` | 189 | **6.86 ms** | 10.59 ms | Phrase match |
| `বাংলা` | 106 | **2.22 ms** | 5.98 ms | Full word match |
| `লেখা` | 106 | **1.70 ms** | 3.53 ms | Full word match |
| `ংলা` | 106 | **2.22 ms** | 3.48 ms | **Substring match inside `বাংলা`** |

## Non-Latin & Bangla Substring Search Findings
1. **Unicode61 Tokenizer**:
   - Handles Bengali words `বাংলা` and `লেখা` correctly when searched as whole tokens or prefixes (`ংলা*`).
   - Does not match mid-word substrings without prefixes.
2. **Trigram Tokenizer**:
   - Successfully matches the mid-word substring `ংলা` with **106 matches** in **2.22 ms median**.
   - Trigram insertion takes ~1.8x longer than unicode61, but query times remain well under 7 ms.

## Architecture & Implementation Decisions for Phase 2
1. **FTS5 Strategy**:
   - `drift_flutter` out of the box bundles SQLite with FTS5 on both Windows and Android without requiring manual compilation or legacy `sqlite3_flutter_libs`.
   - Batching must be used during bulk reindexing (e.g., chunks of 100–500 rows) to avoid isolate communication bottleneck on mobile.
2. **Tokenizer Choice**:
   - Default to `unicode61 remove_diacritics 2` for general full-text search.
   - For CJK or arbitrary substring search requirements, SQLite trigram tokenizer is fully functional and performs within budget.

## Conclusion
- **Windows**: **PASS**. All query medians are between **1.65 ms and 8.83 ms**, substantially outperforming the < 50 ms budget (5x–25x faster).
- **Android**: Benchmarked on emulator debug mode; physical phone profile mode test pending hardware connection.
