# Firebase Backend — што е направено и како да се работи локално

Апликацијата **веќе е поврзана** со вистински Firebase backend — ова не е
план за иднина, туку опис на тековната имплементација (Authentication,
Firestore, Cloud Functions, Cloud Messaging). Клучен архитектурен принцип:
сите екрани комуницираат само преку [`appStore`](../lib/data/app_store.dart)
(`MockDataStore`), кое внатрешно повикува вистински Firebase SDK-и — UI
кодот во `lib/screens/` не знае дали работи со emulator или продукција.

## 1. Податочен модел (Firestore)

```
users/{userId}
  name, username, email, bio
  friendIds: string[]     // денормализирано, менувано САМО од Cloud Functions
  fcmTokens: string[]     // push токени, менувано САМО од Cloud Functions

friendRequests/{fromUserId}_{toUserId}
  fromUserId, toUserId, createdAt
  // Doc id е детерминистички (`friendRequestDocId`) за брзо look-up на
  // постоечко/реверзно барање. Клиентот само чита; сите пишувања се преку
  // Cloud Functions (виж подолу).

posts/{postId}
  authorId, type ("achievement" | "quit"), title, description,
  startDate (Timestamp), endDate (Timestamp?), createdAt (Timestamp),
  likedBy: string[], commentIds: string[]

posts/{postId}/comments/{commentId}
  authorId, text, createdAt

notifications/{notifId}
  recipientId, type ("like" | "comment" | "friendRequest" | "friendAccept"),
  actorId, postId?, read (bool), createdAt
  // Запишувани исклучиво од Cloud Functions (Admin SDK), никогаш директно
  // од клиентот.
```

Нема `friendships`/`friendRequests/{uid}/incoming` подколекции ниту
денормализирани `likeCount` полиња — тоа беше првобитен план во постара
верзија на овој документ, но фактичката имплементација користи `friendIds`
низа директно на `users` документот (побрзо за проверка на пријателство во
rules преку еден `get()`) и `likedBy`/`commentIds` низи директно на
`posts` документот.

## 2. Security rules ([`firestore.rules`](../firestore.rules))

- **`users/{userId}`** — секој најавен корисник може да чита кој било
  профил (потребно за search/feed/profile екраните). Пишување само на
  сопствениот документ, и **никогаш** директно на `friendIds`/`fcmTokens` —
  тие полиња ги менуваат само Cloud Functions преку Admin SDK (кој ги
  заобиколува rules-ите целосно).
- **`friendRequests/{id}`** — читање само ако си испраќач или примач.
  Пишување целосно забрането од клиент (`allow write: if false`) — секое
  создавање/бришење оди преку Cloud Function за да остане атомско (пр.
  проверка дека не постои веќе реверзно барање).
- **`posts/{postId}`** — читливо само од авторот и неговите пријатели
  (`isSelfOrFriend`). **Важно**: Firestore одбива `list` query во целост
  ако кое било потенцијално совпаѓање не го задоволува rule-от — rules не
  се филтри. Затоа клиентот секогаш го скопира query-то со
  `where('authorId', whereIn: [self, ...friendIds])` (максимум 30
  вредности), наместо да чита цела колекција. `update` дозволува само две
  раздвоени промени: (а) авторот менува title/description/датуми, или (б)
  авторот/пријател токглира точно својот uid во `likedBy`.
- **`posts/{postId}/comments/{commentId}`** — исто ограничување
  (author-or-friend), но бидејќи секој query овде е веќе скопиран на еден
  `postId`, нема проблем со list-query одбивање.
- **`notifications/{notifId}`** — читање/означување-како-прочитано само од
  примачот (`recipientId == auth.uid`).

## 3. Cloud Functions ([`functions/src/index.ts`](../functions/src/index.ts))

Сите се во регион `europe-west1`.

