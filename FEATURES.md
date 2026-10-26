# Возможности AHK FOR GOS для Amazing Online

AHK FOR GOS BY SBEZRUK — открытый АХК для госструктур Amazing Online: МВД, ГАИ и других государственных организаций. Эта страница описывает имеющуюся реализацию и ведёт непосредственно к коду.

AHK FOR GOS is an open-source AutoHotkey assistant for government factions in Amazing Online. This catalog links each registered action to its source code.

[Скачать версию 1.1](https://github.com/sbezruk180/AHK-FOR-GOS-BY-SBEZRUK/releases/tag/v1.1) · [Начало работы](README.md) · [Сборка](docs/desktop/BUILD_AND_RUN_RU.md)

## Основные подсистемы

| Возможность | Где реализована |
| --- | --- |
| Auto ID при наведении, предложение новой цели и F1/F2 | [Чтение игры](UDF.ahk), [ID и оверлеи](app/ui_overlays.ahk) |
| Ввод ID вручную и перехват цифр с таймером | [Перехват ID](id_capture.ahk), [служебный ввод](service_ui.ahk) |
| Горячие клавиши, TXT-команды, английские алиасы и смена раскладки | [Каталог и регистрация](app/bindings.ahk), [TXT](app/text_commands.ahk), [приватный ввод](app/private_text.ahk) |
| Отправка в память, вставка, печать всего и фракционная печать | [Чат](app/chat.ahk), [посимвольная печать](chat_typing.ahk) |
| Переменный темп печати и два способа отправки остального текста | [Настройка скорости](docs/desktop/FACTION_SPEED_RU.md) |
| RP-действия, доклады, GPS, задержки и отмена | [Действия](app/actions.ahk), [автоматизации](app/automation.ahk), [очередь](common.ahk), [игровой ввод](app/game_input.ahk) |
| Конструктор сценариев с проверкой, предпросмотром и копированием | [Конструктор](app/custom_functions.ahk) |
| Профили, INI, импорт/экспорт и настройки | [Профили](app/profiles.ahk), [интерфейс настроек](app/ui_settings.ahk) |
| 20 документов законодательства, поиск и текстовые памятки | [Laws](laws), [поиск и страницы](helper.ahk), [окна](app/ui_documents.ahk), [памятки](app/reference_guides.ahk) |
| HUD, окна, единая тема и исключение из поддерживаемого захвата OBS | [Оверлеи](app/ui_overlays.ahk), [стили](ui_style.ahk), [служебный интерфейс](service_ui.ahk) |
| Chatlog, распознавание событий и контекстные действия | [Обработка chatlog](app/chatlog.ahk) |
| Диагностика, самостоятельный EXE и установщик/унинсталлер | [Диагностика](app/diagnostics.ahk), [сборка EXE](tools/build_exe.py), [исходники установки](installer/native) |

## Все 93 действия из каталога

Названия, исходные клавиши и TXT-триггеры извлечены из исходников. «—» означает отсутствие значения по умолчанию; свои назначения задаются в настройках. Здесь используются обозначения AutoHotkey: `!` — Alt, `^` — Ctrl, `+` — Shift, `#` — Win. Настройки существующего профиля могут отличаться. Ссылка «Код» ведёт к обработчику, а для действий с диспетчеризацией — к регистрации.

### Системные

| Действие | Клавиша | TXT | Реализация |
| --- | --- | --- | --- |
| Окно текстовых команд | `!t` | — | [Код](app/bindings.ahk#L1396) · `TextCommandInput` |
| Открыть меню | `F10` | — | [Код](app/bindings.ahk#L1397) · `OpenSettings` |
| Показать bind-list | `F11` | — | [Код](app/bindings.ahk#L1398) · `ToggleBindList` |
| Последний закон | — | — | [Код](app/bindings.ahk#L1399) · `ToggleLastLawDoc` |
| Скрыть окно закона | `Pause` | — | [Код](app/bindings.ahk#L1400) · `HideLawGui` |
| Запустить поиск законов | `^+f` | — | [Код](app/bindings.ahk#L1401) · `LawSearchSubmit` |
| Показать HUD | `F12` | — | [Код](app/bindings.ahk#L1402) · `ToggleHUD` |
| ID-плашка | `F5` | — | [Код](app/bindings.ahk#L1403) · `IDOverlay` |
| Принять найденный ID | `F1` | — | [Код](app/bindings.ahk#L1404) · `ConfirmID` |
| Отклонить найденный ID | `F2` | — | [Код](app/bindings.ahk#L1405) · `RejectID` |
| Ввести ID вручную | `!1` | — | [Код](app/bindings.ahk#L1406) · `EnterID` |
| Сброс ID | `^Numpad0` | — | [Код](app/bindings.ahk#L1407) · `ResetID` |
| Настройки биндов | — | `!бинды` | [Код](app/bindings.ahk#L1408) · `OpenBindsTab` |

### Задержание и RP

| Действие | Клавиша | TXT | Реализация |
| --- | --- | --- | --- |
| Представление | `!2` | — | [Код](app/bindings.ahk#L1410) · `Intro` |
| SOS | `F9` | — | [Код](app/bindings.ahk#L1411) · `SOS` |
| Chase с ID | `!3` | — | [Код](app/bindings.ahk#L1412) · `Chase` |
| Chase без ID | `Insert` | — | [Код](app/bindings.ahk#L1413) · `ChaseNoID` |
| Deject | `!4` | — | [Код](app/bindings.ahk#L1414) · `Deject` |
| Cuff | `!5` | — | [Код](app/bindings.ahk#L1415) · `Cuff` |
| InCar | `!6` | — | [Код](app/bindings.ahk#L1416) · `InCar` |
| Остановка | `!7` | — | [Код](app/bindings.ahk#L1417) · `StopChase` |
| Служебное удостоверение | `!8` | — | [Код](app/bindings.ahk#L1418) · `Doc` |
| Досмотр | `!9` | — | [Код](app/bindings.ahk#L1419) · `Search` |
| Личное дело | — | `!лд` | [Код](app/bindings.ahk#L1420) · `PersonalFile` |
| Корректировка розыска | — | `!су` | [Код](app/bindings.ahk#L1421) · `Su` |
| Снятие розыска | — | `!снятие` | [Код](app/bindings.ahk#L1454) · `WantedRemoval` |

### Доклады

| Действие | Клавиша | TXT | Реализация |
| --- | --- | --- | --- |
| Деп | — | `!деп` | [Код](app/bindings.ahk#L1423) · `Dep` |
| Розыскиваемые | — | `!р` | [Код](app/bindings.ahk#L1424) · `WantedList` |
| SOS выехал | — | `!сос` | [Код](app/bindings.ahk#L1425) · `SOSStart` |
| SOS прибыл | — | `!сос1` | [Код](app/bindings.ahk#L1426) · `SOSArrive` |
| Угон выехал | — | `!угон` | [Код](app/bindings.ahk#L1427) · `HijackStart` |
| Угон прибыл | — | `!угон1` | [Код](app/bindings.ahk#L1428) · `HijackArrive` |
| ДТП вызов принят | — | `!выз` | [Код](app/bindings.ahk#L1429) · `CallStart` |
| ДТП прибыли | — | `!выз1` | [Код](app/bindings.ahk#L1430) · `CallArrive` |
| ДТП оформление старт | — | — | [Код](app/bindings.ahk#L1431) · `CallWorkStart` |
| ДТП оформление конец | — | — | [Код](app/bindings.ahk#L1432) · `CallWorkEnd` |
| Гражданский вызов принят | — | — | [Код](app/bindings.ahk#L1433) · `CivilCallStart` |
| Гражданский вызов: прибыл | — | — | [Код](app/bindings.ahk#L1434) · `CivilCallArrive` |
| Маска и звонок | — | `!м` | [Код](app/bindings.ahk#L1435) · `MaskCall` |
| Проверка записи | — | `!упр` | [Код](app/bindings.ahk#L1436) · `RecordCheck` |
| Крушение поезда | — | `!поезд` | [Код](app/bindings.ahk#L1437) · `TrainCrash` |
| Строй | — | `!строй` | [Код](app/bindings.ahk#L1461) · `MDSFormation` |

### Транспорт / прочее

| Действие | Клавиша | TXT | Реализация |
| --- | --- | --- | --- |
| Патруль старт | — | `!патруль` | [Код](app/bindings.ahk#L1439) · `PatrolStart` |
| Патруль прод. | — | `!патруль1` | [Код](app/bindings.ahk#L1440) · `PatrolCont` |
| Патруль конец | — | `!патруль2` | [Код](app/bindings.ahk#L1441) · `PatrolEnd` |
| Пост старт | — | `!пост` | [Код](app/bindings.ahk#L1442) · `PostStart` |
| Пост прод. | — | `!пост1` | [Код](app/bindings.ahk#L1443) · `PostCont` |
| Пост конец | — | `!пост2` | [Код](app/bindings.ahk#L1444) · `PostEnd` |
| Автопатруль · 10 мин | — | `!апатруль` | [Код](app/bindings.ahk#L1445) · `AutoPatrol` |
| Автопост · 10 мин | — | `!апост` | [Код](app/bindings.ahk#L1446) · `AutoPost` |
| Колонна старт | — | `!вк` | [Код](app/bindings.ahk#L1447) · `ConvoyStart` |
| Колонна прод. | — | — | [Код](app/bindings.ahk#L1448) · `ConvoyCont` |
| Колонна конец | — | `!вк1` | [Код](app/bindings.ahk#L1449) · `ConvoyEnd` |
| Эвакуация старт | — | `!эв` | [Код](app/bindings.ahk#L1450) · `TowStart` |
| Эвакуация конец | — | `!эв1` | [Код](app/bindings.ahk#L1451) · `TowEnd` |
| Осмотр ТС | — | `!обтс` | [Код](app/bindings.ahk#L1452) · `CarSearch` |
| Пробив номера ТС | — | `!поисктс` | [Код](app/bindings.ahk#L1453) · `VehicleLookup` |
| Арест | — | `!ар` | [Код](app/bindings.ahk#L1455) · `Arrest` |
| Штраф | — | `!ш` | [Код](app/bindings.ahk#L1456) · `Fine` |
| Протокол | — | `!протокол` | [Код](app/bindings.ahk#L1457) · `Protocol` |
| Права | — | `!права` | [Код](app/bindings.ahk#L1458) · `Rights` |
| Визитка DS | — | `!визиткадс` | [Код](app/bindings.ahk#L1459) · `CardDS` |
| Визитка VK | — | `!визиткавк` | [Код](app/bindings.ahk#L1460) · `CardVK` |
| GPS Д | — | `!д` | [Код](app/bindings.ahk#L1468) · `GpsD` |
| GPS ОС | — | `!ос` | [Код](app/bindings.ahk#L1469) · `GpsOS` |

### Контекстный помощник

| Действие | Клавиша | TXT | Реализация |
| --- | --- | --- | --- |
| Пробив ООП | — | `!ооп` | [Код](app/bindings.ahk#L1462) · `AssistOOP` |
| Оглушение | — | `!оглуш` | [Код](app/bindings.ahk#L1463) · `AssistStun` |
| Преследование | — | `!погоня` | [Код](app/bindings.ahk#L1464) · `AssistChase` |
| Сигнализация дома | — | `!домgps` | [Код](app/bindings.ahk#L1465) · `AssistHouse` |
| Наркотики рядом | — | `!наркоид` | [Код](app/bindings.ahk#L1466) · `AssistDrugs` |
| Наручники после ПДП | — | `!пдпнаруч` | [Код](app/bindings.ahk#L1467) · `AssistPDPCuff` |

### Документы

| Действие | Клавиша | TXT | Реализация |
| --- | --- | --- | --- |
| Права — текстовое окно | — | `!правагуи` | [Код](app/bindings.ahk#L1470) · `GuideRights` |
| Сигналы СО | — | `!сигналы` | [Код](app/bindings.ahk#L1471) · `GuideSignals` |
| ВУ | — | `!вузакон` | [Код](app/bindings.ahk#L1472) · `VU` |
| ФП | — | `!фп` | [Код](app/bindings.ahk#L1473) · `FP` |
| Конст. | — | `!кон` | [Код](app/bindings.ahk#L1474) · `KON` |
| ФЗОП | — | `!фзоп` | [Код](app/bindings.ahk#L1475) · `FZOP` |
| Терр. | — | `!тер` | [Код](app/bindings.ahk#L1476) · `TER` |
| ТК | — | `!тк` | [Код](app/bindings.ahk#L1477) · `TK` |
| АРГ | — | `!арг` | [Код](app/bindings.ahk#L1478) · `ARG` |
| УК | — | `!ук` | [Код](app/bindings.ahk#L1479) · `UK` |
| Вертикаль | — | `!вв` | [Код](app/bindings.ahk#L1480) · `VV` |
| КоАП | — | `!коап` | [Код](app/bindings.ahk#L1481) · `KOAP` |
| ПДД | — | `!пдд` | [Код](app/bindings.ahk#L1482) · `PDD` |
| Оружие | — | `!оруж` | [Код](app/bindings.ahk#L1483) · `ORUZH` |
| УПК | — | `!упк` | [Код](app/bindings.ahk#L1484) · `UPK` |
| КАС | — | `!кас` | [Код](app/bindings.ahk#L1485) · `KAS` |
| ФЗ о ФСБ | — | `!фсб` | [Код](app/bindings.ahk#L1486) · `FSB` |
| ФЗ о ФСИН | — | `!фсин` | [Код](app/bindings.ahk#L1487) · `FSIN` |
| Военная служба | — | `!фзовс` | [Код](app/bindings.ahk#L1488) · `VS` |
| Судебная система | — | `!суд` | [Код](app/bindings.ahk#L1489) · `SUD` |
| ОРД | — | `!орд` | [Код](app/bindings.ahk#L1490) · `ORD` |
| Гостайна | — | `!гостайна` | [Код](app/bindings.ahk#L1491) · `GT` |

## Полный технический индекс

В текущем включаемом коде: **1386 функций приложения**, **32 тестовые функции**, **195 именованных обработчиков** и **46 AHK-модулей**. Это показатели статического индекса, а не количество проверенных игровых сценариев.

- [Каждая функция: файл, строки, назначение и вызовы](docs/desktop/FUNCTIONS_RU.txt).
- [Машиночитаемый индекс функций](docs/desktop/FUNCTIONS_RU.json).
- [Соответствие функций исходной и модульной версий](docs/desktop/FUNCTION_MAPPING.csv).
- [Результаты проверок](docs/desktop/TEST_RESULTS_RU.md) и [что проверить в игре](docs/desktop/REAL_GAME_CHECKLIST_RU.txt).

Совместимость памяти игры, Auto ID, GPS и OBS зависит от реального клиента и Windows. Наличие реализации и автоматических проверок не подтверждает работу на каждом сервере. Проект не объявляется лучше других без измеримых сравнений.

Страница формируется командой `python tools/build_feature_catalog.py`. Технический индекс обновляется отдельно: `python tools/function_index.py --output docs/desktop/FUNCTIONS_RU.txt`.
