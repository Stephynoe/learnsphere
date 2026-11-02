# Quizzes and Filters Implementation Plan

**Goal:** Add authored, graded multiple-choice assessments and resettable course discovery filters.

**Architecture:** Optional quiz data lives on assessment lessons; attempts live on enrollments. Grade against the latest stored course inside the existing authorized enrollment mutation. Preserve legacy assessment instructions.

**Tech Stack:** Flutter, Dart, existing JSONBin repositories; no new dependencies.

## Tasks

- [x] Define validated quiz data and grading; test scoring, malformed questions and thresholds.
- [x] Add quiz authoring to the lesson editor with questions, choices, correct answers, explanations and pass percentage.
- [x] Save attempts through enrollment repository; enforce ownership and passing before completion; test failed/passed attempts and bypass prevention.
- [x] Render learner quiz, feedback, history and retry; test learner interaction and persistence.
- [x] Add removable discovery filters, result count and clear-all; verify search reset.
- [x] Run formatting, analysis and full tests; document prototype grading limits.

## Decisions and review focus

- Default pass mark 70%; unlimited retries, one correct answer per question, 2–6 choices.
- Existing assessments without quiz data remain manually completable.
- Failed saves must preserve answers and must not display a saved result.
- Navigation must not carry answers between lessons; use a lesson-specific widget key.
- Record question/answer snapshots so later author edits do not rewrite past feedback.
- No live-bin writes or seed updates are part of this change.

## Validation

- Full `flutter test --no-pub`: 213 tests passed.
- Additional targeted runs verify failed saves, stale quiz rejection, 320px quiz interaction and clearing active filters.
- Final `flutter analyze --no-pub`: no issues; `git diff --check`: clean.
