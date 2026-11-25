import 'dart:async';

import 'package:flutter/material.dart';

import 'preferences_store.dart';
import 'theme.dart';

enum AppLanguage { ru, ky }

extension AppLanguageMeta on AppLanguage {
  String get shortName => this == AppLanguage.ky ? 'KG' : 'RU';
  String get displayName => this == AppLanguage.ky ? 'Кыргызча' : 'Русский';
}

class AppLanguageController extends ChangeNotifier {
  AppLanguageController({
    AppPreferencesStore store = const AppPreferencesStore(),
  }) : _store = store;

  final AppPreferencesStore _store;
  AppLanguage _language = AppLanguage.ru;

  AppLanguage get language => _language;
  AppText get text => AppText(_language);

  Future<void> restore() async {
    try {
      final stored = await _store.readLanguage();
      final restored = AppLanguage.values.where((value) => value.name == stored);
      if (restored.isEmpty || restored.first == _language) return;
      _language = restored.first;
      notifyListeners();
    } catch (_) {
      // Keep the default language when local storage is unavailable.
    }
  }

  void setLanguage(AppLanguage value) {
    if (_language == value) return;
    _language = value;
    notifyListeners();
    unawaited(_persistLanguage(value));
  }

  Future<void> _persistLanguage(AppLanguage value) async {
    try {
      await _store.writeLanguage(value.name);
    } catch (_) {
      // The in-memory choice remains active even if persistence fails.
    }
  }
}

class AppLanguageScope extends InheritedNotifier<AppLanguageController> {
  const AppLanguageScope(
      {super.key,
      required AppLanguageController controller,
      required super.child})
      : super(notifier: controller);

  static AppLanguageController controllerOf(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppLanguageScope>();
    assert(scope != null, 'AppLanguageScope not found in widget tree');
    return scope!.notifier!;
  }

  static AppText textOf(BuildContext context) => controllerOf(context).text;
}

class LanguageMenuButton extends StatelessWidget {
  const LanguageMenuButton({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final controller = AppLanguageScope.controllerOf(context);
    final colors = context.appColors;
    return PopupMenuButton<AppLanguage>(
      tooltip: controller.text.languageLabel,
      color: colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: colors.border)),
      onSelected: controller.setLanguage,
      itemBuilder: (_) => AppLanguage.values
          .map((language) => PopupMenuItem<AppLanguage>(
                value: language,
                child: Row(children: [
                  if (language == controller.language)
                    const Icon(Icons.check_rounded,
                        size: 18, color: KoomTheme.primary)
                  else
                    const SizedBox(width: 18),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      language.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textStrong,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ]),
              ))
          .toList(),
      child: compact
          ? SizedBox(
              // Material minimum touch target.
              width: 48,
              height: 48,
              child: Center(
                child: Icon(
                  Icons.language_rounded,
                  color: KoomTheme.primary,
                  size: 21,
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: colors.border),
                  color: colors.surfaceSoft,
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.language_rounded,
                        color: KoomTheme.primary, size: 18),
                    const SizedBox(width: 6),
                    Text(controller.language.shortName,
                        style: TextStyle(
                            color: colors.textStrong,
                            fontWeight: FontWeight.w800)),
                  ]),
                ),
              ),
            ),
    );
  }
}

class AppText {
  const AppText(this.currentLanguage);

  final AppLanguage currentLanguage;
  bool get isKy => currentLanguage == AppLanguage.ky;

