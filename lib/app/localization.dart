import 'package:flutter/material.dart';

import 'theme.dart';

enum AppLanguage { ru, ky }

extension AppLanguageMeta on AppLanguage {
  String get shortName => this == AppLanguage.ky ? 'KG' : 'RU';
  String get displayName => this == AppLanguage.ky ? 'Кыргызча' : 'Русский';
}

class AppLanguageController extends ChangeNotifier {
  AppLanguage _language = AppLanguage.ru;
  AppLanguage get language => _language;
  AppText get text => AppText(_language);

  void setLanguage(AppLanguage value) {
    if (_language == value) return;
    _language = value;
    notifyListeners();
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
  const LanguageMenuButton({super.key});

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
                        size: 18, color: MobileChatTheme.primary)
                  else
                    const SizedBox(width: 18),
                  const SizedBox(width: 8),
                  Text(language.displayName,
                      style: TextStyle(
                          color: colors.textStrong,
                          fontWeight: FontWeight.w700)),
                ]),
              ))
          .toList(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: colors.border),
            color: colors.surfaceSoft,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.language_rounded,
                  color: MobileChatTheme.primary, size: 18),
              const SizedBox(width: 6),
              Text(controller.language.shortName,
                  style: TextStyle(
                      color: colors.textStrong, fontWeight: FontWeight.w800)),
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
      ? 'Телефон номериңизди жазыңыз. Тест үчүн код: 123.'
      : 'Введите номер телефона. Для теста используйте код 123.';
  String get mobileNumber => isKy ? 'Телефон номери' : 'Номер телефона';
  String get code => 'Код';
  String get localTestCode =>
      isKy ? 'Тест үчүн 123 жазыңыз' : 'Для теста введите 123';
  String get displayNameNewOnly =>
      isKy ? 'Жаңы аккаунт үчүн аты-жөнү' : 'Имя только для нового аккаунта';
  String get continueText => isKy ? 'Улантуу' : 'Продолжить';
  String get pleaseWait => isKy ? 'Күтө туруңуз...' : 'Подождите...';
  String get verifyAndContinue => isKy ? 'Кодду текшерүү' : 'Проверить код';
  String get changeMobileNumber => isKy ? 'Номерди өзгөртүү' : 'Изменить номер';
  String get codeRequired => isKy ? 'Кодду жазыңыз' : 'Введите код';
  String get displayNameRequiredForNewAccount => isKy
      ? 'Жаңы аккаунт үчүн аты-жөнүңүздү жазыңыз'
      : 'Для нового аккаунта нужно указать имя';
  String get existingAccountHint => isKy
      ? 'Аккаунт табылды. Кодду гана жазыңыз.'
      : 'Аккаунт найден. Введите только код.';
  String get newAccountHint => isKy
      ? 'Жаңы аккаунт. Кодду жана аты-жөнүңүздү жазыңыз.'
      : 'Новый аккаунт. Введите код и имя.';
  String get devSmsAnyCode => isKy
      ? 'Тест режими: код талаасына 123 жазыңыз.'
      : 'Тестовый режим: введите 123 в поле кода.';
  String devSmsCode(String code) =>
      isKy ? 'Тест SMS коду: $code' : 'Тестовый SMS-код: $code';
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
}
