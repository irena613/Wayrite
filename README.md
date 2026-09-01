# Тимски

Flutter апликација за споделување лични постигнувања и откажувања од лоши
навики со пријатели — feed, коментари, реакции, барања за пријателство и
нотификации.

## Структура

```
lib/
  core/
    theme/      — дизајн систем (бои, типографија, spacing, икони)
    widgets/    — повторно употребливи UI компоненти (вкл. FriendActionButton)
    utils/      — помошни функции (формат на датум)
  models/       — AppUser, Post, Comment, NotificationItem, RelationshipStatus
  data/         — MockDataStore (demo податоци + вистински Firebase повици)
  screens/
    auth/       — Login, Register
    home/       — HomeShell (bottom navigation + FAB)
    feed/       — Feed (само објави од пријатели + сопствени, освежување)
    post/       — CreatePost, PostDetail (коментари + реакции)
    search/     — Пребарување корисници + барања за пријателство
    profile/    — Profile (сопствен), UserProfileScreen (друг корисник),
                  FriendsListScreen, EditProfile
    notifications/ — Notifications (Firestore live listener)

firestore.rules       — security rules (friends-only читање на posts/comments)
functions/src/index.ts — Cloud Functions (friend requests, нотификации, streaks)
```

## Документација

- [docs/UI_FLOW.md](docs/UI_FLOW.md) — граф на навигација низ сите екрани
- [docs/DESIGN_SYSTEM.md](docs/DESIGN_SYSTEM.md) — бои, типографија, икони, компоненти
- [docs/FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md) — податочен модел, security
  rules, Cloud Functions листа, и како да се стартува Firebase Local
  Emulator Suite за локален развој

## Стартување

```bash
flutter pub get
firebase emulators:start --import=./emulator-data --export-on-exit=./emulator-data
flutter run
```

Потребни се `lib/firebase_options.dart` и `android/app/google-services.json`
(не се во git — виж [docs/FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md) #4) и
JDK 11+ за Firestore emulator-от.

На Login екранот, копчето **„Продолжи со демо профил"** најавува со
претходно подготвени demo податоци (корисници, објави, коментари,
нотификации) за брз преглед на UI-то без Firebase (нема потреба од
emulator/конфигурација за ова).

## Тековен статус

Апликацијата има вистински Firebase backend — не само UI/mock:

- **Authentication** — email/password login/register/logout.
- **Firestore** — корисници, објави (achievement/quit), коментари, лајкови,
  барања за пријателство, нотификации. Security rules ги ограничуваат
  објавите/коментарите на авторот и неговите пријатели (види
  [docs/FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md) #2).
- **Cloud Functions** — атомско менаџирање пријателства (send/accept/
  decline/cancel/unfriend), валидација при креирање пост, push нотификации
  (like/коментар/пријателство), автоматско пресметување на streak за Quit
  објави.
- **Cloud Messaging** — push нотификации до регистрирани FCM токени.

Демо-најавата (in-memory, без Firestore) останува достапна за брз преглед
на UI-то без потреба од Firebase проект/emulator. Deploy на реален Firebase
проект: [docs/FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md) #5.
