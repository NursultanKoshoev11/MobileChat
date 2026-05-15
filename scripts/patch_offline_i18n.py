from pathlib import Path

path = Path("lib/main_offline.dart")
text = path.read_text()

# This patch intentionally replaces only quoted Dart string literals.
# It must not replace identifiers such as AdminPanelScreen or enum values in code.
replacements = {
    # App / login
    "MobileChat Offline Demo": "МобилЧат офлайн демо / МобилЧат офлайн демо",
    "Offline Demo": "Офлайн демо / Офлайн демо",
    "No internet. No server. Test admin number opens Admin Panel.": "Без интернета и сервера. Админ-номер открывает админ-панель. / Интернетсиз жана серверсиз. Админ номер админ-панелди ачат.",
    "No internet. No server. Enter a phone number and open the local demo immediately.": "Без интернета и сервера. Введите номер и сразу откройте локальное демо. / Интернетсиз жана серверсиз. Номерди киргизип, локалдык демону дароо ачыңыз.",
    "Admin test number: $adminDemoPhone\\nDemo SMS code: $demoOtpCode": "Админ номер: $adminDemoPhone\\nДемо-код: $demoOtpCode",
    "Mobile number": "Номер телефона / Телефон номери",
    "SMS code": "СМС-код / СМС код",
    "Display name": "Имя / Аты",
    "Enter offline demo": "Войти / Кирүү",
    "Fill admin test number": "Заполнить админ-номер / Админ номерди толтуруу",
    "Demo code is 1111": "Демо-код: 1111 / Демо-код: 1111",
    "Demo User": "Демо пользователь / Демо колдонуучу",
    "Platform Admin": "Админ платформы / Платформа админи",

    # Theme tooltips
    "Light mode": "Светлая тема / Жарык тема",
    "Dark mode": "Тёмная тема / Караңгы тема",

    # Groups / navigation
    "Groups": "Группы / Топтор",
    "Search groups": "Поиск групп / Топторду издөө",
    "My requests": "Мои заявки / Менин арыздарым",
    "Request group": "Заявка на группу / Топко арыз",
    "Log out": "Выйти / Чыгуу",
    "New group": "Новая группа / Жаңы топ",
    "Create local group": "Создать локальную группу / Локалдык топ түзүү",
    "Group name": "Название группы / Топтун аталышы",
    "Description": "Описание / Сүрөттөмө",
    "Public": "Открытая / Ачык",
    "Invite only": "По приглашению / Чакыруу менен",
    "Create": "Создать / Түзүү",
    "members": "участников / катышуучу",
    "owner": "владелец / ээси",
    "admin": "админ / админ",
    "member": "участник / катышуучу",

    # Group seed data
    "City Announcements": "Городские объявления / Шаардык жарыялар",
    "Official city updates and public feedback.": "Официальные новости города и обратная связь. / Шаардын расмий жаңылыктары жана кайрылуулар.",
    "Road Problems": "Проблемы дорог / Жол көйгөйлөрү",
    "Report road, traffic, and street light problems.": "Дороги, транспорт и уличное освещение. / Жолдор, транспорт жана көчө жарыктары.",
    "School Parents": "Родители школы / Мектеп ата-энелери",
    "Invite-only parent community.": "Закрытая группа для родителей. / Ата-энелер үчүн жабык топ.",

    # Request flow
    "Request official group": "Заявка на официальную группу / Расмий топко арыз",
    "Fill information so platform admins can verify the organization before creating an official group.": "Заполните данные, чтобы админы проверили организацию перед созданием группы. / Топ түзүүдөн мурун админдер уюмду текшериши үчүн маалыматтарды толтуруңуз.",
    "Full name": "ФИО / Аты-жөнү",
    "Position": "Должность / Кызматы",
    "Organization name": "Название организации / Уюмдун аталышы",
    "Organization type": "Тип организации / Уюмдун түрү",
    "City / region": "Город / регион / Шаар / аймак",
    "Official phone": "Официальный телефон / Расмий телефон",
    "Official email": "Официальная почта / Расмий почта",
    "Official website": "Официальный сайт / Расмий сайт",
    "Requested group title": "Название будущей группы / Жаңы топтун аталышы",
    "Group description": "Описание группы / Топтун сүрөттөмөсү",
    "Reason for creating group": "Причина создания / Түзүү себеби",
    "Documents / proof": "Документы / подтверждение / Документтер / тастыктоо",
    "Send request": "Отправить заявку / Арыз жөнөтүү",
    "Request sent to admin panel.": "Заявка отправлена админам. / Арыз админдерге жөнөтүлдү.",
    "Representative": "Представитель / Өкүл",
    "Demo Organization": "Демо организация / Демо уюм",
    "Government organization": "Госорган / Мамлекеттик орган",
    "Official demo group": "Официальная демо-группа / Расмий демо топ",
    "Official local group requested in offline demo.": "Официальная локальная группа для офлайн-демо. / Офлайн демо үчүн расмий локалдык топ.",
    "Need official communication with residents.": "Нужна официальная связь с жителями. / Тургундар менен расмий байланыш керек.",
    "Not provided in demo.": "Не указано в демо. / Демодо көрсөтүлгөн жок.",

    # Request demo data
    "Bakyt Asanov": "Бакыт Асанов",
    "Deputy mayor": "Заместитель мэра / Мэрдин орун басары",
    "Tokmok City Hall": "Мэрия города Токмок / Токмок шаарынын мэриясы",
    "City government": "Мэрия / Мэрия",
    "Tokmok": "Токмок",
    "Tokmok City Announcements": "Официальная группа Токмока / Токмоктун расмий тобу",
    "Official announcements and public feedback for Tokmok residents.": "Официальные объявления и предложения жителей Токмока. / Токмок тургундарынын расмий жарыялары жана сунуштары.",
    "We need one verified channel for city announcements, citizen proposals, complaints, and voting.": "Нужен проверенный канал для объявлений, предложений, жалоб и голосований. / Жарыялар, сунуштар, арыздар жана добуш берүү үчүн текшерилген канал керек.",
    "Official letter, staff ID, city hall seal": "Официальное письмо, служебное удостоверение, печать организации / Расмий кат, кызматтык күбөлүк, уюмдун мөөрү",
    "Official letter, staff ID, organization seal": "Официальное письмо, служебное удостоверение, печать организации / Расмий кат, кызматтык күбөлүк, уюмдун мөөрү",

    # Admin panel
    "Admin Panel": "Админ-панель / Админ панель",
    "Signed in as admin": "Вход как админ / Админ катары кирдиңиз",
    "Phone:": "Телефон: / Телефон:",
    "pending group request(s)": "заявок на проверке / текшерүүдөгү арыз",
    "Group creation requests": "Заявки на создание групп / Топ түзүү арыздары",
    "Existing groups": "Существующие группы / Бар болгон топтор",
    "No requests yet.": "Заявок пока нет. / Азырынча арыз жок.",
    "No requests yet": "Заявок пока нет / Азырынча арыз жок",
    "Request details": "Детали заявки / Арыздын деталдары",
    "Requested group": "Будущая группа / Жаңы топ",
    "Applicant": "Заявитель / Арыз ээси",
    "Organization": "Организация / Уюм",
    "Region": "Регион / Аймак",
    "Website": "Сайт / Сайт",
    "Reason": "Причина / Себеби",
    "Documents": "Документы / Документтер",
    "Admin comment": "Комментарий админа / Админдин комментарийи",
    "Admin comment / reason": "Комментарий / причина / Комментарий / себеп",
    "Approve and create group": "Одобрить и создать группу / Жактырып, топ түзүү",
    "Need more info": "Нужны данные / Кошумча маалымат керек",
    "Reject": "Отклонить / Четке кагуу",
    "Approved in offline demo.": "Одобрено в офлайн-демо. / Офлайн демодо жактырылды.",
    "Rejected in offline demo.": "Отклонено в офлайн-демо. / Офлайн демодо четке кагылды.",
    "Please add more documents.": "Добавьте больше документов. / Көбүрөөк документ кошуңуз.",
    "Not provided": "Не указан / Көрсөтүлгөн жок",

    # Request statuses
    "Pending": "На проверке / Текшерилүүдө",
    "Approved": "Одобрено / Жактырылды",
    "Rejected": "Отклонено / Четке кагылды",

    # Posts
    "New post": "Новая публикация / Жаңы жарыя",
    "New local post": "Новая локальная публикация / Жаңы локалдык жарыя",
    "Post type": "Тип публикации / Жарыянын түрү",
    "Interaction mode": "Режим / Режим",
    "Title": "Заголовок / Аталышы",
    "Publish locally": "Опубликовать локально / Локалдык жарыялоо",
    "Newest": "Новые / Жаңылар",
    "Popular": "Популярные / Популярдуу",
    "Resolved": "Решённые / Чечилген",
    "Read": "Открыть / Ачуу",
    "Read post": "Обсуждение / Талкуу",
    "Comments": "Комментарии / Комментарийлер",
    "Add local comment": "Добавить комментарий / Комментарий кошуу",
    "No comments yet.": "Комментариев пока нет. / Азырынча комментарий жок.",
    "Admin status": "Статус админа / Админ статусу",
    "This post is read-only.": "Эта публикация только для чтения. / Бул жарыя окуу үчүн гана.",
    "This post accepts votes only. Comments are disabled.": "Здесь доступно только голосование. Комментарии отключены. / Бул жерде добуш берүү гана бар. Комментарий өчүрүлгөн.",
    "comments": "комментариев / комментарий",
    "By": "Автор / Автор",
    "User": "Пользователь / Колдонуучу",

    # Post seed data
    "City Admin": "Админ города / Шаар админи",
    "Water maintenance notice": "Плановое отключение воды / Сууну убактылуу өчүрүү",
    "Water maintenance is planned tonight from 22:00 to 03:00. Please store enough water in advance.": "Сегодня с 22:00 до 03:00 будет плановое обслуживание водопровода. Подготовьте запас воды заранее. / Бүгүн 22:00дөн 03:00гө чейин суу түтүктөрү тейленет. Сууну алдын ала камдап алыңыз.",
    "Add more trash bins near the park": "Поставить больше урн возле парка / Парктын жанына көбүрөөк таштанды челектерин коюу",
    "The park gets crowded on weekends. More trash bins will keep the area cleaner.": "В выходные в парке много людей. Дополнительные урны помогут сохранить чистоту. / Дем алышта паркта эл көп болот. Кошумча челектер тазалыкты сактоого жардам берет.",
    "Broken street light near school": "Не работает фонарь возле школы / Мектептин жанындагы чырак күйбөйт",
    "The street light near the school entrance is broken. It is difficult to walk there in the evening.": "Возле входа в школу не работает уличный фонарь. Вечером там небезопасно ходить. / Мектептин кире беришиндеги көчө чырагы күйбөйт. Кечинде ал жерде жүрүү кооптуу.",
    "Parent meeting on Friday": "Родительское собрание в пятницу / Жума күнү ата-энелер жыйыны",
    "Please confirm whether you can attend the parent meeting this Friday at 18:00.": "Подтвердите, пожалуйста, сможете ли прийти в пятницу в 18:00. / Жума күнү саат 18:00дө келе аларыңызды ырастап коюңуз.",
    "I also saw this problem yesterday.": "Я тоже видел эту проблему вчера. / Мен да бул көйгөйдү кечээ көрдүм.",
    "Thank you. We will check this location.": "Спасибо. Мы проверим это место. / Рахмат. Бул жерди текшеребиз.",
    "I can attend.": "Я смогу прийти. / Мен келе алам.",
    "Parent": "Родитель / Ата-эне",
    "Admin": "Админ / Админ",
    "Meerim": "Мээрим",
    "Nursultan": "Нурсултан",

    # Post types / modes / statuses
    "Text only": "Только текст / Текст гана",
    "Voting only": "Только голосование / Добуш берүү гана",
    "Discussion with comments": "Обсуждение с комментариями / Комментарий менен талкуу",
    "Discussion": "Обсуждение / Талкуу",
    "Read only": "Только текст / Текст гана",
    "Vote only": "Только голосование / Добуш берүү гана",
    "New": "Новая / Жаңы",
    "Under review": "На проверке / Текшерилүүдө",
    "Accepted": "Принято / Кабыл алынды",
}

for old, new in replacements.items():
    text = text.replace(f"'{old}'", f"'{new}'")
    text = text.replace(f'"{old}"', f'"{new}"')

for forbidden in [
    "'Offline Demo'", "'Admin Panel'", "'Request group'", "'Create local group'",
    "'Group creation requests'", "'New post'", "'Read post'", "'Display name'",
    "'Mobile number'", "'Interaction mode'", "'Water maintenance notice'",
    "'City Announcements'", "'Road Problems'", "'School Parents'", "'Need more info'",
    "'Approve and create group'",
]:
    if forbidden in text:
        raise SystemExit(f"English quoted text remained after i18n patch: {forbidden}")

path.write_text(text)
print("Offline Russian/Kyrgyz quoted text patch applied safely.")
