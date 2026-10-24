#!/usr/bin/env python3
"""Document every registered user action with links to its actual implementation."""
from collections import defaultdict
from html import escape
from pathlib import Path
from function_index import inventory

ROOT = Path(__file__).resolve().parents[1]


def main():
    data = inventory()
    functions = {item['name']: item for item in data['functions']}
    groups = defaultdict(list)
    for item in data['catalog']:
        groups[item['Category']].append(item)
    app_count = sum(item['kind'] == 'application' for item in data['functions'])
    lines = [
        '# Возможности AHK FOR GOS для Amazing Online', '',
        'AHK FOR GOS BY SBEZRUK — открытый АХК для госструктур Amazing Online: МВД, ГАИ и других государственных организаций. '
        'Эта страница описывает имеющуюся реализацию и ведёт непосредственно к коду.', '',
        'AHK FOR GOS is an open-source AutoHotkey assistant for government factions in Amazing Online. '
        'This catalog links each registered action to its source code.', '',
        '[Скачать версию 1.1](https://github.com/sbezruk180/AHK-FOR-GOS-BY-SBEZRUK/releases/tag/v1.1) · '
        '[Начало работы](README.md) · [Сборка](docs/desktop/BUILD_AND_RUN_RU.md)', '',
        '## Основные подсистемы', '',
        '| Возможность | Где реализована |', '| --- | --- |',
        '| Auto ID при наведении, предложение новой цели и F1/F2 | [Чтение игры](UDF.ahk), [ID и оверлеи](app/ui_overlays.ahk) |',
        '| Ввод ID вручную и перехват цифр с таймером | [Перехват ID](id_capture.ahk), [служебный ввод](service_ui.ahk) |',
        '| Горячие клавиши, TXT-команды, английские алиасы и смена раскладки | [Каталог и регистрация](app/bindings.ahk), [TXT](app/text_commands.ahk), [приватный ввод](app/private_text.ahk) |',
        '| Отправка в память, вставка, печать всего и фракционная печать | [Чат](app/chat.ahk), [посимвольная печать](chat_typing.ahk) |',
        '| Переменный темп печати и два способа отправки остального текста | [Настройка скорости](docs/desktop/FACTION_SPEED_RU.md) |',
        '| RP-действия, доклады, GPS, задержки и отмена | [Действия](app/actions.ahk), [автоматизации](app/automation.ahk), [очередь](common.ahk), [игровой ввод](app/game_input.ahk) |',
        '| Конструктор сценариев с проверкой, предпросмотром и копированием | [Конструктор](app/custom_functions.ahk) |',
        '| Профили, INI, импорт/экспорт и настройки | [Профили](app/profiles.ahk), [интерфейс настроек](app/ui_settings.ahk) |',
        '| 20 документов законодательства, поиск и текстовые памятки | [Laws](laws), [поиск и страницы](helper.ahk), [окна](app/ui_documents.ahk), [памятки](app/reference_guides.ahk) |',
        '| HUD, окна, единая тема и исключение из поддерживаемого захвата OBS | [Оверлеи](app/ui_overlays.ahk), [стили](ui_style.ahk), [служебный интерфейс](service_ui.ahk) |',
        '| Chatlog, распознавание событий и контекстные действия | [Обработка chatlog](app/chatlog.ahk) |',
        '| Диагностика, самостоятельный EXE и установщик/унинсталлер | [Диагностика](app/diagnostics.ahk), [сборка EXE](tools/build_exe.py), [исходники установки](installer/native) |', '',
        f'## Все {len(data["catalog"])} действия из каталога', '',
        'Названия, исходные клавиши и TXT-триггеры извлечены из исходников. «—» означает отсутствие значения по умолчанию; '
        'свои назначения задаются в настройках. Здесь используются обозначения AutoHotkey: `!` — Alt, `^` — Ctrl, `+` — Shift, `#` — Win. '
        'Настройки существующего профиля могут отличаться. Ссылка «Код» ведёт к обработчику, а для действий с диспетчеризацией — к регистрации.', '',
    ]
    for category, items in groups.items():
        lines += ['### ' + category, '', '| Действие | Клавиша | TXT | Реализация |', '| --- | --- | --- | --- |']
        for item in items:
            function = functions.get(item.get('handler'))
            path, line = (function['file'], function['line']) if function else (item['file'], item['line'])
            label = item['Label'].replace('|', '\\|')
            key = '`' + item['default_hotkey'] + '`' if item['default_hotkey'] else '—'
            trigger = '`' + item['default_trigger'] + '`' if item['default_trigger'] else '—'
            lines.append(f'| {label} | {key} | {trigger} | [Код]({path}#L{line}) · `{item["Token"]}` |')
        lines.append('')
    lines += [
        '## Полный технический индекс', '',
        f'В текущем включаемом коде: **{app_count} функций приложения**, '
        f'**{len(data["functions"]) - app_count} тестовые функции**, '
        f'**{len(data["events"])} именованных обработчиков** и **{len(data["source_sha256"])} AHK-модулей**. '
        'Это показатели статического индекса, а не количество проверенных игровых сценариев.', '',
        '- [Каждая функция: файл, строки, назначение и вызовы](docs/desktop/FUNCTIONS_RU.txt).',
        '- [Машиночитаемый индекс функций](docs/desktop/FUNCTIONS_RU.json).',
        '- [Соответствие функций исходной и модульной версий](docs/desktop/FUNCTION_MAPPING.csv).',
        '- [Результаты проверок](docs/desktop/TEST_RESULTS_RU.md) и [что проверить в игре](docs/desktop/REAL_GAME_CHECKLIST_RU.txt).', '',
        'Совместимость памяти игры, Auto ID, GPS и OBS зависит от реального клиента и Windows. '
        'Наличие реализации и автоматических проверок не подтверждает работу на каждом сервере. '
        'Проект не объявляется лучше других без измеримых сравнений.', '',
        'Страница формируется командой `python tools/build_feature_catalog.py`. '
        'Технический индекс обновляется отдельно: `python tools/function_index.py --output docs/desktop/FUNCTIONS_RU.txt`.',
    ]
    (ROOT / 'FEATURES.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')
    site = 'https://sbezruk180.github.io/AHK-FOR-GOS-BY-SBEZRUK/'
    source = 'https://github.com/sbezruk180/AHK-FOR-GOS-BY-SBEZRUK/blob/main/'
    html = ['<!doctype html><html lang="ru"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">',
            '<title>Функции AHK FOR GOS — бинды для Amazing Online</title>',
            '<meta name="description" content="Все 93 действия AHK FOR GOS: бинды, RP, Auto ID, доклады, GPS и законодательство Amazing Online. Клавиши, TXT-команды и ссылки на исходники.">',
            '<link rel="canonical" href="'+site+'features.html">',
            '<style>body{font:17px/1.6 system-ui;background:#10121d;color:#e8e9f4;max-width:1100px;margin:auto;padding:24px}a{color:#b29aff}table{width:100%;border-collapse:collapse;margin-bottom:32px}td,th{text-align:left;border-bottom:1px solid #343447;padding:10px}code{overflow-wrap:anywhere}nav{margin-bottom:24px}section{overflow-x:auto}</style>',
            '<nav><a href="./">AHK FOR GOS — главная и загрузки</a> · <a href="'+source+'FEATURES.md">Полный каталог на GitHub</a></nav><main>',
            '<h1>Функции AHK FOR GOS для Amazing Online</h1>',
            '<p>Открытый АХК для госструктур Amazing Online от sbezruk180. Ниже перечислены все 93 действия встроенного каталога с исходными назначениями и ссылками на реальный код.</p>',
            '<p>Назначения вашего профиля могут отличаться. Обозначения AutoHotkey: ! — Alt, ^ — Ctrl, + — Shift, # — Win. Прочерк означает отсутствие назначения по умолчанию.</p>']
    for category, items in groups.items():
        html.append('<section><h2>'+escape(category)+'</h2><table><thead><tr><th>Действие</th><th>Клавиша</th><th>TXT</th><th>Исходники</th></tr></thead><tbody>')
        for item in items:
            function = functions.get(item.get('handler'))
            path, line = (function['file'], function['line']) if function else (item['file'], item['line'])
            html.append('<tr><td>'+escape(item['Label'])+'</td><td><code>'+escape(item['default_hotkey'] or '—')+'</code></td><td><code>'+escape(item['default_trigger'] or '—')+'</code></td><td><a href="'+source+path+'#L'+str(line)+'">'+escape(item['Token'])+'</a></td></tr>')
        html.append('</tbody></table></section>')
    html += ['<p>Код, сборка, установщик, документы и технический индекс доступны в <a href="https://github.com/sbezruk180/AHK-FOR-GOS-BY-SBEZRUK">официальном репозитории</a>. Работа памяти, GPS, Auto ID и OBS зависит от клиента и Windows; универсальная совместимость не заявляется.</p>', '</main></html>']
    (ROOT/'docs/site/features.html').write_text('\n'.join(html)+'\n',encoding='utf-8')
    print(f'Documented {len(data["catalog"])} registered actions, {app_count} application functions')


if __name__ == '__main__':
    main()
