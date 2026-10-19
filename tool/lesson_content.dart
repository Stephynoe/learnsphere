// Each module has a reading, a practical task, and a review with answer guidance.
const moduleContent = <List<String>>[
  [
    'Flutter builds interfaces from widgets. Use a Row for horizontal siblings, a Column for vertical siblings, and Padding for space around a child. Extract a CourseCard widget with final title and instructor properties when the same layout appears in several places. Keep data loading outside its build method: Flutter may call build repeatedly. A ListView.builder creates visible course cards on demand instead of laying out an entire catalog at once.',
    'Build a CourseCard with a title, instructor, and a View course button. Display three cards using ListView.builder. Extract the card into a StatelessWidget and pass an onTap callback from the parent. Try a two-line title and a missing instructor. Deliver the widget and screenshots showing both cases; use a readable fallback for missing text.',
    'Why should an HTTP request stay outside build? When would a StatelessWidget be enough for CourseCard? Review: build can run repeatedly, so requests there can duplicate work. A card whose display comes entirely from constructor properties needs no mutable local state. Confirm that tapping each card invokes its own callback.',
  ],
  [
    'Keep state with the widget that owns a decision. A course filter can store the selected category in a StatefulWidget and call setState when it changes. Pass the selected course to a details route with Navigator.push. The returned Future completes when that route closes; await it before refreshing progress. After an asynchronous operation, check mounted before using a State context. Represent loading, success, and failure separately so an empty list does not hide an error.',
    'Add category filtering to a catalog. Open a details route with Navigator.push and return a changed flag using Navigator.pop(context, true). Refresh only when that flag is true. Simulate a failed refresh and keep the existing cards visible alongside Retry. Test closing the page while a delayed request is running.',
    'Does setState persist data after restart? Why check mounted after await? Review: setState schedules a rebuild of in-memory state; persistence requires a separate store. mounted confirms the State still belongs to the widget tree. Describe how you distinguish no courses from a failed request.',
  ],
  [
    'Flutter constraints flow down the widget tree and sizes flow up. A Row with long text can overflow unless the text receives bounded width, for example through Expanded. Use LayoutBuilder to choose a layout from the available width rather than a device name. A catalog can use one column on a narrow panel and a grid on a wide panel. Text scaling and keyboard insets also change usable space; avoid fixed heights around paragraphs and forms.',
    'Adapt the catalog for widths of 360 and 1280 logical pixels. Use LayoutBuilder to switch between a list and a grid. Put long card titles in constrained text, and test at large text scale. Deliver both layouts with no overflow indicators and buttons that remain reachable when a keyboard opens.',
    'Why can a Row overflow even inside a wide screen? Review: unconstrained text may request more horizontal space than its siblings leave. Explain when Expanded helps and when a vertical layout is clearer. Check both a narrow parent panel and a full-width desktop window.',
  ],
  [
    'Dart distinguishes nullable and non-nullable types: String? may contain null, while String may not. Use a List for ordered values, a Set for unique lesson IDs, and a Map for keyed fields. Prefer explicit models at boundaries rather than repeated dynamic casts. For example, completedIds.toSet() removes duplicate completion IDs, but validation must still reject IDs that are absent from the curriculum.',
    'Write a function that accepts a list of lesson IDs and returns unique nonblank IDs in their original order. Test an empty list, repeated IDs, and whitespace-only entries. Then model a learner with an integer ID, a required name, and an optional organization. Show how the UI displays a missing organization.',
    'How do List and Set differ? What does String? permit? Review: lists retain order and duplicates; sets enforce uniqueness. A nullable string permits null as well as strings, including an empty string. Explain why null checks alone do not reject blank names.',
  ],
  [
    'A Future represents a result available later. await pauses an async function until that Future completes; it does not block the entire application. Independent reads can use Future.wait, while dependent operations must remain ordered. Always await writes whose success affects navigation. A timeout stops waiting for a response but does not prove that a remote write failed to happen.',
    'Create an async catalog loader that waits 300 milliseconds before returning two titles. Add a failure mode and handle it with try/catch. Next load two independent datasets with Future.wait. Compare elapsed time with sequential awaits. For a simulated uncertain save, show a refresh action instead of automatically repeating the write.',
    'When is Future.wait appropriate? Does a timeout guarantee that the server rejected a write? Review: parallelize independent work; preserve ordering when one result is required by the next operation. A response may be lost after the server commits, so read back before retrying an uncertain mutation.',
  ],
  [
    'Separate invalid input from transport failure. FormatException can represent malformed data; a domain exception can describe an action the user cannot complete. Catch exceptions where you can recover or translate them into useful UI state. Use finally to release resources such as an HTTP client. Avoid catching every error and returning an empty list: that makes broken storage look like a valid empty catalog.',
    'Parse a JSON-like course record and reject a missing title or non-list modules field. Translate a network failure into a retryable message without printing credentials. Test malformed data and a valid empty catalog separately. Close your injected client in a finally block or test teardown.',
    'Why is returning [] from every catch misleading? Review: callers lose the difference between failure and a successful empty result. Explain which errors can be retried and which require correcting data. Verify that your error output excludes secrets.',
  ],
  [
    'Semantic HTML describes purpose. Use main for the primary content, nav for navigation, and a real button for an action. A link navigates to another resource. Associate every form control with a label using matching for and id attributes. Headings should describe the document outline rather than being chosen only for their visual size. Native controls support keyboard interaction without recreating it in JavaScript.',
    'Author a course catalog page with header, nav, main, and article elements. Each course needs a heading and a details link. Add a search input with an explicit label. Navigate the page using only Tab and Enter; record the focus order and fix any unreachable control.',
    'Should a submit action use a link or a button? Review: use a button for the form action and a link for navigation. Explain why a styled div is a weaker default than a native button. Inspect the heading order without relying on CSS.',
  ],
  [
    'CSS Grid handles two-dimensional layouts; Flexbox aligns items along one main axis. A responsive card grid can use grid-template-columns: repeat(auto-fit, minmax(min(100%, 16rem), 1fr)). The minimum prevents cards from becoming too narrow, while the inner min allows a small container to fit. gap controls spacing between items without adding outer margins. Set box-sizing: border-box so padding is included in declared widths.',
    'Style the catalog as a grid that fits a 320-pixel viewport without horizontal scrolling. Use Flexbox inside each card to align its action after the description. Test one long title and six cards. Deliver the CSS and explain why the breakpoint or minimum width suits the content.',
    'When would Grid be preferable to Flexbox? Review: Grid coordinates rows and columns; Flexbox suits a single row or column. Check that padding does not push a 100%-width element beyond its parent and that long words do not force horizontal scrolling.',
  ],
  [
    'Accessible forms provide labels, instructions, and specific errors. Mark required fields in text as well as markup. Use type=email for an email control, but validate again at the trusted storage boundary. Associate hints and errors with aria-describedby. After an unsuccessful submit, keep entered values and help users reach the first invalid field. Do not communicate errors through red color alone.',
    'Build a learner registration form with name and email. On submit, display an inline explanation for each invalid value and preserve the other field. Add an error summary that links to invalid controls. Test with a keyboard, an empty submit, and a malformed email.',
    'Is browser email validation sufficient for account security? Review: client checks improve usability but can be bypassed. Describe how a label differs from a placeholder and why visible error text is needed in addition to color.',
  ],
  [
    'Python functions make a transformation explicit through parameters and return values. A dictionary maps keys to values, while a list retains an ordered collection. For example, def active_names(users): return [u["name"] for u in users if u.get("active") is True]. This keeps the input unchanged. Validate required keys before a larger pipeline rather than letting a distant KeyError obscure the source record.',
    'Write active_names for three learner dictionaries, including an inactive learner. Add a validation step for missing names and return a new list without modifying the input. Use assert statements for normal, empty, and invalid data. Explain whether invalid records should stop the batch or be reported separately.',
    'What is the difference between print and return? Review: print emits text; return provides a value to the caller. Explain why mutating a list while iterating over it can skip entries, and demonstrate a comprehension that avoids that problem.',
  ],
  [
    'Use pathlib.Path to represent file paths and a with block to close open files. The csv module handles quoted delimiters better than splitting each line on commas. Open CSV text with newline="" and an explicit encoding such as utf-8. Validate headers before processing rows. Write output to a separate path so a failed transformation does not destroy the only copy of the source.',
    'Read learners.csv with csv.DictReader, requiring name and email headers. Trim surrounding whitespace and write a cleaned copy to learners_clean.csv. Test a quoted name containing a comma and a missing email. Keep rejected rows in a separate report with row numbers.',
    'Why is line.split(",") unsafe for CSV? Review: delimiters may appear inside quoted fields. Explain why an explicit encoding and a context manager matter. Verify that your script leaves the original file unchanged on a validation failure.',
  ],
  [
    'An automation workflow needs clear inputs, observable results, and a safe rerun strategy. Separate discovery from changes: first list candidate files, then transform them. Use stable record keys to avoid creating duplicates on repeat runs. A dry run should describe intended writes without performing them. Log counts and failure locations rather than entire sensitive records.',
    'Create a dry-run option for a learner CSV import. Report accepted, rejected, and duplicate rows. Apply to a separate JSON output file only when explicitly requested. Run the same import twice and demonstrate that the second run adds no duplicate learner emails.',
    'What makes an import repeatable? Review: stable identity rules and explicit handling of existing records. Describe what happens if a write fails halfway through and how an operator can determine which changes completed.',
  ],
  [
    'SQL SELECT chooses columns, FROM identifies the table, and WHERE filters rows before grouping. For example: SELECT id, full_name FROM learners WHERE is_active = 1 ORDER BY full_name, id; returns active learners in a stable order. Use IS NULL rather than = NULL to test missing values. Bind parameters for user input instead of concatenating values into query text.',
    'Create a small learners table and insert five fictional rows. Query active learners, names starting with A, and rows with a missing organization. Sort by name and ID. Use a bound parameter for a search value containing an apostrophe and verify the query still works.',
    'Why does organization = NULL fail to select missing values? Review: NULL represents unknown and uses IS NULL. Explain how bound parameters separate data from SQL syntax. Check that ORDER BY resolves ties for consistent pagination.',
  ],
  [
    'JOIN combines related rows through keys. INNER JOIN keeps matching rows; LEFT JOIN retains every left-side row even without a match. SELECT l.id, e.course_id FROM learners l LEFT JOIN enrollments e ON e.learner_id = l.id; includes learners without enrollments. A one-to-many join repeats the learner row for each matching enrollment, so counting joined rows is different from counting distinct learners.',
    'Create learners, courses, and enrollments tables with primary and foreign keys. Include one learner with two enrollments and another with none. Compare INNER JOIN and LEFT JOIN results. List each learner with course titles, retaining the learner with no courses.',
    'Why can a join return more rows than the learners table? Review: one learner may match multiple enrollments. Explain how a WHERE condition on the right-hand table can remove NULL rows from a LEFT JOIN. Use COUNT(DISTINCT l.id) when counting unique learners.',
  ],
  [
    'GROUP BY forms groups before aggregate calculations; HAVING filters the resulting groups. SELECT course_id, COUNT(*) AS enrollment_count FROM enrollments GROUP BY course_id HAVING COUNT(*) >= 2; finds courses with at least two enrollments. With a LEFT JOIN from courses, use COUNT(e.id), not COUNT(*), to show zero for courses with no enrollment rows. Define whether withdrawn enrollments count before writing a report.',
    'Report enrollment counts for every course, including an empty course. Add a second report that excludes withdrawn enrollments without losing zero-count courses. Then calculate average progress per course and document whether the value is a fraction or a percentage.',
    'When should you use HAVING instead of WHERE? Review: WHERE selects input rows; HAVING selects aggregated groups. Explain why COUNT(*) returns one for an unmatched LEFT JOIN row and why COUNT(e.id) returns zero.',
  ],
  [
    'Data cleaning starts with a definition of a valid row. Normalize email casing and surrounding spaces, but keep meaningful internal punctuation. Inspect missing values, duplicate keys, and invalid dates separately. Do not silently replace unknown progress with zero: unknown and not started mean different things. Keep an unchanged source and a record of each transformation so results can be reproduced.',
    'Prepare a 12-row enrollment CSV with duplicate IDs, a missing course ID, and an invalid date. Produce a cleaned dataset and a rejection report. Define the duplicate-selection rule before removing rows. Summarize input rows, accepted rows, and rejected rows so the counts reconcile.',
    'When is filling a missing value with zero misleading? Review: it changes unknown data into a measured value. Explain why duplicate detection needs a business key and why the most recent timestamp must be validated before using it to choose a record.',
  ],
  [
    'Exploratory analysis looks for distributions, unusual values, and relationships before making claims. Compare median and mean course progress: a few unusually high values can move the mean. Segment results by enrollment age because a learner enrolled yesterday has had less time to finish. Always show the number of observations alongside percentages. Correlation between activity and completion does not establish which caused the other.',
    'Using a fictional enrollment table, calculate count, mean, median, minimum, and maximum progress. Compare learners enrolled within seven days with older enrollments. Draw a histogram or frequency table. Identify one outlier and explain whether it is a data error or a plausible case.',
    'Why can an overall average hide a useful pattern? Review: groups may have different sizes or exposure times. Explain why a 100% completion rate from one learner should not be interpreted like 100% from 200 learners. State one limitation of your comparison.',
  ],
  [
    'A useful analysis report connects a question, evidence, and a decision. Label chart axes and units, state the observation period, and show denominators. Use a line chart for a time series and a bar chart for category comparisons. Distinguish observed results from explanations you have not tested. A recommendation should identify an owner and a measurable follow-up rather than promising an unsupported outcome.',
    'Write a one-page report on course completion with one chart and a small summary table. Include the date range, sample size, definition of completion, and treatment of withdrawn enrollments. Recommend one action and a metric to check after four weeks. Ask a peer to identify the main finding in 30 seconds.',
    'What belongs in a chart caption? Review: describe the measure, population, time range, and important exclusions. Rewrite “reminders caused completion to rise” as an observation unless a suitable experiment supports the causal claim.',
  ],
  [
    'User research investigates actual behavior and needs. Ask participants to describe their most recent learning experience rather than predict whether they would use a proposed feature. Avoid leading questions such as “Would a simpler dashboard help?” Record observations separately from interpretations. A small interview sample can reveal problems but cannot establish how common they are across the entire population.',
    'Prepare five neutral interview questions about choosing and finishing an online course. Conduct two practice interviews with consent, using fictional notes if participants are unavailable. Group observations into themes and identify one problem supported by a direct observation. Remove identifying details from your summary.',
    'Why are questions about recent behavior useful? Review: concrete events often reveal constraints that hypothetical preferences miss. Identify the leading phrase in “How much do you love our easy signup?” and rewrite the question neutrally.',
  ],
  [
    'A user flow maps decisions and destinations; a wireframe explores layout before visual polish. For enrollment, map discovery, course details, confirmation, and the first lesson. Include error and return paths, not only the successful path. Low-fidelity sketches make alternatives inexpensive to compare. Labels should tell users what an action does, such as Start lesson rather than a vague Continue when the next step is unclear.',
    'Sketch a course-enrollment flow with a catalog, course details, and a lesson screen. Include already enrolled, unavailable course, and failed-save states. Create two alternatives for the details page. Explain which information must be visible before the learner decides to enroll.',
    'How does a wireframe differ from a user flow? Review: a wireframe shows screen structure; a flow shows movement and decisions between states. Check that your error route preserves the selected course and provides a clear recovery action.',
  ],
  [
    'Usability testing observes people attempting realistic tasks. Give a goal such as “Find a beginner course and locate its first lesson” without naming the buttons to press. Ask participants to think aloud and avoid coaching them through a failure. Record task completion, hesitation, and errors. Prioritize issues by their effect on the task and frequency in the sessions rather than aesthetic preference alone.',
    'Run three practice sessions on your wireframes. Use the same task prompt and record completion without help, time on task, and observed obstacles. Select the two most disruptive issues, revise the design, and write a short follow-up test plan. Do not generalize percentages from three people to all learners.',
    'Why should a moderator avoid pointing at the correct button? Review: assistance hides discoverability problems. Explain the difference between an observed behavior and a participant suggestion. Rank a blocked enrollment above a minor spacing preference.',
  ],
  [
    'A project scope states the intended outcome, deliverables, boundaries, and acceptance criteria. For a learning portal, “support enrollment” is ambiguous until you define who can enroll, which courses qualify, and how success is shown. Break deliverables into manageable tasks and identify dependencies. Record exclusions explicitly so stakeholders can distinguish a missing requirement from work scheduled for another release.',
    'Write a one-page scope for a course-enrollment release. Include an objective, three deliverables, measurable acceptance criteria, exclusions, and dependencies. Estimate each task as a range and name the assumption driving uncertainty. Ask a reviewer to identify one ambiguous requirement.',
    'How does an acceptance criterion differ from a task? Review: a task describes work; a criterion describes observable behavior that proves the outcome. Rewrite “implement enrollment” as a testable statement about a learner enrolling in a published course.',
  ],
  [
    'Delivery planning makes ownership and risk visible. A board with Ready, In progress, Review, and Done columns helps a team see bottlenecks. Limit concurrent work so tasks finish before more tasks start. Record risks with likelihood, impact, owner, and a response. A dependency on access to a test service should be raised before the day the integration is due.',
    'Create a delivery board for the enrollment release with owners and acceptance checks. Add a risk register covering unavailable test data, delayed review, and an unreliable external service. Simulate a two-day dependency delay and revise the plan. Explain which work can continue independently.',
    'Why can starting more tasks slow completion? Review: context switching and blocked work increase work in progress. Distinguish a risk that might occur from an issue already affecting delivery. State an escalation trigger for your highest-impact dependency.',
  ],
  [
    'A project review compares results with the original objective and records what to change next time. Use evidence such as accepted deliverables, escaped defects, and lead time. A retrospective should produce a small number of actions with owners and dates. Separate system improvements from blame: a missing validation checklist is actionable, while calling someone careless rarely improves the process.',
    'Prepare a release review with planned versus delivered scope, two successes, two problems, and supporting evidence. Turn one problem into a process change with an owner and review date. Define how you will tell whether the change helped on the next release.',
    'What makes a retrospective action useful? Review: it is specific, owned, time-bounded, and verifiable. Replace “communicate better” with a concrete practice and a check. Explain why completing tasks alone does not prove the project achieved its intended outcome.',
  ],
  [
    'Phishing attempts pressure people into sharing information or taking an unsafe action. Warning signs include unexpected urgency, mismatched sender domains, requests for passwords, and links whose destination differs from the visible label. A familiar logo is not proof of origin. Verify a request through a known channel by opening the service directly rather than following the message link. Treat unexpected attachments cautiously.',
    'Write three fictional messages: an ordinary course reminder, a password-stealing request, and an urgent payment impersonation. Use example.com addresses and no active malicious links. Annotate warning signs and describe a safe verification step for each suspicious message. Practice reporting it through a fictional organization process.',
    'Does an HTTPS padlock prove a message is trustworthy? Review: HTTPS protects a connection to a domain; it does not establish that the sender is legitimate. Explain why contacting the requester through a known phone number is safer than replying to the suspicious message.',
  ],
  [
    'Unique passwords reduce the damage when one service is compromised. A password manager can generate and store them. Multi-factor authentication adds another check beyond a password; never share one-time codes with someone claiming to be support. Review recovery methods and remove access you no longer need. On shared devices, sign out and avoid saving credentials in the browser.',
    'Create an account-security checklist for a fictional learning platform: unique password, available MFA, recovery options, session review, and shared-device sign-out. Apply it to a mock account only. Describe how you would respond to an unexpected sign-in notification without clicking a link in that notification.',
    'Why is password reuse risky? Review: credentials exposed by one service may be tried elsewhere. Does MFA remove the need to check domains and requests? No; users can still be deceived into approving an action or exposing a session. Identify one recovery method that needs protection.',
  ],
  [
    'Incident response starts with reporting and limiting further exposure through the organization’s established process. Record what happened, when, and which accounts or systems may be affected. Preserve relevant messages and logs; avoid deleting evidence or investigating systems you are not authorized to access. Use a trusted channel to contact support. Follow approved instructions for account recovery and device isolation.',
    'Tabletop scenario: a learner entered a password on a suspicious page. Write the first report with time, affected account, observed behavior, and evidence available. Describe who should receive it and which account-protection steps require the official recovery process. Do not include the password itself in the report.',
    'Why preserve the suspicious message? Review: investigators may need its sender details and destination to assess impact. Explain the difference between a confirmed fact and a suspicion in an incident report. Identify the escalation contact before making changes to a managed device.',
  ],
  [
    'A clear written update leads with the outcome or request, then gives the context needed to act. Name the owner and deadline when asking for a decision. Replace vague phrases such as “soon” with a date or a specific dependency. For a blocked release, state the impact, what has been tried, and what help is needed. Keep background material after the main point.',
    'Rewrite this update: “We are still working on things and might finish soon.” Use a fictional enrollment release with one completed item, one blocker, and a decision required by Friday. Keep it under 120 words. Ask a peer to identify the status and requested action without additional explanation.',
    'What information does “Please review” omit? Review: name the item, the kind of feedback needed, the reviewer, and the deadline. Distinguish a status update from a request for approval and write an example of each.',
  ],
  [
    'Active listening checks understanding before responding. Let the speaker finish, summarize the key point in your own words, and ask an open question about uncertainty. Acknowledge a concern without assuming agreement on the proposed solution. In a requirements conversation, separate the underlying need from a requested feature: “I lose my place” may indicate a resume problem rather than a need for another dashboard.',
    'Role-play a learner describing difficulty returning to unfinished lessons. The listener must summarize the problem and ask two open questions before suggesting a solution. Swap roles and record one assumption corrected by listening. Produce a short problem statement using only what the speaker confirmed.',
    'How is paraphrasing different from agreeing? Review: paraphrasing checks meaning; agreement endorses a view. Rewrite “You just need a better dashboard, right?” as an open question. Explain how interrupting with a solution can hide the actual problem.',
  ],
  [
    'Constructive feedback describes an observable behavior, its effect, and a useful next step. Keep feedback specific: “The update omitted the deployment date, so support could not prepare” is more actionable than “Your communication is bad.” Invite the other person’s context and agree on a change. Offer feedback privately when the issue concerns an individual, and recognize concrete improvements in follow-up.',
    'Write feedback for a fictional teammate whose release notes omit known limitations. Include the observed example, its effect on users, an open question, and a proposed improvement. Then write the teammate’s possible response and revise the plan to account for a time constraint. Avoid labels about personality or intent.',
    'Why should feedback name behavior rather than personality? Review: behavior can be discussed and changed; personality labels are broad and hard to act on. Turn “be more professional” into a specific request and define how you would follow up respectfully.',
  ],
];

