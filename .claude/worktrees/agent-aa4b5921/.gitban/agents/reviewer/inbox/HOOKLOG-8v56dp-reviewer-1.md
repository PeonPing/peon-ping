---
verdict: APPROVAL
card_id: 8v56dp
review_number: 1
commit: 8f67b4b
date: 2026-03-26
has_backlog_items: false
---

## Review: step-8a-sync-debugging-docs-to-readme-ja-and-readme-ko

This is a documentation-only card that adds translated Debugging sections to README_ja.md and README_ko.md, matching the section already present in README.md and README_zh.md.

### Assessment

**Structure and placement.** Both translations insert the Debugging section between Sound packs and Uninstall, exactly matching the ordering in README.md (line 1092) and README_zh.md. Section headings in README_ja.md (line 1083) and README_ko.md (line 715) confirm correct placement.

**Content fidelity.** Both translations reproduce all six subsections from the English source: intro paragraph, "Enabling debug logs", "Reading logs", "Log format", "Common failure examples", and "Config keys". Every CLI command (`peon debug on/off/status`, `peon logs` variants), every code block (log format examples), every table row (failure symptoms, config keys), and every technical identifier (`inv`, `PEON_DEBUG=1`, phase names) is preserved verbatim. Only the natural-language prose is translated.

**Translation quality.** The Japanese translation uses appropriate technical register (e.g., katakana for loanwords like "デバッグ", "フック", "フィルタ") and the Korean translation uses standard technical Korean (e.g., "디버그 로그", "훅 호출"). Both are consistent with the style established in the rest of their respective README files.

**Checkbox integrity.** All checked boxes on the card are truthful. The four documentation tasks, section placement verification, and quality standards are all confirmed by the diff.

**TDD proportionality.** This is a pure documentation change -- no runtime behavior is altered. No tests are required.

### Close-out

No outstanding actions. The diff is clean and complete.
