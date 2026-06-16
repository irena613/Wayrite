# Firebase Setup — чекор по чекор

Оваа апликација моментално работи со in-memory mock backend
([`lib/data/mock_data_store.dart`](../lib/data/mock_data_store.dart)) за UI
flow-то да може да се демонстрира без вистински сервер. Овој документ
објаснува како да се креира Firebase проект и да се поврзе со Auth,
Firestore, Cloud Functions и Cloud Messaging. Чекорите 1–4 се прават рачно
во браузер (потребна е твоја Google сметка), чекор 5+ е код кој аз/ти
можеме да го додадеме откако проектот постои.

## 1. Креирање на Firebase проект

1. Оди на https://console.firebase.google.com и логирај се со Google сметка.
2. „Add project" → внеси име (пр. `timski-app`) → продолжи.
3. Google Analytics е опционално за овој проект — може да се исклучи.
4. Кога проектот е креиран, во левото мени додади Android/iOS/Web апликации
   (зависно што градиш):
   - **Android**: package name мора да се совпаѓа со `android/app/build.gradle`
     (`applicationId`). Се прескокнува рачно симнување на `google-services.json`
     ако користиш FlutterFire CLI (чекор 2 подолу прави сè автоматски).
   - **iOS**: bundle id од `ios/Runner.xcodeproj`.
   - **Web**: ако планираш да градиш и за `flutter run -d chrome`.

## 2. Поврзување со Flutter проектот (FlutterFire CLI)

Во терминал, во root на овој проект:

```bash
dart pub global activate flutterfire_cli
firebase login
flutterfire configure
```

`flutterfire configure` ќе те праша кој Firebase проект да се користи и за
кои платформи — автоматски генерира `lib/firebase_options.dart` и
ги поставува native конфигурациите (`google-services.json`,
`GoogleService-Info.plist`).

> Ако `firebase` CLI не е инсталиран: `npm install -g firebase-tools`.

## 3. Authentication

Во Firebase Console → **Build → Authentication → Sign-in method**:

1. Активирај **Email/Password** (ова го покрива `LoginScreen`/`RegisterScreen`).
2. (Опционално) активирај **Google** sign-in ако сакаш побрза регистрација.

Во `pubspec.yaml` додади:

```yaml
dependencies:
  firebase_core: ^3.8.0
  firebase_auth: ^5.3.3
```

Замена на mock логиката во `MockDataStore.login`/`register` со:

```dart
final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
  email: email, password: password,
);
```

## 4. Firestore (база на податоци)

Во Firebase Console → **Build → Firestore Database** → „Create database" →
избери production mode → избери регион (пр. `eur3` за Европа).

### Препорачана структура на колекции

Соодветствува директно на моделите во `lib/models/`:

```
users/{userId}
  name, username, email, bio

posts/{postId}
  authorId, type ("achievement" | "quit"), title, description,
  startDate (Timestamp), endDate (Timestamp?), createdAt (Timestamp),
  likeCount (number)               // денормализирано за брзо читање
posts/{postId}/likes/{userId}      // subcollection, постоење = liked
posts/{postId}/comments/{commentId}
  authorId, text, createdAt

friendships/{userId}/friends/{friendId}     // симетрично, се пишува на двете страни
friendRequests/{targetUserId}/incoming/{requesterId}
  createdAt

notifications/{userId}/items/{notificationId}
  type, actorId, postId?, createdAt, read (bool)
```

Додади во `pubspec.yaml`:

```yaml
dependencies:
  cloud_firestore: ^5.5.0
```

### Security rules (почетна верзија)