  String get appTitle => 'Koom';
  String get languageLabel => isKy ? 'Тил' : 'Язык';
  String get groups => isKy ? 'Топтор' : 'Группы';
  String get adminRequests => isKy ? 'Админ өтүнүчтөрү' : 'Заявки админу';
  String get myRequests => isKy ? 'Менин өтүнүчтөрүм' : 'Мои заявки';
  String get groupRequests => isKy ? 'Топ өтүнүчтөрү' : 'Заявки на группы';
  String get requestGroup => isKy ? 'Топ ачууга өтүнүч' : 'Заявка на группу';
  String get invitations => isKy ? 'Чакыруулар' : 'Приглашения';
  String get joinByCode => isKy ? 'Код менен кирүү' : 'Войти по коду';
  String get scanQr => isKy ? 'QR сканерлөө' : 'Сканировать QR';
  String get profile => isKy ? 'Профиль' : 'Профиль';
  String get createGroup => isKy ? 'Топ түзүү' : 'Создать группу';
  String get newGroup => isKy ? 'Жаңы топ' : 'Новая группа';
  String get logout => isKy ? 'Чыгуу' : 'Выйти';
  String get accountDeletion => isKy ? 'Аккаунтту өчүрүү' : 'Удаление аккаунта';
  String get accountDeletionDescription => isKy
      ? 'Аккаунт жана ага байланышкан жеке маалыматтар өчүрүлөт.'
      : 'Аккаунт и связанные с ним персональные данные будут удалены.';
  String get deleteAccount => isKy ? 'Аккаунтту өчүрүү' : 'Удалить аккаунт';
  String get deletedAccount => isKy ? 'Өчүрүлгөн аккаунт' : 'Удалённый аккаунт';
  String get deleteAccountConfirmTitle =>
      isKy ? 'Аккаунтту өчүрөсүзбү?' : 'Удалить аккаунт?';
  String get deleteAccountConfirmBody => isKy
      ? 'Профиль, телефон номери, сессиялар, добуштар жана топтук билдирүүлөр өчүрүлөт. Коомдук кайрылуулар, комментарийлер жана алардын медиафайлдары автору көрсөтүлбөй сакталат. Текстте өзүңүз жазган же медиафайлдардан көрүнгөн жеке маалымат автоматтык түрдө өчүрүлбөйт. Сиз ээлик кылган топ башка катышуучуга өткөрүлөт. Бул аракет артка кайтарылбайт.'
      : 'Профиль, номер телефона, сессии, голоса и сообщения в групповых чатах будут удалены. Публичные обращения, комментарии и прикреплённые медиафайлы останутся без связи с автором. Персональные сведения, которые вы указали в тексте или которые видны на медиафайлах, автоматически не удаляются. Ваши группы перейдут другому участнику. Действие нельзя отменить.';
  String get accountDeletionNeedsGroupMember => isKy
      ? 'Сиз ээ болгон топтордун биринде башка катышуучу жок. Алгач топко катышуучуну чакырып, андан кийин аккаунтту өчүрүңүз.'
      : 'В одной из ваших групп нет другого участника. Сначала пригласите человека в группу, затем удалите аккаунт.';
  String get noGroupsYet => isKy ? 'Азырынча топ жок' : 'Пока нет групп';
  String get noGroups => noGroupsYet;
  String get createGroupOrApprove => isKy
      ? 'Топ түзүңүз же өтүнүчтөрдү бекитиңиз.'
      : 'Создайте группу или одобрите заявки.';
  String get sendGroupRequestOrJoin => isKy
      ? 'Расмий топко өтүнүч жөнөтүңүз же код менен кириңиз.'
      : 'Отправьте заявку на группу или войдите по коду.';
  String get publicGroup => isKy ? 'Ачык топ' : 'Открытая группа';
  String get privateGroup => isKy ? 'Жабык топ' : 'Закрытая группа';
  String get copyInviteCode =>
      isKy ? 'Чакыруу кодун көчүрүү' : 'Скопировать код приглашения';
  String get inviteCodeCopied =>
      isKy ? 'Чакыруу коду көчүрүлдү.' : 'Код приглашения скопирован.';
  String get enterMobileNumber => isKy
      ? 'Телефон номериңизди жазыңыз. Биз SMS аркылуу алты орундуу код жөнөтөбүз.'
      : 'Введите номер телефона. Мы отправим шестизначный код по SMS.';
  String get mobileNumber => isKy ? 'Телефон номери' : 'Номер телефона';
  String get groupMember => isKy ? 'Топтун катышуучусу' : 'Участник группы';
  String get code => 'Код';
  String get displayNameNewOnly =>
      isKy ? 'Жаңы аккаунт үчүн аты-жөнү' : 'Имя только для нового аккаунта';
  String get continueText => isKy ? 'Улантуу' : 'Продолжить';
  String get pleaseWait => isKy ? 'Күтө туруңуз...' : 'Подождите...';
  String get verifyAndContinue => isKy ? 'Кодду текшерүү' : 'Проверить код';
  String get changeMobileNumber => isKy ? 'Номерди өзгөртүү' : 'Изменить номер';
  String get codeRequired => isKy ? 'Кодду жазыңыз' : 'Введите код';
  String get resendCode =>
      isKy ? 'Кодду кайра жөнөтүү' : 'Отправить код заново';
  String resendCodeIn(int seconds) => isKy
      ? 'Кодду $seconds сек. кийин кайра жөнөтө аласыз'
      : 'Отправить код заново можно через $seconds сек.';
  String get displayNameRequiredForNewAccount => isKy
      ? 'Жаңы аккаунт үчүн аты-жөнүңүздү жазыңыз'
      : 'Для нового аккаунта нужно указать имя';
  String get existingAccountHint => isKy
      ? 'Аккаунт табылды. Кодду гана жазыңыз.'
      : 'Аккаунт найден. Введите только код.';
  // Shown whenever the server does not say the account exists, which is
  // every time now: the number may belong to a returning user.
  String get newAccountHint => isKy
      ? 'Кодду жазыңыз. Аты-жөнү жаңы аккаунт үчүн гана керек.'
      : 'Введите код. Имя нужно только для нового аккаунта.';
  String get newest => isKy ? 'Жаңылары' : 'Новые';
  String get popular => isKy ? 'Популярдуу' : 'Популярные';
  String get resolved => isKy ? 'Чечилген' : 'Решённые';
  String get mine => isKy ? 'Менин' : 'Мои';
  String get newPost => isKy ? 'Жаңы жарыя' : 'Новая публикация';
  String get noPostsYet => isKy ? 'Азырынча жарыя жок' : 'Пока нет публикаций';
  String get noPopularPosts =>
      isKy ? 'Популярдуу жарыя жок' : 'Популярных публикаций нет';
  String get noResolvedPosts =>
      isKy ? 'Чечилген жарыя жок' : 'Решённых публикаций нет';
  String get noMyPosts =>
      isKy ? 'Сиз жарыя түзө элексиз' : 'Вы ещё не создавали публикации';
  String get postsDescription => isKy
      ? 'Жарыялар, сунуштар, арыздар, идеялар ушул жерде чыгат.'
      : 'Публикации, предложения, жалобы и идеи будут здесь.';
  String get postPublished => isKy ? 'Жарыя кошулду.' : 'Публикация добавлена.';
  String get postType => isKy ? 'Жарыя түрү' : 'Тип публикации';
  String get announcement => isKy ? 'Кулактандыруу' : 'Объявление';
  String get suggestion => isKy ? 'Сунуш' : 'Предложение';
  String get complaint => isKy ? 'Арыз' : 'Жалоба';
  String get requirement => isKy ? 'Талап' : 'Требование';
  String get problem => isKy ? 'Көйгөй' : 'Проблема';
  String get idea => 'Идея';
  String get interactionMode => isKy ? 'Иштөө режими' : 'Режим взаимодействия';
  String get textOnly => isKy ? 'Текст гана' : 'Только текст';
  String get votingOnly => isKy ? 'Добуш берүү гана' : 'Только голосование';
  String get discussionWithComments =>
      isKy ? 'Комментарий менен талкуу' : 'Обсуждение с комментариями';
  String get title => isKy ? 'Аталышы' : 'Заголовок';
  String get description => isKy ? 'Сүрөттөмө' : 'Описание';
  String get publish => isKy ? 'Жарыялоо' : 'Опубликовать';
  String get publishing => isKy ? 'Жарыяланып жатат...' : 'Публикуется...';
  String get read => isKy ? 'Окуу' : 'Читать';
  String get readPost => isKy ? 'Жарыяны окуу' : 'Читать публикацию';
  String get comments => isKy ? 'Комментарийлер' : 'Комментарии';
  String get noCommentsYet =>
      isKy ? 'Комментарий жок.' : 'Комментариев пока нет.';
  String get readOnlyPost =>
      isKy ? 'Бул жарыя окуу үчүн гана.' : 'Эта публикация только для чтения.';
  String get voteOnlyPost => isKy
      ? 'Бул жарыяда добуш гана берилет. Комментарий өчүрүлгөн.'
      : 'В этой публикации доступно только голосование. Комментарии отключены.';
  String get addComment => isKy ? 'Комментарий кошуу' : 'Добавить комментарий';
  String get adminStatus => isKy ? 'Админ статусу' : 'Статус администратора';
  String get statusNew => isKy ? 'Жаңы' : 'Новая';
  String get statusUnderReview => isKy ? 'Каралууда' : 'На рассмотрении';
  String get statusAccepted => isKy ? 'Кабыл алынды' : 'Принята';
  String get statusRejected => isKy ? 'Четке кагылды' : 'Отклонена';
  String get statusResolved => isKy ? 'Чечилди' : 'Решена';
  String get manageAdmins =>
      isKy ? 'Админдерди башкаруу' : 'Управление админами';
  String get manageAdminsHint => isKy
      ? 'Топтун катышуучусунун телефон номерин жазыңыз.'
      : 'Введите номер телефона участника группы.';
  String get manageAdminsDescription => isKy
      ? 'Ээси катышуучуну админ кылып дайындай алат же админ укугун алып сала алат.'
      : 'Владелец может назначить участника админом или снять права админа.';
  String get makeAdmin => isKy ? 'Админ кылуу' : 'Сделать админом';
  String get removeAdmin => isKy ? 'Админден алуу' : 'Снять админа';
  String get adminAssigned => isKy ? 'Админ дайындалды.' : 'Админ назначен.';
  String get adminRemoved => isKy ? 'Админ укугу алынды.' : 'Админ снят.';
  String get statistics => isKy ? 'Статистика' : 'Статистика';
  String get codeAndQr => isKy ? 'Код жана QR' : 'Код и QR';
  String get inviteByPhone =>
      isKy ? 'Телефон менен чакыруу' : 'Пригласить по телефону';
  String get lightMode => isKy ? 'Жарык режим' : 'Светлый режим';
  String get darkMode => isKy ? 'Караңгы режим' : 'Тёмный режим';
  String get settings => isKy ? 'Жөндөөлөр' : 'Настройки';
  String get close => isKy ? 'Жабуу' : 'Закрыть';
  String get blockComments =>
      isKy ? 'Комментарийди бөгөттөө' : 'Блок комментариев';
  String get blockCommentsDescription => isKy
      ? 'Колдонуучу окуй алат, бирок комментарий жаза албайт.'
      : 'Пользователь сможет читать, но не сможет писать комментарии.';
  String get blockCommentsButton => isKy ? 'Бөгөттөө' : 'Заблокировать';
  String get unblockCommentsButton =>
      isKy ? 'Бөгөттөн чыгаруу' : 'Разблокировать';
  String get blockDuration => isKy ? 'Мөөнөт' : 'Срок';
  String get blockReason => isKy ? 'Себеп' : 'Причина';
  String get mutedDone =>
      isKy ? 'Комментарий жазуу бөгөттөлдү.' : 'Комментарии заблокированы.';
  String get unmutedDone => isKy ? 'Бөгөт алынды.' : 'Блок снят.';
  String get oneHour => isKy ? '1 саат' : '1 час';
  String get threeHours => isKy ? '3 саат' : '3 часа';
  String get sixHours => isKy ? '6 саат' : '6 часов';
  String get twelveHours => isKy ? '12 саат' : '12 часов';
  String get oneDay => isKy ? '1 күн' : '1 день';
  String get sevenDays => isKy ? '7 күн' : '7 дней';
  String get thirtyDays => isKy ? '30 күн' : '30 дней';
  String get forever => isKy ? 'Түбөлүк' : 'Навсегда';
  String get featureNotAvailableYet => isKy
      ? 'Бул функция серверде азырынча жеткиликсиз. Кийинчерээк аракет кылыңыз.'
      : 'Эта функция пока недоступна на сервере. Попробуйте позже.';
  String get cancel => isKy ? 'Жокко чыгаруу' : 'Отмена';
  String get groupMembers => isKy ? 'Катышуучулар' : 'Участники';
  String get removeFromGroup => isKy ? 'Топтон чыгаруу' : 'Удалить из группы';
  String get removeFromGroupConfirmTitle =>
      isKy ? 'Катышуучуну топтон чыгарасызбы?' : 'Удалить участника из группы?';
  String removeFromGroupConfirmBody(String name) => isKy
      ? '$name топтон чыгарылат. Кайра кошулуу үчүн ага жаңы чакыруу керек болот.'
      : '$name будет удалён из группы. Чтобы вернуться, ему понадобится новое приглашение.';
  String get memberRemoved =>
      isKy ? 'Катышуучу топтон чыгарылды.' : 'Участник удалён из группы.';
  String get rotateInviteCode => isKy ? 'Кодду алмаштыруу' : 'Сменить код';
  String get rotateInviteCodeConfirmTitle =>
      isKy ? 'Чакыруу кодун алмаштырасызбы?' : 'Сменить код приглашения?';
  String get rotateInviteCodeConfirmBody => isKy
      ? 'Жаңы код түзүлөт. Эски код жана эски QR код мындан ары иштебейт.'
      : 'Будет создан новый код. Старый код и старый QR-код перестанут работать.';
  String get inviteCodeRotated =>
      isKy ? 'Чакыруу коду алмаштырылды.' : 'Код приглашения изменён.';
  String get inviteCodeAdminsOnly => isKy
      ? 'Чакыруу кодун топтун ээси же админдери гана бөлүшө алат.'
      : 'Делиться кодом приглашения могут только владелец и администраторы группы.';
  String get logoutAllDevices =>
      isKy ? 'Бардык түзмөктөрдөн чыгуу' : 'Выйти на всех устройствах';
  String get logoutAllDevicesDescription => isKy
      ? 'Аккаунтуңуз бардык телефондордо, ушул түзмөктү кошо, жабылат.'
      : 'Аккаунт будет закрыт на всех телефонах, включая этот.';
  String get logoutAllDevicesConfirmTitle => isKy
      ? 'Бардык түзмөктөрдөн чыгасызбы?'
      : 'Выйти на всех устройствах?';
  String get logoutAllDevicesConfirmBody => isKy
      ? 'Бардык түзмөктөрдөгү сессиялар жабылат. Кайра кирүү үчүн SMS-код керек болот.'
      : 'Все сеансы на всех устройствах будут завершены. Для повторного входа понадобится SMS-код.';
  String get notificationFallbackTitle => 'Koom';
  String get notificationFallbackBody => isKy
      ? 'Жаңылыкты көрүү үчүн тиркемени ачыңыз.'
      : 'Откройте приложение, чтобы посмотреть обновление.';
  String get notificationChannelName =>
      isKy ? 'Koom билдирмелери' : 'Уведомления Koom';
  String get notificationChannelDescription => isKy
      ? 'Koomдогу жаңы жарыялар жана комментарийлер тууралуу билдирмелер.'
      : 'Уведомления о новых публикациях и комментариях в Koom.';
  String get uploadQuotaExceeded => isKy
      ? 'Бүгүнкү файл жүктөө лимити түгөндү. Эртең кайра аракет кылыңыз.'
      : 'Дневной лимит загрузки файлов исчерпан. Попробуйте завтра.';
  String get avatarTooLarge => isKy
      ? 'Сүрөт өтө чоң. Көлөмү кичирээк сүрөт тандаңыз.'
      : 'Фото слишком большое. Выберите снимок меньшего размера.';

