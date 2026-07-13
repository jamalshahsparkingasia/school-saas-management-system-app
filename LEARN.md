# Learn App Development with Your Own App

This guide teaches you Flutter using **this actual codebase** — the PrimeSchoolOS
mobile app for students, teachers and parents. No toy examples: every concept
points at a real file you can open, change, and see the result.

> **How to use this guide:** read a section, open the file it mentions, change
> something small, hot-reload, watch what happens. That loop — read, change,
> see — is how app development is learned. Claude is your pair programmer for
> every step (see the last section for how to ask well).

---

## 1. The big picture

Your system now has two halves:

```
┌─────────────────────┐        HTTPS (JSON)         ┌──────────────────────┐
│   The Flutter app    │  ──────────────────────▶   │  The Laravel server   │
│  (this folder)       │   GET /api/v1/student/...  │  (school-saas-...)    │
│                      │  ◀──────────────────────   │                       │
│  Screens, buttons,   │    {"success":true,        │  Database, security,  │
│  navigation, theme   │     "data":{...}}          │  business rules       │
└─────────────────────┘                             └──────────────────────┘
```

- The **server** owns all the data and all the rules (who may see what).
- The **app** is a beautiful remote control: it asks the server for JSON and
  draws it. The app never talks to the database directly.
- The glue is the **API** — a fixed set of URLs that return predictable JSON.
  Yours lives at `/api/v1/...` and is documented in section 7.

One login = one **token** (a long random string). The app stores it and sends
it with every request as `Authorization: Bearer <token>` — that's how the
server knows who's asking without a password every time.

---

## 2. Flutter in five ideas

**Idea 1 — Everything on screen is a widget.** A button is a widget. A row is
a widget. A whole screen is a widget. Widgets nest inside each other to form a
*widget tree*. Open [lib/screens/login_screen.dart](lib/screens/login_screen.dart)
and read `build()` bottom-up: `TextField`s inside a `Column` inside a
`SingleChildScrollView` inside a `Scaffold`.

**Idea 2 — Two kinds of widgets.**
- `StatelessWidget` — draws itself from what it's given, never changes.
  Example: `StatCard` in [lib/widgets/common.dart](lib/widgets/common.dart).
- `StatefulWidget` — holds values that change while you look at it (typed
  text, a loading spinner). Example: the whole login screen. When state
  changes you call `setState(...)` and Flutter repaints.

**Idea 3 — Hot reload.** While `flutter run` is active, press `r` after saving
a file and the running app updates in about a second, keeping its state. This
is the single biggest reason Flutter is beginner-friendly — experiment freely.

**Idea 4 — One codebase, every platform.** This same folder builds an Android
app, an iPhone app and a web app. You write Dart once.

**Idea 5 — Declarative UI.** You never say "now add a row to the list". You
say "the screen looks like *this* given *this data*", and when the data
changes, Flutter redraws. All our screens are pure functions of API data.

---

## 3. Tour of the codebase (read in this order)

```
lib/
├── main.dart                     ① App entry: theme + "which screen shows?"
├── api/
│   └── api_client.dart           ② EVERY network call goes through here
├── state/
│   └── session.dart              ③ Who is logged in (token, profile, school)
├── screens/
│   ├── login_screen.dart         ④ Your first full screen — read carefully
│   ├── home_shell.dart           ⑤ Bottom tabs, different per role
│   ├── student/…                 ⑥ 7 student screens
│   ├── teacher/…                 ⑦ 4 teacher screens (attendance marking!)
│   ├── parent/…                  ⑧ children dashboard + child detail tabs
│   └── shared/…                  ⑨ notices + notifications (all roles)
└── widgets/
    ├── common.dart               StatCard, StatusChip, EmptyState, ApiFutureView
    └── timetable_view.dart       The weekly timetable (student + teacher share it)
```

The three files marked ②③ plus `ApiFutureView` in `common.dart` are the
**foundation patterns**. Understand those three and you understand the app:

