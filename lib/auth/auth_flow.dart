import '../enrollment/enrollment_repository.dart';
import '../enrollment/enrollment_screens.dart';
import '../learner/learner_dashboard_screen.dart';
import '../learner/learner_courses_repository.dart';
import '../admin/admin_courses_repository.dart';
import '../profile/profile_repository.dart';
import '../profile/profile_screen.dart';
import '../admin/admin_learners_repository.dart';

import 'package:flutter/material.dart';

import '../registration/registration_repository.dart';
import '../registration/registration_screen.dart';
import 'sign_in_preferences.dart';
import 'sign_in_repository.dart';
import 'sign_in_screen.dart';
import 'recovery_repository.dart';
import 'recovery_screen.dart';
import '../admin/admin_dashboard_repository.dart';
import '../admin/admin_dashboard_screen.dart';

class AuthFlow {
  AuthFlow({
    this.enrollments,
    required this.registration,
    required this.signIn,
    required this.preferences,
    required this.recovery,
    required this.adminDashboard,
    this.adminCourses,
    this.learnerCourses,
    required this.profile,
    required this.adminLearners,
    required this.adminLearnerRegistration,
  });
  final EnrollmentRepository? enrollments;
  final RegistrationRepository registration;
  final SignInRepository signIn;
  final SignInPreferences preferences;
  final RecoveryRepository recovery;
  final AdminDashboardRepository adminDashboard;
  final AdminCoursesRepository? adminCourses;
  final LearnerCoursesRepository? learnerCourses;
  final ProfileRepository profile;
  final AdminLearnersRepository adminLearners;
  final RegistrationRepository Function(UserSession) adminLearnerRegistration;
  Future<UserSession> _editProfile(
    BuildContext context,
    UserSession session,
  ) async {
    var updated = session;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileScreen(
          repository: profile,
          enrollmentContent:
              enrollments == null || session.role != AccountRole.learner
              ? null
              : EnrollmentPanel(repository: enrollments!, actor: session),
          session: session,
          onSaved: (value) => updated = value,
          onSecurity: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => RecoveryScreen(repository: recovery),
            ),
          ),
        ),
      ),
    );
    return updated;
  }

  void _signOut(BuildContext context) => Navigator.of(context)
      .pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => signInScreen()),
        (_) => false,
      );

  Widget signInScreen() => Builder(
    builder: (context) => SignInScreen(
      repository: signIn,
      preferences: preferences,
      onForgotPassword: () async {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => RecoveryScreen(repository: recovery),
          ),
        );
      },
      onRegister: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => RegistrationScreen(
            repository: registration,
            onSignIn: () => Navigator.of(context).pop(),
          ),
        ),
      ),
      onSignedIn: (session, warning) =>
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute<void>(
              builder: (context) => session.role == AccountRole.admin
                  ? AdminDashboardScreen(
                      onAddLearner: (actor) async =>
                          await Navigator.of(context).push<bool>(
                            MaterialPageRoute<bool>(
                              builder: (routeContext) => RegistrationScreen(
                                repository: adminLearnerRegistration(actor),
                                adminMode: true,
                                onCreated: () =>
                                    Navigator.of(routeContext).pop(true),
                              ),
                            ),
                          ) ??
                          false,
                      enrollmentsRepository: enrollments,
                      learnersRepository: adminLearners,
                      coursesRepository: adminCourses,
                      repository: adminDashboard,
                      session: session,
                      onEditProfile: (value) => _editProfile(context, value),
                      warning: warning,
                      onSignOut: () => _signOut(context),
                    )
                  : LearnerDashboardScreen(
                      enrollmentsRepository: enrollments,
                      repository: learnerCourses,
                      profileRepository: profile,
                      session: session,
                      onEditProfile: (value) => _editProfile(context, value),
                      warning: warning,
                      onSignOut: () => _signOut(context),
                    ),
            ),
            (_) => false,
          ),
    ),
  );
}
