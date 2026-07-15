import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../app/localization.dart';
import '../app/theme.dart';

String avatarText(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '?';
  return trimmed.substring(0, 1).toUpperCase();
}

String compactTime(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

int? _cp1251ByteForRune(int codePoint) {
  if (codePoint <= 0xff) return codePoint;
  if (codePoint >= 0x0410 && codePoint <= 0x044f) {
    return 0xc0 + (codePoint - 0x0410);
  }

  switch (codePoint) {
    case 0x0402:
      return 0x80;
    case 0x0403:
      return 0x81;
    case 0x201a:
      return 0x82;
    case 0x0453:
      return 0x83;
    case 0x201e:
      return 0x84;
    case 0x2026:
      return 0x85;
    case 0x2020:
      return 0x86;
    case 0x2021:
      return 0x87;
    case 0x20ac:
      return 0x88;
    case 0x2030:
      return 0x89;
    case 0x0409:
      return 0x8a;
    case 0x2039:
      return 0x8b;
    case 0x040a:
      return 0x8c;
    case 0x040c:
      return 0x8d;
    case 0x040b:
      return 0x8e;
    case 0x040f:
      return 0x8f;
    case 0x0452:
      return 0x90;
    case 0x2018:
      return 0x91;
    case 0x2019:
      return 0x92;
    case 0x201c:
      return 0x93;
    case 0x201d:
      return 0x94;
    case 0x2022:
      return 0x95;
    case 0x2013:
      return 0x96;
    case 0x2014:
      return 0x97;
    case 0x2122:
      return 0x99;
    case 0x0459:
      return 0x9a;
    case 0x203a:
      return 0x9b;
    case 0x045a:
      return 0x9c;
    case 0x045c:
      return 0x9d;
    case 0x045b:
      return 0x9e;
    case 0x045f:
      return 0x9f;
    case 0x00a0:
      return 0xa0;
    case 0x040e:
      return 0xa1;
    case 0x045e:
      return 0xa2;
    case 0x0408:
      return 0xa3;
    case 0x00a4:
      return 0xa4;
    case 0x0490:
      return 0xa5;
    case 0x00a6:
      return 0xa6;
    case 0x00a7:
      return 0xa7;
    case 0x0401:
      return 0xa8;
    case 0x00a9:
      return 0xa9;
    case 0x0404:
      return 0xaa;
    case 0x00ab:
      return 0xab;
    case 0x00ac:
      return 0xac;
    case 0x00ad:
      return 0xad;
    case 0x00ae:
      return 0xae;
    case 0x0407:
      return 0xaf;
    case 0x00b0:
      return 0xb0;
    case 0x00b1:
      return 0xb1;
    case 0x0406:
      return 0xb2;
    case 0x0456:
      return 0xb3;
    case 0x0491:
      return 0xb4;
    case 0x00b5:
      return 0xb5;
    case 0x00b6:
      return 0xb6;
    case 0x00b7:
      return 0xb7;
    case 0x0451:
      return 0xb8;
    case 0x2116:
      return 0xb9;
    case 0x0454:
      return 0xba;
    case 0x00bb:
      return 0xbb;
    case 0x0458:
      return 0xbc;
    case 0x0405:
      return 0xbd;
    case 0x0455:
      return 0xbe;
    case 0x0457:
      return 0xbf;
  }
  return null;
}

int _mojibakeScore(String value) {
  final brokenPairs = RegExp(r'[РСТУ][\u0400-\u04ff\u00a0-\u00bf]');
  return brokenPairs.allMatches(value).length +
      'Ð'.allMatches(value).length +
      'Ñ'.allMatches(value).length +
      '�'.allMatches(value).length;
}

int _cyrillicScore(String value) =>
    RegExp(r'[\u0400-\u04ff]').allMatches(value).length;

String _repairMojibake(String value) {
  if (value.isEmpty ||
      !(value.contains('Р') ||
          value.contains('С') ||
          value.contains('Т') ||
          value.contains('У') ||
          value.contains('Ð') ||
          value.contains('Ñ'))) {
    return value;
  }

  final bytes = <int>[];
  for (final rune in value.runes) {
    final b = _cp1251ByteForRune(rune);
    if (b == null) return value;
    bytes.add(b);
  }

  try {
    final decoded = utf8.decode(bytes, allowMalformed: false);
    if (_mojibakeScore(decoded) < _mojibakeScore(value) &&
        _cyrillicScore(decoded) >= _cyrillicScore(value) ~/ 2) {
      return decoded;
    }
  } on FormatException {
    return value;
  }

  return value;
}

String _formatMuteUntil(String value) {
  try {
    final dt = DateTime.parse(value.trim()).toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}.${two(dt.month)}.${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  } catch (_) {
    final v = value.trim();
    if (v.length >= 16 && v.contains('T')) {
      return '${v.substring(8, 10)}.${v.substring(5, 7)}.${v.substring(0, 4)} ${v.substring(11, 16)}';
    }
    return v;
  }
}

String _normalizeMojibakeMessage(String message) {
  const replacements = <String, String>{
    'РЎС‚Р°С‚СѓСЃ Р¶Р°ТЈС‹СЂС‚С‹Р»РґС‹.': 'Статус жаңыртылды.',
    'РЎС‚Р°С‚СѓСЃ РѕР±РЅРѕРІР»С‘РЅ.': 'Статус обновлён.',
    'РўРѕРїС‚СѓРЅ С‡Р°РєС‹СЂСѓСѓ РєРѕРґСѓ Р°Р·С‹СЂС‹РЅС‡Р° С‚ТЇР·ТЇР»РіУ©РЅ СЌРјРµСЃ.':
        'Топтун чакыруу коду азырынча түзүлгөн эмес.',
    'РљРѕРґ РїСЂРёРіР»Р°С€РµРЅРёСЏ РіСЂСѓРїРїС‹ РїРѕРєР° РЅРµ СЃРѕР·РґР°РЅ.':
        'Код приглашения группы пока не создан.',
    'Р‘У©РіУ©С‚С‚У©Р№ С‚СѓСЂРіР°РЅ РєР°С‚С‹С€СѓСѓС‡Сѓ Р¶РѕРє.':
        'Бөгөттөй турган катышуучу жок.',
    'РќРµС‚ СѓС‡Р°СЃС‚РЅРёРєРѕРІ, РєРѕС‚РѕСЂС‹С… РјРѕР¶РЅРѕ Р·Р°Р±Р»РѕРєРёСЂРѕРІР°С‚СЊ.':
        'Нет участников, которых можно заблокировать.',
    'РўРµРєС€РµСЂТЇТЇРґУ©РіТЇ РјР°С‚РµСЂРёР°Р»РґР°СЂ':
        'Текшерүүдөгү материалдар',
    'РњР°С‚РµСЂРёР°Р»С‹ РЅР° РїСЂРѕРІРµСЂРєРµ': 'Материалы на проверке',
    'РњРµРЅСЋ': 'Меню',
  };
  var normalized = message;
  replacements.forEach((bad, good) {
    normalized = normalized.replaceAll(bad, good);
  });
  return normalized;
}


String _fieldLabel(AppText text, String rawField) {
  final field = rawField.trim().replaceAll(' ', '_');
  final labels = <String, List<String>>{
    'applicant_name': ['Имя заявителя', 'Өтүнмө ээсинин аты'],
    'position': ['Должность', 'Кызмат орду'],
    'organization_name': ['Название организации', 'Уюмдун аталышы'],
    'organization_type': ['Тип организации', 'Уюмдун түрү'],
    'region': ['Регион', 'Аймак'],
    'official_phone': ['Официальный телефон', 'Расмий телефон'],
    'official_email': ['Официальная почта', 'Расмий электрондук почта'],
    'group_title': ['Название группы', 'Топтун аталышы'],
    'group_description': ['Описание группы', 'Топтун сүрөттөмөсү'],
    'display_name': ['Имя', 'Аты-жөнү'],
    'title': ['Название', 'Аталыш'],
    'description': ['Описание', 'Сүрөттөмө'],
    'reason': ['Причина', 'Себеп'],
    'documents': ['Документы', 'Документтер'],
    'text': ['Текст', 'Текст'],
    'body': ['Текст публикации', 'Жарыянын тексти'],
    'body_text': ['Текст публикации', 'Жарыянын тексти'],
    'comment': ['Комментарий', 'Комментарий'],
    'query': ['Поисковый запрос', 'Издөө суроосу'],
    'password': ['Пароль', 'Сырсөз'],
    'phone': ['Телефон', 'Телефон'],
    'mobile': ['Номер телефона', 'Телефон номери'],
    'code': ['Код', 'Код'],
    'file': ['Файл', 'Файл'],
    'token': ['Токен', 'Токен'],
  };
  final pair = labels[field];
  if (pair == null) return text.isKy ? 'Маалымат' : 'Поле';
  return text.isKy ? pair[1] : pair[0];
}

String? _localizedValidationMessage(AppText text, String message) {
  final normalized = message
      .trim()
      .replaceFirst(RegExp(r'^(api)?exception:\s*', caseSensitive: false), '')
      .replaceFirst(RegExp(r'^formatException:\s*', caseSensitive: false), '')
      .toLowerCase();

  RegExpMatch? match;

  match = RegExp(r'^([a-z_ ]+) must be between (\d+) and (\d+) characters').firstMatch(normalized);
  if (match != null) {
    final field = _fieldLabel(text, match.group(1)!);
    final min = match.group(2)!;
    final max = match.group(3)!;
    return text.isKy
        ? '$field $min–$max белгиден турушу керек.'
        : '$field: от $min до $max символов.';
  }

  match = RegExp(r'^([a-z_ ]+) must be at least (\d+) characters').firstMatch(normalized);
  if (match != null) {
    final field = _fieldLabel(text, match.group(1)!);
    final min = match.group(2)!;
    return text.isKy
        ? '$field кеминде $min белгиден турушу керек.'
        : '$field: минимум $min символов.';
  }

  match = RegExp(r'^([a-z_ ]+) must be at most (\d+) characters').firstMatch(normalized);
  if (match != null) {
    final field = _fieldLabel(text, match.group(1)!);
    final max = match.group(2)!;
    return text.isKy
        ? '$field $max белгиден узун болбошу керек.'
        : '$field: не более $max символов.';
  }

  match = RegExp(r'^([a-z_ ]+) must be less than (\d+) characters').firstMatch(normalized);
  if (match != null) {
    final field = _fieldLabel(text, match.group(1)!);
    final max = match.group(2)!;
    return text.isKy
        ? '$field $max белгиден кыска болушу керек.'
        : '$field: меньше $max символов.';
  }

  match = RegExp(r'^([a-z_ ]+) is required and must be at most (\d+) characters').firstMatch(normalized);
  if (match != null) {
    final field = _fieldLabel(text, match.group(1)!);
    final max = match.group(2)!;
    return text.isKy
        ? '$field толтурулушу жана $max белгиден узун болбошу керек.'
        : '$field обязательно. Максимум $max символов.';
  }

  match = RegExp(r'^([a-z_ ]+) is required').firstMatch(normalized);
  if (match != null) {
    final field = _fieldLabel(text, match.group(1)!);
    return text.isKy ? '$field толтурулушу керек.' : '$field обязательно.';
  }

  match = RegExp(r'only (\d+) photos are allowed').firstMatch(normalized);
  if (match != null) {
    final count = match.group(1)!;
    return text.isKy
        ? '$count сүрөткө чейин гана кошууга болот.'
        : 'Можно добавить не более $count фотографий.';
  }
  match = RegExp(r'only (\d+) video is allowed').firstMatch(normalized);
  if (match != null) {
    return text.isKy
        ? 'Бир гана видео кошууга болот.'
        : 'Можно добавить только одно видео.';
  }

  if (normalized.contains('body text, photo or video is required')) {
    return text.isKy
        ? 'Текст, сүрөт же видео кошуңуз.'
        : 'Добавьте текст, фотографию или видео.';
  }
  if (normalized.contains('code must contain 6 digits')) {
    return text.isKy ? 'Код 6 сандан турушу керек.' : 'Код должен содержать 6 цифр.';
  }
  if (normalized.contains('mobile must be in international format')) {
    return text.isKy
        ? 'Номерди эл аралык форматта жазыңыз: +996700123456.'
        : 'Введите номер в международном формате: +996700123456.';
  }
  if (normalized.contains('too many code requests')) {
    return text.isKy
        ? 'Код өтө көп жолу суралды. Бир аздан кийин аракет кылыңыз.'
        : 'Слишком много запросов кода. Попробуйте позже.';
  }
  if (normalized.contains('please wait before requesting another code')) {
    return text.isKy
        ? 'Жаңы код сураардан мурун бир аз күтүңүз.'
        : 'Подождите перед повторным запросом кода.';
  }
  if (normalized.contains('rate limit exceeded')) {
    return text.isKy
        ? 'Өтө көп аракет жасалды. Бир аздан кийин кайталаңыз.'
        : 'Слишком много действий. Попробуйте немного позже.';
  }
  if (normalized.contains('too many websocket connection attempts')) {
    return text.isKy
        ? 'Туташуу аракеттери өтө көп. Бир аздан кийин кайталаңыз.'
        : 'Слишком много попыток подключения. Попробуйте позже.';
  }

  if (normalized.contains('avatar must be a jpeg') ||
      normalized.contains('group avatar must be a jpeg')) {
    return text.isKy
        ? 'JPEG, PNG же WebP форматындагы сүрөттү тандаңыз.'
        : 'Выберите изображение в формате JPEG, PNG или WebP.';
  }
  if (normalized.contains('avatar data is invalid') ||
      normalized.contains('group avatar data is invalid') ||
      normalized.contains('photo data is invalid') ||
      normalized.contains('video data is invalid') ||
      normalized.contains('invalid file type')) {
    return text.isKy ? 'Файлдын форматы туура эмес.' : 'Неверный формат файла.';
  }
  if (normalized.contains('avatar image must be at most 512 kb') ||
      normalized.contains('group avatar image must be at most 512 kb')) {
    return text.isKy
        ? 'Сүрөттүн көлөмү 512 КБдан ашпашы керек.'
        : 'Размер изображения не должен превышать 512 КБ.';
  }
  if (normalized.contains('file is too large') ||
      normalized.contains('must be less than') && normalized.contains('bytes')) {
    return text.isKy
        ? 'Файл өтө чоң. Кичирээк файлды тандаңыз.'
        : 'Файл слишком большой. Выберите файл меньшего размера.';
  }
  if (normalized.contains('photo data is required') ||
      normalized.contains('video data is required') ||
      normalized.contains('file is required')) {
    return text.isKy ? 'Файлды тандаңыз.' : 'Выберите файл.';
  }
  if (normalized.contains('photo file_id is invalid') ||
      normalized.contains('photo url is invalid')) {
    return text.isKy
        ? 'Сүрөттү ачуу мүмкүн болгон жок.'
        : 'Не удалось обработать фотографию.';
  }
  if (normalized.startsWith('upload failed')) {
    return text.isKy
        ? 'Файлды жүктөө мүмкүн болгон жок.'
        : 'Не удалось загрузить файл.';
  }

  if (normalized.contains('request_type is invalid')) {
    return text.isKy ? 'Жарыянын түрү туура эмес.' : 'Неверный тип публикации.';
  }
  if (normalized.contains('interaction_mode is invalid')) {
    return text.isKy ? 'Иштөө режими туура эмес.' : 'Неверный режим взаимодействия.';
  }
  if (normalized.contains('vote_type must be support or oppose')) {
    return text.isKy ? 'Добуштун түрү туура эмес.' : 'Неверный вариант голосования.';
  }
  if (normalized.contains('visibility must be private or public')) {
    return text.isKy ? 'Топтун көрүнүү түрү туура эмес.' : 'Неверный тип доступа к группе.';
  }
  if (normalized.contains('role must be admin or member')) {
    return text.isKy ? 'Колдонуучунун ролу туура эмес.' : 'Неверная роль пользователя.';
  }
  if (normalized.contains('status is invalid') ||
      normalized.contains('statistics period is invalid') ||
      normalized.contains('content_type is invalid')) {
    return text.isKy ? 'Тандалган маани туура эмес.' : 'Выбрано недопустимое значение.';
  }

  if (normalized.contains('moderation item is already reviewed')) {
    return text.isKy
        ? 'Бул материал мурда эле текшерилген.'
        : 'Этот материал уже проверен.';
  }
  if (normalized.contains('content is not allowed')) {
    return text.isKy
        ? 'Материал модерациядан өткөн жок. Текстти өзгөртүңүз.'
        : 'Материал не прошёл модерацию. Измените текст.';
  }
  if (normalized.contains('custom statistics period requires from and to')) {
    return text.isKy
        ? 'Статистика үчүн башталыш жана аяктоо даталарын тандаңыз.'
        : 'Выберите начальную и конечную даты периода.';
  }
  if (normalized.contains('from must be before to')) {
    return text.isKy
        ? 'Башталыш датасы аяктоо датасынан мурда болушу керек.'
        : 'Начальная дата должна быть раньше конечной.';
  }
  if (normalized.contains('custom statistics period cannot be longer than 370 days')) {
    return text.isKy
        ? 'Статистика мезгили 370 күндөн ашпашы керек.'
        : 'Период статистики не может превышать 370 дней.';
  }

  if (normalized.contains('invalid json body') ||
      normalized.contains('invalid multipart form') ||
      normalized.contains('server returned an invalid response') ||
      normalized.contains('server returned an invalid websocket token response')) {
    return text.isKy
        ? 'Сервер туура эмес жооп берди. Кайра аракет кылыңыз.'
        : 'Сервер вернул некорректный ответ. Попробуйте ещё раз.';
  }
  if (normalized.contains('internal server error') ||
      normalized.contains('database connection interrupted') ||
      normalized.contains('server error')) {
    return text.isKy
        ? 'Серверде ката кетти. Бир аздан кийин кайталаңыз.'
        : 'Ошибка сервера. Попробуйте немного позже.';
  }
  if (normalized.contains('sms sender is disabled') ||
      normalized.contains('sms sender is not configured')) {
    return text.isKy
        ? 'SMS кызматы убактылуу жеткиликсиз.'
        : 'Сервис SMS временно недоступен.';
  }
  if (normalized.contains('missing bearer token') ||
      normalized.contains('refresh_token is required')) {
    return text.isKy
        ? 'Сессия бүттү. Кайра кириңиз.'
        : 'Сессия истекла. Войдите снова.';
  }
  if (normalized.contains('valid email is required')) {
    return text.isKy
        ? 'Туура электрондук почта дарегин жазыңыз.'
        : 'Введите корректный адрес электронной почты.';
  }
  if (normalized.contains('email and password are required')) {
    return text.isKy
        ? 'Электрондук почтаны жана сырсөздү жазыңыз.'
        : 'Введите электронную почту и пароль.';
  }

  return null;
}

String localizedMessage(BuildContext context, String message) {
  final repairedMessage = _normalizeMojibakeMessage(
    _repairMojibake(message),
  );
  final text = AppLanguageScope.textOf(context);
  final lower = repairedMessage.toLowerCase();
  final validationMessage = _localizedValidationMessage(text, repairedMessage);
  if (validationMessage != null) return validationMessage;

  if (lower.contains('comments are blocked until')) {
    final raw = repairedMessage
        .replaceFirst(
            RegExp(r'comments are blocked until\s*', caseSensitive: false), '')
        .trim();
    final value = _formatMuteUntil(raw);
    return text.isKy
        ? 'Комментарий жазуу $value чейин бөгөттөлгөн.'
        : 'Комментарии заблокированы до $value.';
  }
  if (lower.contains('comments are blocked')) {
    return text.isKy
        ? 'Комментарий жазуу бөгөттөлгөн.'
        : 'Комментарии заблокированы.';
  }

  if (lower.contains(String.fromCharCodes([
    99,
    111,
    110,
    116,
    101,
    110,
    116,
    32,
    105,
    115,
    32,
    116,
    101,
    109,
    112,
    111,
    114,
    97,
    114,
    105,
    108,
    121,
    32,
    108,
    105,
    109,
    105,
    116,
    101,
    100
  ]))) {
    return text.isKy
        ? 'Модерация көп жолу четке каккандыктан, билдирүү убактылуу чектелди. Бир аздан кийин аракет кылыңыз.'
        : 'Сообщения временно ограничены после частых отклонений модерацией. Попробуйте позже.';
  }
  if (lower.contains(String.fromCharCodes([
    99,
    111,
    110,
    116,
    101,
    110,
    116,
    32,
    105,
    115,
    32,
    110,
    111,
    116,
    32,
    97,
    108,
    108,
    111,
    119,
    101,
    100
  ]))) {
    return text.isKy
        ? 'Материал модерациядан өткөн жок. Текстти өзгөртүп кайра жөнөтүңүз.'
        : 'Материал не прошёл модерацию. Измените текст и отправьте заново.';
  }

  if (lower.contains('status updated')) {
    return text.isKy ? 'Статус жаңыртылды.' : 'Статус обновлён.';
  }
  if (lower.contains('comment deleted')) {
    return text.isKy ? 'Комментарий өчүрүлдү.' : 'Комментарий удалён.';
  }
  if (lower.contains('comment added')) {
    return text.isKy ? 'Комментарий кошулду.' : 'Комментарий добавлен.';
  }
  if (lower.contains('request updated')) {
    return text.isKy ? 'Өтүнүч жаңыртылды.' : 'Заявка обновлена.';
  }
  if (lower.contains('request sent')) {
    return text.isKy ? 'Өтүнүч жөнөтүлдү.' : 'Заявка отправлена.';
  }
  if (lower.contains('post published')) return text.postPublished;
  if (lower.contains('invitation sent')) {
    return text.isKy ? 'Чакыруу жөнөтүлдү.' : 'Приглашение отправлено.';
  }
  if (lower.contains('invitation accepted')) {
    return text.isKy ? 'Чакыруу кабыл алынды.' : 'Приглашение принято.';
  }
  if (lower.contains('invitation declined')) {
    return text.isKy ? 'Чакыруу четке кагылды.' : 'Приглашение отклонено.';
  }
  if (lower.contains('session expired')) {
    return text.isKy
        ? 'Сессия бүттү. Кайра кириңиз.'
        : 'Сессия истекла. Войдите снова.';
  }
  if (lower.contains('connection timed out')) {
    return text.isKy
        ? 'Сервер жооп берген жок. Кайра аракет кылыңыз.'
        : 'Сервер не ответил вовремя. Попробуйте ещё раз.';
  }
  if (lower.contains('network error')) {
    return text.isKy
        ? 'Тармак катасы. Интернетти же серверди текшериңиз.'
        : 'Ошибка сети. Проверьте интернет или сервер.';
  }
  if (lower.contains('server error')) {
    return text.isKy ? 'Сервер катасы.' : 'Ошибка сервера.';
  }
  if (lower.contains('mobile must be in international format')) {
    return text.isKy
        ? 'Номерди эл аралык форматта жазыңыз: +996700123456'
        : 'Введите номер в международном формате: +996700123456';
  }
  if (lower.contains('code is required')) return text.codeRequired;
  if (lower.contains('display_name is required')) {
    return text.displayNameRequiredForNewAccount;
  }
  if (lower.contains('display_name must be between')) {
    return text.isKy
        ? 'Аты-жөнү 2ден 40 белгиге чейин болушу керек.'
        : 'Имя должно быть от 2 до 40 символов.';
  }
  if (lower.contains('invalid email or password') ||
      lower.contains('invalid credentials')) {
    return text.isKy ? 'Маалымат туура эмес.' : 'Неверные данные.';
  }
  if (lower.contains('unauthorized')) {
    return text.isKy
        ? 'Кирүү укугу жок. Кайра кириңиз.'
        : 'Нет доступа. Войдите снова.';
  }
  if (lower.contains('forbidden')) {
    return text.isKy
        ? 'Бул аракетке уруксат жок.'
        : 'Нет разрешения на это действие.';
  }
  if (lower.contains('title must be between')) {
    return text.isKy
        ? 'Аталыш 3төн 80 белгиге чейин болушу керек.'
        : 'Название должно быть от 3 до 80 символов.';
  }
  if (lower.contains('description must be at most')) {
    return text.isKy ? 'Сүрөттөмө өтө узун.' : 'Описание слишком длинное.';
  }
  if (lower.contains('text is required')) {
    return text.isKy ? 'Текст жазыңыз.' : 'Введите текст.';
  }
  if (lower.contains('body is required')) {
    return text.isKy ? 'Текст жазыңыз.' : 'Введите текст.';
  }
  if (lower.contains('not found')) {
    return text.isKy ? 'Табылган жок.' : 'Не найдено.';
  }
  if (lower.contains('already')) {
    return text.isKy ? 'Бул аракет мурун эле жасалган.' : 'Это уже выполнено.';
  }

  final looksLikeEnglishError = RegExp(
    r'\b(error|invalid|failed|failure|required|must|forbidden|unauthorized|not found|too many|too large|cannot|unable|missing|expired|unavailable|interrupted|unsupported|denied|blocked|exceeded)\b',
    caseSensitive: false,
  ).hasMatch(repairedMessage);
  if (looksLikeEnglishError) {
    return text.isKy
        ? 'Аракетти аткаруу мүмкүн болгон жок. Кайра аракет кылыңыз.'
        : 'Не удалось выполнить действие. Попробуйте ещё раз.';
  }
  return repairedMessage;
}

OverlayEntry? _activeNoticeEntry;
Timer? _activeNoticeTimer;

void _removeActiveNotice() {
  _activeNoticeTimer?.cancel();
  _activeNoticeTimer = null;
  final entry = _activeNoticeEntry;
  _activeNoticeEntry = null;
  if (entry != null && entry.mounted) entry.remove();
}

void showAppSnack(BuildContext context, String message) {
  final localized = localizedMessage(context, message);
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(localized),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    return;
  }

  final topPadding = MediaQuery.paddingOf(context).top;
  final colors = context.appColors;
  final brightness = Theme.of(context).brightness;
  final closeLabel = AppLanguageScope.textOf(context).close;
  _removeActiveNotice();

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => Positioned(
      top: topPadding + 12,
      left: 14,
      right: 14,
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        tween: Tween<double>(begin: 0, end: 1),
        builder: (_, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, -18 * (1 - value)),
            child: child,
          ),
        ),
        child: _TopAppNotice(
          message: localized,
          colors: colors,
          brightness: brightness,
          closeLabel: closeLabel,
          onDismiss: _removeActiveNotice,
        ),
      ),
    ),
  );

  _activeNoticeEntry = entry;
  overlay.insert(entry);
  _activeNoticeTimer = Timer(const Duration(milliseconds: 2600), () {
    if (identical(_activeNoticeEntry, entry)) _removeActiveNotice();
  });
}