### Pattern A — the API client (`lib/api/api_client.dart`)
One class wraps the `http` package so every request automatically gets the
server URL, the token header, and error handling. Screens write one line:

```dart
final data = await session.api.get('/student/dashboard');
```

### Pattern B — the session (`lib/state/session.dart`)
A `ChangeNotifier` holding the token + user profile. `main.dart` *watches* it:
log in → `notifyListeners()` → the app swaps the login screen for the
dashboard. No navigation code. It also saves the token to device storage so
you stay signed in after closing the app.

### Pattern C — the loading screen (`ApiFutureView` in `lib/widgets/common.dart`)
Every data screen holds a `Future` and hands it to `ApiFutureView`, which
shows a spinner while loading, a "Try again" view on failure, and your content
on success. Open any screen in `lib/screens/student/` — you'll see the same
skeleton every time:

```dart
late Future<Map<String, dynamic>> _future;

@override
void initState() {
  super.initState();
  _future = _load();            // start fetching immediately
}

Future<Map<String, dynamic>> _load() =>
    context.read<Session>().api.get('/student/dashboard');

// build():
ApiFutureView(
  future: _future,
  onRetry: () => setState(() => _future = _load()),
  builder: (context, data) => /* draw the screen from `data` */,
)
```

When you build a new screen, copy this skeleton. It's deliberately the same
everywhere.

---

## 4. Running the app

```bash
cd /Applications/XAMPP/xamppfiles/htdocs/primeschoolos_app

flutter devices          # what can I run on?
flutter run -d chrome    # fastest way to try it (runs in a browser)
```

While it runs: `r` = hot reload, `R` = full restart, `q` = quit.

**Demo logins** (all password `password`, server `http://schoolsaas.test:8020`):

| Role    | Email                    |
|---------|--------------------------|
| Student | student@westfield.edu    |
| Teacher | teacher@westfield.edu    |
| Parent  | guardian@westfield.edu   |

### Running on your real phone

1. The phone can't see `schoolsaas.test` (that name only exists on your Mac).
   Find your Mac's LAN IP (System Settings → Wi-Fi → Details), e.g.
   `192.168.1.20`, and make the Laravel app reachable on it:
   ```bash
   cd ../school-saas-management-system
   php artisan serve --host 0.0.0.0 --port 8020
   ```
2. On the app's login screen tap **Server settings** and enter
   `http://192.168.1.20:8020` (your IP). Phone and Mac must share the Wi-Fi.
3. **Android:** enable Developer Options → USB debugging, plug in, then
   `flutter run`. **iPhone:** you'll need Xcode installed and a free Apple
   developer account (Xcode → open `ios/Runner.xcworkspace`, set your team,
   then `flutter run`).

Building a shareable Android APK: `flutter build apk` → the file lands in
`build/app/outputs/flutter-apk/app-release.apk`.

---

## 5. Exercises (do them in order)

Each exercise is safe: if anything breaks, `git checkout .` inside this folder
puts everything back (commit first: `git add -A && git commit -m "before exercises"`).

**Ex 1 — Change something and see it (5 min).**
In `lib/main.dart`, find `Color(0xFF1C7A5A)` (the fallback theme colour) and
change it to `Color(0xFF7C3AED)` (purple). Hot reload. Log out — the login
screen is purple. Log in as a student — it turns cyan. Why? Read `_theme()`:
the school's own brand colour wins after login.

**Ex 2 — Add a stat to the student dashboard (15 min).**
The `/student/dashboard` response contains `open_loans` (library books out).
Find where the `StatCard`s are built in
`lib/screens/student/student_dashboard.dart` and add/modify one. Change its
icon (browse icons at `Icons.` with autocomplete) and colour.

**Ex 3 — Build a whole new screen (45 min).**
Add a "My profile" screen for students showing everything in
`session.person` and `session.school`. Steps: create
`lib/screens/student/student_profile.dart` using the `MoreScreen` list-tile
style (no API call needed — the data is already in the Session!), then add an
entry for it in the `items` list in `lib/screens/home_shell.dart`. This
teaches: creating files, imports, `Navigator.push`, reading shared state.

