# LearnSphere - Week 4 Changelog

## 1. Graded quizzes and lesson authoring

- Assessment lessons now support an optional automatically graded quiz.
- Administrators can enable grading in the Lesson Content Editor, set a pass
  mark from 1–100% (default 70%), and add or remove questions.
- Each question created in the editor has four answer choices, one correct
  answer and an explanation shown after submission.
- Validation checks required question text, distinct nonblank choices, correct
  answer selection and explanations. Quizzes require at least one question and
  support up to 50 questions.
- Existing instruction-only assessments retain manual lesson completion.

## 2. Learner scores, feedback and saved attempts

- Learners must answer every question before submitting a quiz.
- Results show the number correct, percentage, pass status, selected answers,
  correct answers and explanations.
- Passing completes the assessment lesson and updates course progress. A failed
  attempt leaves the lesson incomplete unless it was already completed.
- Learners can retry without an attempt limit and view saved attempt scores.
- Attempts are stored with the enrolment, including submission time and a
  snapshot of the questions and answers used for feedback.
- Administrators can expand **Quiz results** on an enrolment to inspect scores,
  pass status and selected answers for each question.

## 3. Quiz submission safeguards

- Submissions use the existing active-account and enrolment ownership checks.
  Administrators cannot submit quizzes on behalf of learners, and withdrawn
  enrolments cannot submit attempts.
- A graded assessment cannot be completed through the manual completion action.
- Answers are graded against the stored course definition. If the quiz changes
  while a learner is answering, submission asks the learner to refresh.
- Failed saves show an error instead of displaying a successful saved result;
  the learner's selected answers remain available while the quiz is displayed.
- Pass status uses the unrounded score, even though the displayed percentage is
  rounded. For example, two correct answers out of three do not meet a 70% pass
  mark.

## 4. Course search and filter improvements

- Home and Explore show the number of matching courses.
- Active category and difficulty filters appear as removable chips below search.
- **Clear all** resets the current tab's search text, category and difficulty.
- The **No matching courses** state includes **Clear search and filters** to
  restore the course list directly.
- Home and Explore retain separate search and filter state.

## 5. Demo content and repository housekeeping

- Created `misc/demo_course_content.txt` for a copy-and-paste demo course,
  **Write Clear Workplace Emails**, with an article, practical lab, three-question
  quiz and recording notes for failed and passed attempts.
- The `misc/` directory is local-only and ignored by Git. Its previously tracked
  helper files were removed from the index while retaining the local copies.
- Added ignore rules for local environment files, signing keys, local test
  reports and Flutter's legacy plugin metadata. Environment example files remain
  eligible for version control.
- Updated the README with quiz instructions, filter behaviour and Week 4 notes.

## 6. Verification

- The full Flutter test run passed all 213 tests at that stage of development.
- Subsequent targeted runs passed for quiz grading, failed saves, stale quiz
  rejection, enrolment access, narrow-screen interaction and filter reset.
- `flutter analyze --no-pub` completed with no issues.
- Git ignore checks confirmed local demo content and secret-file patterns are
  ignored while environment examples and `pubspec.lock` remain eligible for
  version control.

## 7. Current limitations

- Quiz definitions and grading remain client-side within the JSONBin prototype;
  this is not a secure examination system.
- Quizzes use single-answer multiple-choice questions. Timed exams, question
  randomisation and certificates are not included.
- Existing text assessments are not automatically converted into quizzes.
- Demo content is local-only and must be entered through the course editor; it
  does not update live courses automatically.