| Функција | Тип | Што прави |
|---|---|---|
| `registerFcmToken` / `unregisterFcmToken` | `onCall` | Додава/отстранува FCM токен на `users/{uid}.fcmTokens` при login/logout. |
| `createPostValidated` | `onCall` | Валидира и создава нова објава на серверска страна (истиот `postId` генериран од Flutter, за конзистентност со оптимистичкиот locален запис). |
| `onCommentCreated` | `onDocumentCreated` (trigger) | При нов коментар, испраќа нотификација + push до авторот на објавата. |
| `onPostLiked` | `onDocumentUpdated` (trigger) | При додаден нов uid во `likedBy`, испраќа нотификација + push до авторот. |
| `updateAllStreaks` | `onSchedule` (секој ден во полноќ) | Го рекалкулира `currentStreakDays` за сите активни (без `endDate`) Quit-објави. |
| `recalcStreak` | `onDocumentUpdated` (trigger) | Го рекалкулира streak-от веднаш штом се смени датум на Quit-објава. |
| `sendFriendRequest` | `onCall` | Атомски проверува дека нема веќе пријателство/барање (во која било насока) па создава `friendRequests` документ + нотификација. |
| `cancelFriendRequest` | `onCall` | Го брише сопственото испратено барање. |
| `declineFriendRequest` | `onCall` | Го брише примено барање без да создаде пријателство. |
| `acceptFriendRequest` | `onCall` | Во транзакција: додава меѓусебно `friendIds` на двата корисника + брише барањето + испраќа нотификација. |
| `unfriend` | `onCall` | Batch write — отстранува меѓусебно `friendIds` на двата корисника. |

## 4. Локален развој (Firebase Local Emulator Suite)

Апликацијата (по default, `_useEmulator = true` во
[`lib/main.dart`](../lib/main.dart)) зборува со **локален** emulator, не со
продукција — сигурно е за тестирање без да се допрат реални податоци.

### Предуслови

- **Node.js** + `npm install -g firebase-tools`, потоа `npm install` во
  `functions/`.
- **JDK 11+** за Firestore emulator-от. Ако системски е инсталиран постар
  JDK (пр. 8), emulator-от паѓа со
  `UnsupportedClassVersionError`/`Unsupported java version`. На Windows,
  најлесно решение е да се насочи кон JDK-то вградено во Android Studio,
  без инсталирање ново:
  ```bash
  export JAVA_HOME="C:\Program Files\Android\Android Studio\jbr"
  export PATH="$JAVA_HOME/bin:$PATH"
  ```
- **Android emulator/уред**: cleartext HTTP кон emulator-ите е блокирано by
  default од API 28. Затоа постои
  [`android/app/src/debug/res/xml/network_security_config.xml`](../android/app/src/debug/res/xml/network_security_config.xml)
  (allowlist за `10.0.2.2`/`localhost`), референциран во
  [`android/app/src/debug/AndroidManifest.xml`](../android/app/src/debug/AndroidManifest.xml).
  Промена тука бара **целосен rebuild**, не hot reload/restart.
- **Конфигурациски датотеки кои НЕ се во git** (види `.gitignore`):
  `lib/firebase_options.dart` и `android/app/google-services.json`. Без
  нив апликацијата не се билдира воопшто (`Firebase.initializeApp()` нема
  на што да укаже). Земи ги директно или регенерирај ги со
  `flutterfire configure` (потребен пристап до Firebase проектот).

### Стартување

```bash
firebase emulators:start --import=./emulator-data --export-on-exit=./emulator-data
```

- `--import` ги вчитува претходно зачуваните тест-профили/објави (ако
  постои `emulator-data/`, изворно направена со
  `firebase emulators:export ./emulator-data`). Без `--import`, почнуваш
  со празна база.
- `--export-on-exit` автоматски ги зачувува податоците при чист gracefully
  shutdown (Ctrl+C), за да не се губат тест-профилите меѓу сесии.
- Emulator UI: http://127.0.0.1:4000 (Firestore/Auth/Functions табови).
- Портите (Firestore 8080, Auth 9099, Functions 5001, UI 4000) се
  конфигурирани во [`firebase.json`](../firebase.json).

`lib/main.dart` содржи:

```dart
const _useEmulator = true;
const _emulatorHost = '10.0.2.2'; // Android emulator alias за host machine-от
```

За физички уред, замени со LAN IPv4-адресата на твојот компјутер
(`ipconfig`) и осигурај се дека уредот е на иста мрежа.

## 5. Деплојирање на вистински Firebase проект

```bash
firebase deploy --only firestore:rules,functions
```

Потоа во `lib/main.dart`, стави `_useEmulator = false` — апликацијата ќе
зборува со реалниот проект (без промена во UI кодот).

## 6. Познати ограничувања

- `test/widget_test.dart` не повикува `Firebase.initializeApp()` пред да
  рендерира `TimskiApp`, па паѓа со `[core/no-app]` — постоечки проблем,
  не е поврзан со friends-функционалноста додадена подоцна. CI
  ([`.github/workflows/flutter_ci.yml`](../.github/workflows/flutter_ci.yml))
  моментално се активира само на push/PR кон `master`/`main`, не `dev`.
- `searchUsers` е точен-match само по `username` (не prefix/substring) —
  намерна одлука откако prefix-range query со невидлив sentinel карактер
  за горна граница се покажа непоуздан преку Android platform channel-от
  во тестирањето.