```js
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    match /posts/{postId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null
                     && request.resource.data.authorId == request.auth.uid;
      allow update, delete: if request.auth != null
                     && resource.data.authorId == request.auth.uid;

      match /likes/{userId} {
        allow read: if request.auth != null;
        allow write: if request.auth != null && request.auth.uid == userId;
      }
      match /comments/{commentId} {
        allow read: if request.auth != null;
        allow create: if request.auth != null
                       && request.resource.data.authorId == request.auth.uid;
      }
    }
    match /notifications/{userId}/items/{itemId} {
      allow read, update: if request.auth != null && request.auth.uid == userId;
      allow create: if request.auth != null; // се создава од друг корисник/Cloud Function
    }
  }
}
```

## 5. Cloud Functions (нотификации при like/коментар/барање)

```bash
firebase init functions
```

Избери TypeScript или JavaScript. Пример функција која при нов коментар
праќа push нотификација до авторот на објавата (триггер-базирана
архитектура — ова е причината зошто Functions се потребни наместо да се
праќа FCM директно од клиента):

```ts
// functions/src/index.ts
import * as functions from "firebase-functions/v2/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { getFirestore } from "firebase-admin/firestore";
import { initializeApp } from "firebase-admin/app";

initializeApp();
const db = getFirestore();

export const onNewComment = functions.onDocumentCreated(
  "posts/{postId}/comments/{commentId}",
  async (event) => {
    const comment = event.data?.data();
    if (!comment) return;

    const postSnap = await db.doc(`posts/${event.params.postId}`).get();
    const post = postSnap.data();
    if (!post || post.authorId === comment.authorId) return; // не нотифицирај себе си

    await db.collection(`notifications/${post.authorId}/items`).add({
      type: "comment",
      actorId: comment.authorId,
      postId: event.params.postId,
      createdAt: new Date(),
      read: false,
    });

    const authorSnap = await db.doc(`users/${post.authorId}`).get();
    const fcmToken = authorSnap.data()?.fcmToken;
    if (fcmToken) {
      await getMessaging().send({
        token: fcmToken,
        notification: {
          title: "Нов коментар",
          body: `${comment.authorId} коментираше на твојата објава`,
        },
      });
    }
  }
);
```

Деплојирање:

```bash
firebase deploy --only functions
```

Истиот шаблон се копира за `onNewLike` (trigger на `posts/{postId}/likes/{userId}`
create) и `onFriendRequest` (trigger на `friendRequests/{userId}/incoming/{requesterId}`).

## 6. Cloud Messaging (push нотификации)

Во Firebase Console → **Build → Cloud Messaging** — не треба рачна
конфигурација ако веќе си направил чекор 2 (FlutterFire CLI ги поставува
APNs/FCM клучевите за iOS автоматски, за Android работи "из кутија").

```yaml
dependencies:
  firebase_messaging: ^15.1.6
```

Во апликацијата, при логирање, зачувај `fcmToken` во `users/{userId}`:

```dart
final token = await FirebaseMessaging.instance.getToken();
await FirebaseFirestore.instance.collection('users').doc(uid).update({
  'fcmToken': token,
});
```

За Android треба и `minSdkVersion 21+` во `android/app/build.gradle`
(стандардно е веќе задоволено во нов Flutter проект).

## 7. Редослед на интеграција (препорака)

1. Authentication (замени `login`/`register`/`logout` во `MockDataStore`)
2. Firestore за `users`, `posts`, `comments`, `likes` (замени
   `createPost`/`toggleLike`/`addComment`/`feedPosts`)
3. Firestore за `friendRequests`/`friendships` (замени
   `sendFriendRequest`/`acceptFriendRequest`/...)
4. Cloud Functions + Firestore `notifications` (замени `_addNotification`
   логиката — таа треба да се пресели од клиент на Cloud Function за
   сигурност и доследност)
5. Cloud Messaging (push нотификации кога апликацијата е во background)

Бидејќи сите екрани комуницираат само преку `appStore`
([`lib/data/app_store.dart`](../lib/data/app_store.dart)), секој од овие
чекори значи замена на внатрешноста на `MockDataStore` со повици кон
Firebase — UI кодот во `lib/screens/` не треба да се менува.