String lessonContent(int course, int module, int lesson) =>
    moduleContent[course * 3 + module][lesson];

// Exact v1 text is retained only to recognize untouched demo lessons on update.
String originalLessonContent(
  String course,
  String topic,
  int lesson,
) => switch (lesson) {
  0 =>
    '$topic is a core skill in $course. Start by defining the intended outcome and the constraints. Break the work into small steps, check assumptions with a simple example, and review the result against the original goal.\n\nFor a learning portal, identify the user, the action they need to take, and the evidence that the action succeeded. Write down one likely failure and explain how you would detect it. Compare two approaches and describe their tradeoffs.',
  1 =>
    'Create a small worked example demonstrating ${topic.toLowerCase()} for a learning portal.\n1. Define a realistic input and expected outcome.\n2. Produce a draft solution using the concepts from this module.\n3. Try a normal case, an empty case, and an incorrect input.\n4. Record what happened and improve the solution.\nDeliverable: your solution, three observations, and a short explanation of one tradeoff.',
  _ =>
    'Self-check:\n1. Explain ${topic.toLowerCase()} in your own words.\n2. Give one example from a learning portal.\n3. Identify a common mistake and how to prevent it.\n4. Explain how you would verify your work.\nReview guide: a strong answer states a clear goal, uses a concrete example, identifies a plausible failure, and describes an observable check. Revise your answers before marking this lesson complete.',
};
