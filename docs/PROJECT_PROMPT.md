# MobileChat Product Prompt

Original request saved from the user:

> Нужно сделать приложение на языке Dart, чтобы был кроссплатформенный и для Android, и для iOS. И смотри, это приложение должно быть как Telegram, то есть все работы как в Telegram, но должно быть вот так вот. Личные чаты не должно быть, ну то есть будут только группы. Есть два вида групп. Первый только через код или через приглашение можно зайти у админа, а второй для всех. Ну то есть можешь поискать в поиске и туда войти. Давай, начинай сделать. Вот у тебя есть две репозитория, один для серверной части, другой для клиентской части. Сделай все красиво, как в Telegram. Все работа как в Telegram, но там не будет личных чатов, только будут группы. И человека можно добавить в группу по ID. То есть у каждого человека будет ID, всем будет виден. Можешь приглашать в группу через ID. Давай начинай, потом постепенно будем исправлять. Вот этот промпт обязательно где-нибудь сохрани. Не забывай об этом. Обязательно сохрани где-нибудь.

## Product direction

MobileChat is a Telegram-style cross-platform group chat application built with Flutter/Dart for Android and iOS.

Core rules:

- No private one-to-one chats.
- Only group chats.
- Two group visibility modes:
  - Public groups: searchable and joinable by any user.
  - Private groups: join only by invite code or admin invitation.
- Every user has a visible public user ID.
- Admins can invite users to a group by user ID.
- UI should feel clean, modern, and close to Telegram-style navigation.

## Initial MVP scope

- Flutter app shell.
- Auth/profile placeholder.
- Group list.
- Public group search.
- Create public/private group.
- Join private group by invite code.
- Group chat screen.
- Server API integration layer.
