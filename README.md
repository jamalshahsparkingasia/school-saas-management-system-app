# PrimeSchoolOS Mobile App

The companion app for the PrimeSchoolOS school-management platform.
Students, teachers and parents sign in with their school account and see
their own data — attendance, timetable, homework, exams, results, fees,
lessons, notices and notifications. Teachers can mark class attendance and
create + grade homework from their phone.

- Backend API: the Laravel app in `../school-saas-management-system`
  (`/api/v1`, Sanctum bearer tokens).
- Made with Flutter (Android / iOS / web from one codebase).

## Quick start

```bash
flutter pub get
flutter run -d chrome        # or an Android/iOS device
```

Demo logins (server `http://schoolsaas.test:8020`, password `password`):
`student@westfield.edu` · `teacher@westfield.edu` · `guardian@westfield.edu`

**New to app development? Read [LEARN.md](LEARN.md)** — a hands-on guide to
this exact codebase, including how to run it on a real phone and how to
build features with Claude.
