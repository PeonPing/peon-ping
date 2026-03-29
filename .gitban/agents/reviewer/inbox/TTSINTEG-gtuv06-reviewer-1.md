---
verdict: APPROVAL
card_id: gtuv06
review_number: 1
commit: 615573d
date: 2026-03-28
has_backlog_items: false
---

## Summary

Clean extract-method refactor that pulls category-to-key mapping out of `Resolve-NotificationTemplate` into a standalone `Resolve-TemplateKey` helper. The motivation is preparing a shared mapping for TTS text resolution (per ADR-001) without duplicating the mapping when TTS lands. The diff is small, focused, and behavior-preserving.

## Assessment

### Refactoring correctness

The extraction is mechanically sound. `Resolve-TemplateKey` receives the three inputs that drive key selection (`$Category`, `$Event`, `$Ntype`) and returns the resolved key string or null. `Resolve-NotificationTemplate` delegates to it with the same parameters, then continues with template variable substitution. The before/after behavior is identical -- no logic was added, removed, or reordered during extraction.

The function placement is correct: `Resolve-TemplateKey` is defined before `Resolve-NotificationTemplate`, which calls it. PowerShell requires this ordering for functions defined in the same scope.

### ADR compliance

ADR-001 specifies that speech text resolution happens centrally in the hook pipeline (PowerShell block for Windows), and that the category-to-key mapping is shared between notification templates and TTS text resolution. This refactor establishes that shared mapping as a callable function, directly supporting ADR-001's implementation notes (step 4: "Add speech text resolution... template interpolation using existing machinery").

### TDD evaluation

The 6 new Pester tests cover the full surface of `Resolve-TemplateKey`: all 5 mapped keys (`stop`, `error`, `idle`, `question`, `permission`) and the null-return boundary case for unmapped categories. The tests exercise the function through its public interface with realistic inputs (correct event names, correct notification types). The null case is particularly important -- it ensures the caller's fallback-to-default logic activates correctly.

The card reports baseline tests passed before refactoring (360/360 + 20/20) and after (360/360 + 26/26), with zero existing test modifications required. This is the expected outcome for a pure extract-method refactor.

### Code quality

The function is small (~24 lines including param block), single-purpose, and follows existing PowerShell naming conventions (`Resolve-*` verb-noun). The inline comment noting it is shared between notification and TTS subsystems provides sufficient context for future readers. The `$keyMap` hashtable is the same structure used throughout the codebase.

### Checkbox audit

All checked boxes on the card are truthful. The card correctly marks documentation updates as N/A (internal helper function, no external-facing docs). The "both notification and TTS subsystems use the shared helper" success criterion is partially met -- notification uses it now, TTS will use it when that card lands. This is acceptable for a preparatory refactor.

## BLOCKERS

None.

## FOLLOW-UP

**L1: Regex extraction in test is fragile but acceptable.** The test extracts `Resolve-TemplateKey` via `(?ms)(function Resolve-TemplateKey \{.+?\n\})` regex. This works because the function body currently uses only single-line `{ }` blocks. If someone later adds a multi-line block with a bare `}` on its own line inside the function, the non-greedy match would under-capture. This matches the pragmatic test style of the codebase and is not blocking, but worth noting for awareness if the function grows.
