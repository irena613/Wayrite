# Тимски

Flutter апликација за споделување лични постигнувања и откажувања од лоши
навики со пријатели — feed, коментари, реакции, барања за пријателство и
нотификации.

## Структура

```
lib/
  core/
    theme/      — дизајн систем (бои, типографија, spacing, икони)
    widgets/    — повторно употребливи UI компоненти
    utils/      — помошни функции (формат на датум)
  models/       — AppUser, Post, Comment, NotificationItem, RelationshipStatus
  data/         — MockDataStore (in-memory "backend" за демо/UI flow)
  screens/
    auth/       — Login, Register
    home/       — HomeShell (bottom navigation + FAB)
    feed/       — Feed (хронолошки приказ на објави)
    post/       — CreatePost, PostDetail (коментари + реакции)
    search/     — Пребарување корисници + барања за пријателство
    profile/    — Profile, EditProfile
    notifications/ — Notifications
```

## Документација

- [docs/UI_FLOW.md](docs/UI_FLOW.md) — граф на навигација низ сите екрани
- [docs/DESIGN_SYSTEM.md](docs/DESIGN_SYSTEM.md) — бои, типографија, икони, компоненти
- [docs/FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md) — чекор-по-чекор поврзување со
  Firebase Authentication, Firestore, Cloud Functions и Cloud Messaging

## Стартување

```bash
flutter pub get
flutter run
```

На Login екранот, копчето **„Продолжи со демо профил"** најавува со
претходно подготвени demo податоци (корисници, објави, коментари,
нотификации) за брз преглед на целиот UI flow без рачна регистрација.

## Тековен статус

UI-то работи со in-memory mock backend
([`lib/data/mock_data_store.dart`](lib/data/mock_data_store.dart)) — сите
екрани и интеракции (najava, creирање објава, like, коментар, барање за
пријателство, нотификации) се целосно функционални во апликацијата, без
надворешен сервер. Поврзување со вистински Firebase backend се прави по
чекорите во [docs/FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md), без промена
на UI кодот.