  // Content moderation queue.
  String get moderationQueueTitle => isKy ? 'Текшерүүдө' : 'На проверке';
  String get refresh => isKy ? 'Жаңыртуу' : 'Обновить';
  String get moderationQueueEmptyTitle =>
      isKy ? 'Тизме бош' : 'Очередь пуста';
  String get moderationQueueEmptyMessage => isKy
      ? 'Текшерүүдө жаңы комментарий жана жарыя жок.'
      : 'Новых комментариев и публикаций на проверке нет.';
  String get moderationApproved =>
      isKy ? 'Материал бекитилди.' : 'Материал одобрен.';
  String get moderationRejected =>
      isKy ? 'Материал четке кагылды.' : 'Материал отклонен.';
  String get author => 'Автор';
  String get reason => isKy ? 'Себеп' : 'Причина';
  String get moderationCheck => isKy ? 'Текшерүү' : 'Проверка';
  String get emptyBodyText => isKy ? 'Текст бош' : 'Текст пустой';
  String get reject => isKy ? 'Четке кагуу' : 'Отклонить';
  String get approve => isKy ? 'Бекитүү' : 'Одобрить';

  // --- Post card, voting, media and comments -------------------------------
  String get unnamedUser => isKy ? 'Колдонуучу' : 'Пользователь';
  String get voting => isKy ? 'Добуш берүү' : 'Голосование';
  String get votesLabel => isKy ? 'Добуш' : 'Голосов';
  String get voteSupport => isKy ? 'Колдойм' : 'Поддерживаю';
  String get voteOppose => isKy ? 'Колдобойм' : 'Не поддерживаю';
  String get voteToggleHint => isKy
      ? 'Тандалган вариантты кайра бассаңыз, добуш өчүрүлөт.'
      : 'Нажмите выбранный вариант ещё раз, чтобы убрать голос.';
  String get justNow => isKy ? 'азыр эле' : 'только что';
  String get minuteShort => isKy ? 'мүн' : 'мин';
  String get hourShort => isKy ? 'саат' : 'ч';
  String get dayShort => isKy ? 'күн' : 'дн';
  String get moreActions => isKy ? 'Дагы' : 'Ещё';
  String get deleteItem => isKy ? 'Өчүрүү' : 'Удалить';
  String get sendComment => isKy ? 'Жөнөтүү' : 'Отправить';
  String get beFirstToComment => isKy
      ? 'Биринчи болуп пикириңизди жазыңыз.'
      : 'Напишите первый комментарий.';
  String get photosLabel => isKy ? 'Сүрөттөр' : 'Фото';
  String get videosLabel => isKy ? 'Видеолор' : 'Видео';
  String get mediaUnavailable =>
      isKy ? 'Медиа жеткиликсиз' : 'Медиа недоступно';
  String get photoTooLarge => isKy
      ? 'Сүрөт өтө чоң. Башка сүрөт тандаңыз.'
      : 'Фото слишком большое. Выберите другое фото.';
  String get videoTooLarge => isKy
      ? 'Видео өтө чоң. 12 MB чейин видео тандаңыз.'
      : 'Видео слишком большое. Выберите видео до 12 MB.';
  String get mediaLimitsHint => isKy
      ? 'Эң көп 3 сүрөт. Видео 12 MB чейин.'
      : 'Максимум 3 фото. Видео до 12 MB.';
  String get addTextOrMedia => isKy
      ? 'Текст, сүрөт же видео кошуңуз.'
      : 'Добавьте текст, фото или видео.';
  String get addVideo => isKy ? 'Видео кошуу' : 'Добавить видео';
  String get videoAdded => isKy ? 'Видео кошулду' : 'Видео добавлено';
  String get photoLabel => isKy ? 'Сүрөт' : 'Фото';
  // Root bottom navigation.
  String get notifications => isKy ? 'Билдирүүлөр' : 'Уведомления';