**Ex 4 — Full stack: new endpoint + new screen (2h, with Claude's help).**
The student dashboard shows a *count* of library loans, but there's no loans
list screen. Add `GET /api/v1/student/loans` to the Laravel API (follow
`StudentController` + `StudentPortalService` patterns — the `BookLoan` model
already exists), then a Flutter screen listing each book + due date. This
teaches the whole request→response→screen pipeline.

---

## 6. Developing with Claude (the honest workflow)

Claude wrote this app and can extend it with you. What works best:

1. **One feature per request.** "Add a dark mode toggle to the More screen"
   beats "improve the app".
2. **Point at files.** "In `lib/screens/student/student_fees.dart`, make
   overdue invoices show at the top" — file paths remove all guesswork.
3. **Paste the whole error.** When something breaks, run
   `flutter analyze` and paste ALL of the red text. Never paraphrase errors.
4. **Ask to be taught, not just served.** "Explain what a FutureBuilder is
   using my student_dashboard.dart, then add X" gets you the feature AND the
   understanding.
5. **Checkpoint with git.** Before each feature: `git add -A && git commit -m
   "working: before <feature>"`. Fearless experimentation needs an undo button.
6. **Make Claude verify.** End requests with "run flutter analyze and fix
   anything it reports". For API work: "test the endpoint with curl and show
   me the response".
7. **When stuck, shrink the problem.** "The homework screen is blank" →
   ask Claude to add a `print(data)` after the API call and read what the
   server actually returned. Debugging is looking, not guessing.

### Vocabulary for talking to Claude (and reading its answers)

| Term | Meaning here |
|---|---|
| Widget | Any building block of UI (button, row, whole screen) |
| State | Data that can change while a screen is visible |
| `setState` | "State changed — repaint this widget" |
| Provider / `context.watch` | How any screen reads the shared Session |
| Future / `async`/`await` | A value that arrives later (all network calls) |
| Hot reload | Apply saved code changes to the running app instantly |
| Endpoint | One URL on the server, e.g. `GET /api/v1/student/fees` |
| Token | The random string proving to the server who you are |
| JSON | The text format the app and server exchange |

---

## 7. Your API, on one page

Base URL: `http://schoolsaas.test:8020/api/v1` · All authenticated requests
need the header `Authorization: Bearer <token>`.

```
POST /login {email, password, device_name}     → token + user (+school branding)
GET  /me            POST /logout
GET  /notices       GET /notifications         POST /notifications/{id}/read
GET  /notifications/unread-count               POST /notifications/read-all

# student
GET  /student/dashboard | attendance?month=YYYY-MM | timetable | homework
     | exams | results | fees | lessons
POST /student/homework/{id}/submit {content}

# teacher
GET  /teacher/dashboard | timetable | sections
GET  /teacher/attendance?section_id=&date=     POST /teacher/attendance
GET  /teacher/assignments | assignments/meta   POST /teacher/assignments
GET  /teacher/assignments/{id}/submissions     POST /teacher/submissions/{id}/grade

# parent
GET  /parent/dashboard | children
GET  /parent/children/{id}/attendance | timetable | homework | exams
     | results | fees
```

Every response is wrapped the same way:
`{"success": true, "message": "OK", "data": { ... }}` — and on failure
`{"success": false, "message": "why", "errors": {...}}` with an HTTP error
code. The app's `ApiClient` handles both automatically.

Try it yourself in a terminal:

```bash
curl -s -X POST http://schoolsaas.test:8020/api/v1/login \
  -H "Content-Type: application/json" -H "Accept: application/json" \
  -d '{"email":"student@westfield.edu","password":"password","device_name":"curl"}'
```

Copy the token from the reply, then:

```bash
curl -s http://schoolsaas.test:8020/api/v1/student/fees \
  -H "Accept: application/json" -H "Authorization: Bearer PASTE_TOKEN_HERE"
```

That's the entire secret of mobile apps: the app just does what you did by
hand, and draws the answer.
