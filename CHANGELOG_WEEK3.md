# LearnSphere - Week 3 Changelog

## 1. Screens that load data from JSON
- Home and Explore Courses (lib/learner/learner_dashboard_screen.dart):
  courses are loaded from an online JSON store (JSONBin) through
  JsonBinLearnerCoursesRepository (lib/learner/learner_courses_repository.dart).
  The repository checks the learner's access first, and only published
  courses are shown.
- Course cards show title, category, instructor, difficulty, duration and a
  thumbnail (with a fallback icon if the image fails).
- Search by title, headline, category or instructor, plus category chips and
  a filter sheet for category and difficulty.
- Course Details (opens when a course card is tapped): title, headline,
  instructor, category, difficulty, duration, description, learning
  objectives and curriculum, all taken from the loaded course data. When the
  enrolment service is connected, the enrolment version of the screen
  (lib/enrollment/enrollment_screens.dart) opens for the same course.
- Home shows enrolment counts (In Progress, Completed) from enrolment data.

## 2. Forms and validation
- Sign In (lib/auth/sign_in_screen.dart): required-field checks.
- Registration (lib/registration/registration_screen.dart): email, username
  and password rules (RegistrationValidation).
- Password Recovery (lib/auth/recovery_screen.dart): validated input.
- Admin Create/Edit Course (lib/admin/admin_courses_screen.dart): required
  fields and a numeric check.
- Example messages: [ADD THE EXACT MESSAGES YOU SAW WHILE TESTING]

## 3. Loading and error handling
- A loading spinner shows while courses load. The refresh button is disabled
  during loading, and pull-to-refresh is supported.
- If loading fails, a message and a Retry button appear. Known errors show
  their own message, otherwise: "Unable to load courses. Please try again."
- Enrolment errors are shown separately and do not block the course list.
- Empty states: "No published courses yet" and "No matching courses".
- Spinners also appear on Sign In, Registration, Recovery and Profile.
- try/catch with custom errors (SignInException, RecoveryException,
  JsonBinException) in controllers and repositories.

## 4. Known limitations
- Notifications, Saved courses and Weekly goal show "coming soon".
- The "Logged" and "Day Streak" statistics show a dash.

## 5. Documentation
- README updated with Week 3 notes.
- Prepared by:Team 2

## What changed in Week 3
- Home, Explore and Course Details now load data from a JSON store (JSONBin).
- Forms with validation: Sign In, Registration, Password Recovery, Admin Course.
- Loading spinners, error messages with Retry, and empty states.
- Full details: see CHANGELOG_WEEK3.md