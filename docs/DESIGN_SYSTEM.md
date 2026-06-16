# Дизајн систем — Тимски

Изворот на вистина е кодот во [`lib/core/theme/`](../lib/core/theme) и
[`lib/core/widgets/`](../lib/core/widgets). Овој документ е резиме за
презентација/документација на проектот.

## Бои ([`app_colors.dart`](../lib/core/theme/app_colors.dart))

| Токен | Hex | Употреба |
|---|---|---|
| `primary` | `#5B6BF5` | Брендинг, копчиња, активни икони |
| `primaryDark` | `#3F4ED1` | Hover/pressed состојби |
| `primaryLight` | `#E7E9FE` | Позадина на chips, истакнати нотификации |
| `achievement` | `#2EB872` | Бедж/икона за тип на објава „Постигнување" |
| `quit` | `#FF7A59` | Бедж/икона за тип на објава „Откажување" |
| `background` | `#F7F8FA` | Позадина на екрани |
| `surface` | `#FFFFFF` | Картички, полиња, бар |
| `border` | `#E5E7EB` | Линии/рамки |
| `textPrimary` | `#1A1B25` | Основен текст |
| `textSecondary` | `#6B7280` | Помошен текст (датуми, captions) |
| `error` | `#E53E3E` | Грешки, „Одбиј" акции |
| `like` | `#FF4D67` | Активна реакција (like) |

Avatar-ите немаат вистински слики на ова ниво — секој корисник добива боја
автоматски избрана од `avatarPalette` според `userId`, конзистентно секаде
каде се прикажува.

## Типографија ([`app_typography.dart`](../lib/core/theme/app_typography.dart))

| Стил | Големина | Тежина | Употреба |
|---|---|---|---|
| `displaySmall` | 28 | 700 | Наслов на Login екран |
| `titleLarge` | 22 | 700 | AppBar наслови, наслов на објава во детали |
| `titleMedium` | 18 | 600 | Наслов на објава во картичка |
| `titleSmall` | 15 | 600 | Име на корисник |
| `bodyLarge` | 16 | 400 | Опис на објава (детален преглед) |
| `bodyMedium` | 14 | 400 | Опис во картичка, коментари |
| `bodySmall` | 12 | 400 | Датуми, мета-информации |
| `label` | 13 | 600 | Текст на копчиња |
| `caption` | 11 | 500 | Временски ознаки (timeAgo) |

Фонт: системски (без custom font asset), за да остане лесно читливо на сите
платформи без дополнителни ресурси.

## Spacing ([`app_spacing.dart`](../lib/core/theme/app_spacing.dart))

4pt grid: `xs=4, sm=8, md=12, lg=16, xl=24, xxl=32`.
Радиус: `radiusSm=8, radiusMd=12, radiusLg=16, radiusPill=999`.

## Икони ([`app_icons.dart`](../lib/core/theme/app_icons.dart))

Material Icons (вклучени преку `uses-material-design: true`, без
дополнителен пакет):

- Навигација: `feed` (dynamic_feed), `search`, `add` (FAB), `notifications`,
  `profile` (person)
- Реакции: `like`/`likeOutline` (favorite), `comment`
- Пријателство: `friendAdd`, `friendPending`, `friendAccept`, `friendDecline`,
  `friends`
- Тип на објава: `emoji_events` (Achievement), `block` (Quit)

## Компоненти ([`lib/core/widgets/`](../lib/core/widgets))

| Компонента | Фајл | Употреба |
|---|---|---|
| `PrimaryButton` / `SecondaryButton` | `app_button.dart` | Сите главни/секундарни акции |
| `AppTextField` | `app_text_field.dart` | Сите форми (login, register, edit profile, create post, коментар) |
| `UserAvatar` | `user_avatar.dart` | Секаде каде се прикажува корисник |
| `PostTypeBadge` | `post_type_badge.dart` | Означува Achievement/Quit на картичка и детали |
| `PostCard` | `post_card.dart` | Feed и Профил листа на објави |
| `LikeButton` | `like_button.dart` | Реакција со бројач |
| `CommentTile` | `comment_tile.dart` | Ред во листа коментари |
| `UserListTile` | `user_list_tile.dart` | Резултат од пребарување / барање за пријателство |
| `NotificationTile` | `notification_tile.dart` | Ред во листа нотификации |
| `EmptyState` | `empty_state.dart` | Празни состојби (нема објави/резултати/коментари) |

`AppTheme.light` ([`app_theme.dart`](../lib/core/theme/app_theme.dart)) ги
склопува сите токени во едно `ThemeData` (Material 3) кое се применува
еднаш во `MaterialApp` ([`main.dart`](../lib/main.dart)) — екраните не
дефинираат сопствени бои/фонтови.
