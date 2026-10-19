import 'enrollment/enrollment_repository.dart';
import 'learner/learner_courses_repository.dart';
import 'admin/admin_courses_repository.dart';
import 'profile/profile_repository.dart';
import 'admin/admin_learners_repository.dart';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'registration/registration_repository.dart';
import 'data/jsonbin_stores.dart';
import 'auth/auth_flow.dart';
import 'auth/sign_in_preferences.dart';
import 'auth/sign_in_repository.dart';
import 'auth/recovery_repository.dart';
import 'admin/admin_dashboard_repository.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({
    super.key,
    this.repository,
    this.signInRepository,
    this.preferences,
    this.recoveryRepository,
    this.adminDashboardRepository,
    this.profileRepository,
    this.adminLearnersRepository,
    this.adminCoursesRepository,
    this.learnerCoursesRepository,
    this.adminLearnerRegistration,
    this.enrollmentsRepository,
  });
  final EnrollmentRepository? enrollmentsRepository;
  final RegistrationRepository? repository;
  final SignInRepository? signInRepository;
  final SignInPreferences? preferences;
  final RecoveryRepository? recoveryRepository;
  final AdminDashboardRepository? adminDashboardRepository;
  final ProfileRepository? profileRepository;
  final AdminLearnersRepository? adminLearnersRepository;
  final AdminCoursesRepository? adminCoursesRepository;
  final LearnerCoursesRepository? learnerCoursesRepository;
  final RegistrationRepository Function(UserSession)? adminLearnerRegistration;
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final http.Client _client = http.Client();
  late final JsonBinStores _stores = JsonBinStores(client: _client);
  late final RegistrationRepository _repository =
      widget.repository ??
      JsonBinRegistrationRepository(client: _client, store: _stores.users);
  late final AuthFlow _flow = AuthFlow(
    enrollments:
        widget.enrollmentsRepository ??
        JsonBinEnrollmentRepository(
          _stores.enrollments,
          _stores.users,
          _stores.courses,
        ),
    learnerCourses:
        widget.learnerCoursesRepository ??
        JsonBinLearnerCoursesRepository(_stores.courses, _stores.users),
    adminCourses:
        widget.adminCoursesRepository ??
        JsonBinAdminCoursesRepository(_stores.courses, _stores.users),
    adminLearnerRegistration:
        widget.adminLearnerRegistration ??
        (session) => JsonBinRegistrationRepository(
          client: _client,
          store: _stores.users,
          administrator: session,
        ),
    adminLearners:
        widget.adminLearnersRepository ??
        JsonBinAdminLearnersRepository(_stores.users),
    registration: _repository,
    profile:
        widget.profileRepository ?? JsonBinProfileRepository(_stores.users),
    signIn: widget.signInRepository ?? JsonBinSignInRepository(_stores.users),
    preferences: widget.preferences ?? LocalSignInPreferences(),
    recovery:
        widget.recoveryRepository ?? JsonBinRecoveryRepository(_stores.users),
    adminDashboard:
        widget.adminDashboardRepository ??
        JsonBinAdminDashboardRepository(_stores.users),
  );
  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.fromSeed(seedColor: const Color(0xFFF97316))
        .copyWith(
          primary: const Color(0xFFF97316),
          onPrimary: Colors.white,
          surface: const Color(0xFFF9F9FF),
        );
    return MaterialApp(
      title: 'LearnSphere',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colors,
        scaffoldBackgroundColor: colors.surface,
        fontFamily: 'Plus Jakarta Sans',
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          errorMaxLines: 3,
          contentPadding: const EdgeInsets.all(16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFF97316), width: 2),
          ),
        ),
      ),
      home: _flow.signInScreen(),
    );
  }
}