class _TopAppNotice extends StatelessWidget {
  const _TopAppNotice({
    required this.message,
    required this.colors,
    required this.brightness,
    required this.closeLabel,
    required this.onDismiss,
  });

  final String message;
  final MobileChatColors colors;
  final Brightness brightness;
  final String closeLabel;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final dark = brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: Semantics(
        liveRegion: true,
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.fromLTRB(14, 11, 8, 11),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.34 : 0.16),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: MobileChatTheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: MobileChatTheme.primary,
                  size: 19,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  message,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textStrong,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ),
              IconButton(
                onPressed: onDismiss,
                tooltip: closeLabel,
                icon: Icon(Icons.close_rounded, color: colors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF3A2026) : const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: dark ? const Color(0xFF7F2D3A) : const Color(0xFFFFCDD2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Colors.redAccent, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              localizedMessage(context, message),
              style: TextStyle(color: colors.textStrong),
            ),
          ),
        ],
      ),
    );
  }
}

class InfoBanner extends StatelessWidget {
  const InfoBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF19364A) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: dark ? const Color(0xFF2A5F82) : const Color(0xFFBFDBFE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              color: MobileChatTheme.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              localizedMessage(context, message),
              style: TextStyle(color: colors.textStrong),
            ),
          ),
        ],
      ),
    );
  }
}
