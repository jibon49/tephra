// © 2026 Tephra. All rights reserved.

import 'package:tephra_sync/tephra_sync.dart';
import 'package:test/test.dart';

void main() {
  group('mergeMarkdown frontmatter-aware merge', () {
    test('different keys changed merges cleanly and body merges', () {
      const base = '''---
title: Original
author: Alice
tags: [note]
---
# Original Heading

Body text.
''';

      const local = '''---
title: Local Title
author: Alice
tags: [note]
---
# Local Heading

Body text.
''';

      const remote = '''---
title: Original
author: Bob
tags: [note, sync]
---
# Original Heading

Body text.
Extra remote text.
''';

      final outcome = mergeMarkdown(base, local, remote);
      expect(outcome.isClean, isTrue);

      final merged = outcome.text!;
      expect(merged, contains('title: Local Title'));
      expect(merged, contains('author: Bob'));
      expect(merged, contains('tags: [note, sync]'));
      expect(merged, contains('# Local Heading'));
      expect(merged, contains('Extra remote text.'));
    });

    test('same key changed differently produces conflict', () {
      const base = '''---
title: Original
---
# Note
''';

      const local = '''---
title: Changed by Alice
---
# Note
''';

      const remote = '''---
title: Changed by Bob
---
# Note
''';

      final outcome = mergeMarkdown(base, local, remote);
      expect(outcome.isClean, isFalse);
    });

    test('key removed on one side is cleanly removed', () {
      const base = '''---
title: Note
deprecated_field: old_value
tags: [test]
---
Content
''';

      const local = '''---
title: Note
deprecated_field: old_value
tags: [test, v2]
---
Content
''';

      const remote = '''---
title: Note
tags: [test]
---
Content
''';

      final outcome = mergeMarkdown(base, local, remote);
      expect(outcome.isClean, isTrue);
      expect(outcome.text, contains('tags: [test, v2]'));
      expect(outcome.text, isNot(contains('deprecated_field')));
    });

    test('comments in local YAML frontmatter are preserved', () {
      const base = '''---
title: Original
status: draft
---
# Note
''';

      const local = '''---
# Local editor comment explaining the title
title: Original
status: draft
---
# Note
''';

      const remote = '''---
title: Original
status: published
---
# Note
''';

      final outcome = mergeMarkdown(base, local, remote);
      expect(outcome.isClean, isTrue);
      expect(
        outcome.text,
        contains('# Local editor comment explaining the title'),
      );
      expect(outcome.text, contains('status: published'));
    });

    test('invalid YAML falls back to plain line merge', () {
      const base = '''---
title: Valid
---
# Heading

Original line.
''';

      const local = '''---
: invalid [ YAML {
---
# Heading

Original line.
''';

      const remote = '''---
title: Valid
---
# Heading

Original line.
Added line.
''';

      // Local has invalid YAML syntax. Should fall back to plain merge3.
      // Since local edited line 2 and remote edited line 7, line merge succeeds cleanly.
      final outcome = mergeMarkdown(base, local, remote);
      expect(outcome.isClean, isTrue);
      expect(outcome.text, contains(': invalid [ YAML {'));
      expect(outcome.text, contains('Added line.'));

      // If both edit the same line in invalid YAML, line merge detects a conflict
      const remoteConflicting = '''---
: other invalid [ YAML }
---
# Heading

Original line.
''';
      final outcomeConflict = mergeMarkdown(base, local, remoteConflicting);
      expect(outcomeConflict.isClean, isFalse);
    });

    test('clean merge when no side modified frontmatter', () {
      const base = '''---
title: Fixed Title
---
Section 1

Section 2
''';

      const local = '''---
title: Fixed Title
---
Section 1 edited locally

Section 2
''';

      const remote = '''---
title: Fixed Title
---
Section 1

Section 2 edited remotely
''';

      final outcome = mergeMarkdown(base, local, remote);
      expect(outcome.isClean, isTrue);
      expect(outcome.text, startsWith('---\ntitle: Fixed Title\n---\n'));
      expect(outcome.text, contains('Section 1 edited locally'));
      expect(outcome.text, contains('Section 2 edited remotely'));
    });
  });
}
