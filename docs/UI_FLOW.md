# UI Flow — Тимски

Граф на навигација низ сите екрани на апликацијата. Секој екран одговара на
конкретен Flutter файл во [`lib/screens/`](../lib/screens).

```
┌─────────────┐        регистрирај се        ┌──────────────────┐
│ LoginScreen  ├──────────────────────────────▶ RegisterScreen   │
│ (auth/)      │                               │ (auth/)          │
└──────┬───────┘                               └────────┬─────────┘
       │ најава / демо профил                            │ успешна регистрација
       ▼                                                  ▼
┌──────────────────────────────────────────────────────────────────┐
│                            HomeShell                               │
│              (bottom navigation + FAB "+")                         │
│                                                                      │
│   ┌──────────┐   ┌────────────┐   ┌────────────────┐   ┌────────┐ │
│   │ FeedScreen│   │SearchScreen│   │NotificationsScr.│   │Profile │ │
│   └─────┬────┘   └─────┬──────┘   └────────┬────────┘   └───┬────┘ │
└─────────┼──────────────┼───────────────────┼────────────────┼──────┘
          │ тап на автор/пост │ ред → профил   │ тап на ставка   │ Уреди / Одјави
          ▼              ▼    │                │                ▼
┌───────────────────┐  ┌──────────────────┐    │        ┌──────────────────┐
│ PostDetailScreen   │  │ UserProfileScreen │◀──┘        │ EditProfileScreen │
│ (коментари + like, │  │ (профил+објави на  │            └──────────────────┘
│  тап на автор ──┐  │  │  друг корисник)    │
└─────────────────┼──┘  └─────────┬─────────┘
                   │               │ "Пријатели" стат.
                   │               ▼
                   │      ┌──────────────────┐
                   │      │ FriendsListScreen │── тап на ред ──▶ UserProfileScreen
                   │      └──────────────────┘
                   └──────────────▶ UserProfileScreen
                                    │ friendRequest/friendAccept нотиф.
                                    ▼
                              (враќа на SearchScreen)

FAB "+" во HomeShell ─────────────▶ CreatePostScreen ───── "Објави" ─────▶ назад на FeedScreen
                                    (Achievement/Quit, наслов, опис, датуми)
```

## Чекор-по-чекор сценарија

1. **Регистрација и најава**
   `LoginScreen` → „Регистрирај се" → `RegisterScreen` → успешна регистрација
   → автоматска најава → `HomeShell` (таб Feed). Постои и копче „Продолжи со
   демо профил" за брз преглед без регистрација (in-memory demo податоци,
   не Firestore).

2. **Преглед/измена на сопствен профил**
   `HomeShell` (таб Профил) → `ProfileScreen` (лични податоци, статистика,
   сопствени објави, копче „Освежи") → „Уреди профил" → `EditProfileScreen`
   → „Зачувај" → назад на `ProfileScreen` со ажурирани податоци.

3. **Пребарување и пријателство**
   `HomeShell` (таб Пребарувај) → `SearchScreen` → пребарување по точен
   `username` → копче „Додај" (испраќа барање преку `sendFriendRequest`
   Cloud Function) → примателот во својот `SearchScreen` (без активно
   пребарување) гледа листа „Барања за пријателство" → „Прифати"/„Одбиј".
   Тап на самиот ред (не копчето) отвора `UserProfileScreen` на тој корисник.

4. **Профил на друг корисник и листа на пријатели**
   Тап на ред во `SearchScreen`/`FriendsListScreen`, или тап на автор на
   пост (аватар/име) во `FeedScreen`/`PostDetailScreen` → `UserProfileScreen`
   — податоци + објави на тој корисник (видливи само ако сте пријатели или
   ако е сопствениот профил — согласно `firestore.rules`). „Пријатели"
   статистиката (на `ProfileScreen` и `UserProfileScreen`) е тап-абилна →
   `FriendsListScreen` (листа на пријателите на тој корисник, секој ред
   води до неговиот `UserProfileScreen`). На `UserProfileScreen`/
   `FriendsListScreen`, чипот „Пријатели" (лилава боја) е исто така
   тап-абилен → потврда → отпријателување (`unfriend` Cloud Function).

5. **Креирање објава**
   `HomeShell` → FAB „+" → `CreatePostScreen` → избор на тип
   (Achievement/Quit) преку `SegmentedButton`, наслов, опис, почетен и
   опционален краен датум → „Објави" → нова објава на врвот на `FeedScreen`.

6. **Feed и детали**
   `FeedScreen` прикажува само објави од пријатели + сопствени (
   `where authorId in [self, ...friendIds]`), хронолошки (најнови прво),
   преку `PostCard`. Копче „Освежи" во AppBar-от + pull-to-refresh за
   рачно бришење на кешот и повторно вчитување (feed-от не е live
   listener — потребно рачно освежување по нови објави/пријателства). Тап
   на картичка отвора `PostDetailScreen` со целосен текст, копче за
   реакција (like) и листа на коментари + поле за нов коментар. Тап на
   авторот (аватар/име) отвора `UserProfileScreen`.

7. **Нотификации**
   `like`/`comment`/`friendRequest`/`friendAccept` настани се запишуваат од
   Cloud Functions директно во Firestore `notifications` колекцијата и се
   читаат во реално време (live listener) во `NotificationsScreen`. Тап на
   ставка води до `PostDetailScreen` (за like/коментар) или `SearchScreen`
   (за пријателство), и ја означува нотификацијата како прочитана
   (`notifications/{id}.read = true` во Firestore).

## Архитектурна забелешка

Сите екрани читаат и пишуваат преку единствена точка —
[`appStore`](../lib/data/app_store.dart) (`MockDataStore`). Internally, тоа
веќе комбинира in-memory demo податоци (за „Продолжи со демо профил") со
вистински Firebase повици (Auth, Firestore live listeners, Cloud Functions)
кога си најавен со реален профил — деталите се во
[`FIREBASE_SETUP.md`](FIREBASE_SETUP.md).