  // Groups tab.
  String get searchGroupsHint => isKy ? 'Топтордон издөө' : 'Поиск по группам';
  String get clearSearch => isKy ? 'Издөөнү тазалоо' : 'Очистить поиск';
  String get groupsSearchEmptyTitle =>
      isKy ? 'Топ табылган жок' : 'Группы не найдены';
  String get groupsSearchEmptyMessage => isKy
      ? 'Издөө сөзүн өзгөртүп көрүңүз.'
      : 'Попробуйте изменить поисковый запрос.';

  // Notifications tab.
  String get allFilter => isKy ? 'Баары' : 'Все';
  String get noNotificationsTitle => isKy ? 'Билдирүү жок' : 'Уведомлений нет';
  String get noNotificationsMessage => isKy
      ? 'Топко чакыруулар жана топтордогу жаңы жарыялар ушул жерде чыгат.'
      : 'Приглашения в группы и новые публикации в ваших группах появятся здесь.';
  String get noInvitationsTitle => isKy ? 'Чакыруу жок' : 'Приглашений нет';
  String get noInvitationsMessage => isKy
      ? 'Топко чакыруулар ушул жерде чыгат.'
      : 'Приглашения в группы появятся здесь.';
  String get newPostsSectionTitle =>
      isKy ? 'Жаңы жарыялар' : 'Новые публикации';
  String newPostsInGroup(String group) => isKy
      ? '«$group» тобунда жаңы жарыялар'
      : 'Новые публикации в «$group»';
  String newPostsCount(int count) => isKy
      ? '$count жаңы жарыя'
      : '$count ${_ruPlural(count, 'новая публикация', 'новые публикации', 'новых публикаций')}';
  String invitationsCountLabel(int count) => isKy
      ? '$count жаңы чакыруу'
      : '$count ${_ruPlural(count, 'новое приглашение', 'новых приглашения', 'новых приглашений')}';
  String get invitedBy => isKy ? 'Чакырган' : 'Пригласил';
  String get invitationNew => isKy ? 'Жаңы' : 'Новое';
  String get acceptInvitation => isKy ? 'Кабыл алуу' : 'Принять';
  String get declineInvitation => isKy ? 'Баш тартуу' : 'Отклонить';
  String get invitationAccepted =>
      isKy ? 'Чакыруу кабыл алынды.' : 'Приглашение принято.';
  String get invitationDeclined =>
      isKy ? 'Чакыруу четке кагылды.' : 'Приглашение отклонено.';

  // Tabs inside a group.
  String get groupFeed => isKy ? 'Агым' : 'Лента';
  String get groupModeration => isKy ? 'Текшерүү' : 'Модерация';

  // Rare group actions that stay in the group overflow menu.
  String get reports => isKy ? 'Даттануулар' : 'Жалобы';
  String get changeGroupPhoto =>
      isKy ? 'Топтун сүрөтүн өзгөртүү' : 'Изменить фото группы';
  String get uploading => isKy ? 'Жүктөлүүдө...' : 'Загрузка...';
}

/// Picks the Russian plural form for [count] (1 / 2-4 / 5+), so counted
/// labels read naturally instead of always using the genitive plural.
String _ruPlural(int count, String one, String few, String many) {
  final mod10 = count % 10;
  final mod100 = count % 100;
  if (mod10 == 1 && mod100 != 11) return one;
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return few;
  return many;
}
