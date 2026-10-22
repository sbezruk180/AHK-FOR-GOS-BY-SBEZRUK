#!/usr/bin/env python3
"""Canonical AHK function/action index and disposable entry-counter copies."""
from pathlib import Path
import argparse
import collections
import hashlib
import json
import re
import shutil
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools/build'))
from source_graph import SourceGraph, read_source
from ahk_symbols import functions

SUBSYSTEMS = {
 'host': 'EXE, пути данных, встроенные ресурсы', 'core': 'ядро и служебные операции',
 'profiles': 'профили, INI, миграции', 'ui_settings': 'страницы настроек',
 'ui_overlays': 'HUD и списки биндов', 'game': 'Auto ID и состояние игры',
 'game_input': 'владение вводом и игровые меню', 'chatlog': 'chatlog и доказательства',
 'actions': 'игровые действия и мастера', 'bindings': 'регистрация клавиш и TXT-команд',
 'automation': 'очередь, расписание и таймеры', 'ui_documents': 'документы и поиск',
 'chat': 'чат и шаблоны', 'custom_functions': 'конструктор действий',
 'UDF': 'чтение игры и вызовы API клиента', 'common': 'WinAPI, процесс, память и вызовы x86',
 'runtime_support': 'безопасный ввод, очереди, файлы, совместимость',
 'chat_typing': 'посимвольная печать и раскладки', 'id_capture': 'временный цифровой ввод ID',
 'service_ui': 'служебные окна и приватный ввод', 'ui_style': 'единая тема и геометрия GUI',
 'text_commands': 'разбор и алиасы TXT-команд', 'private_text': 'личное окно TXT-команд',
 'reference_guides': 'памятка ВГП/сигналов', 'helper': 'справочники, законы, поиск и совместимость',
 'diagnostics': 'диагностика и автономные проверки',
}
PURPOSES = {
 'Action_DoRights': 'Зачитать все строки прав через очередь выбранного профиля.',
 'RunGpsDialogAction': 'Открыть /gps, выбрать дом/организацию, ввести номер и подтвердить.',
 'SendChatMemory': 'Отправить строку через адрес игрового чата/команды в azmp.',
 'callWithParams': 'Собрать и выполнить вызов x86 с параметрами; нормализовать возврат потока.',
 'MemoryRemotePoll': 'Проверить завершение потока и освободить его дескриптор.',
 'ChatQueue_Tick': 'Отправить очередной разрешённый элемент; завершить, отложить или отменить пакет.',
 'ChatQueue_CompleteItem': 'Обновить состояние пакета и удалить его остаток при отказе.',
 'ChatTransport_Send': 'Выбрать печать, вставку или память; запретить опасный повтор.',
 'SendChatKeyboard': 'Открыть чат, вставить буквальный текст, подтвердить и освободить ввод.',
 'SendChatTyped': 'Ввести текст физическими клавишами с выбранным темпом и проверкой отмены.',
 'CancelAllAutomation': 'Остановить автоматизации, очистить очередь и временные состояния.',
 'QueueItem_IsCurrent': 'Проверить поколение действия и актуальность пакета.',
 'IniReadText': 'Прочитать многострочный текст INI с учётом версии кодека.',
 'IniWriteText': 'Сохранить текст и его кодек в INI.',
 'EncodeIniText': 'Закодировать CP1251-текст в формат H1 для безопасного INI.',
 'DecodeIniText': 'Восстановить текст из H1 либо прежних маркеров переноса строк.',
 'IsLikelyPointer': 'Проверить допустимый диапазон указателя 32-битного клиента.',
 'SafeSend': 'Отправить разрешённые клавиши с владением вводом и восстановлением задержек.',
 'SafeLayout': 'Сменить и проверить раскладку конкретного окна.',
 'ServiceUI_Request': 'Получить значение через собственное окно ввода.',
 'OpenSettings': 'Создать или открыть настройки со страницами профиля.',
 'AppHost_Init': 'Определить режим запуска и безопасную папку пользовательских данных.',
 'AppHost_RuntimeInfo': 'Экспортировать сведения о фактическом runtime и ресурсах.',
 'ReadOwnEntryText': 'Получить объединённый исходный текст из файлов или ресурсов EXE.',
}


VERBS = dict(Get="Получить",Read="Прочитать",Load="Загрузить",Show="Показать",Open="Открыть",Close="Закрыть",Run="Выполнить",Build="Сформировать",Set="Установить",Update="Обновить",Save="Сохранить",Parse="Разобрать",Is="Проверить",Has="Проверить наличие",Can="Проверить возможность",Reset="Сбросить",Check="Проверить",Validate="Проверить",Add="Добавить",Remove="Удалить",Normalize="Нормализовать",Release="Освободить",Acquire="Захватить",Start="Запустить",Stop="Остановить",Render="Отрисовать",Confirm="Подтвердить",Submit="Применить",Restore="Восстановить",Toggle="Переключить",Resolve="Определить",Ensure="Обеспечить",Encode="Закодировать",Decode="Декодировать",Apply="Применить",Append="Дописать",Register="Зарегистрировать",Capture="Перехватить",Find="Найти",Wait="Дождаться",Type="Напечатать",Try="Попытаться выполнить",Create="Создать",Destroy="Уничтожить",Format="Отформатировать",Execute="Выполнить",Send="Отправить",Write="Записать",Poll="Опросить",Select="Выбрать",Cancel="Отменить",Clear="Очистить",Init="Инициализировать",Refresh="Обновить",On="Обработать событие",Audit="Проверить")
NOUNS = dict(Label="подпись",Text="текст",Index="индекс",Page="страницу",Name="имя",Value="значение",Status="состояние",Token="токен команды",Alias="алиас",Result="результат",Path="путь",Dialog="диалог",Window="окно",Input="ввод",Target="цель",Player="игрока",State="состояние",Config="настройки",Profile="профиль",Theme="тему",Key="клавишу",Hotkey="горячую клавишу",Trigger="текстовый триггер",Bind="бинд",Item="элемент",Queue="очередь",Rows="строки",Data="данные",Memory="память",Handle="дескриптор",Line="строку",Action="действие",Map="карту",Layout="раскладку",Signature="сигнатуру",Date="дату",Time="время",Position="положение",Bounds="границы",Rect="прямоугольник",Response="ответ",Report="отчёт",Error="ошибку",Clipboard="буфер обмена",Selection="выделение",Owner="владение",Lease="право ввода",Reservation="резервирование",Code="код",Notice="уведомление",Settings="настройки",Corpus="базу законов",Doc="документ",Source="исходный текст",Host="оболочку приложения",Function="пользовательскую функцию",Control="элемент интерфейса",Button="кнопку",Tab="вкладку",Font="шрифт",Color="цвет",Candidate="кандидата",Prompt="подсказку",Match="совпадение",Distance="расстояние",Route="маршрут",Thread="поток",Chars="символы",Speed="скорость",Timer="таймер",Task="задачу",Log="журнал",File="файл",Asset="ресурс",Law="законодательство",Search="поиск")


def describe(row):
    if row['purpose']: return row['purpose']
    name=row['name']
    law=re.fullmatch(r'(LawText_)?(vu|fp|kon|fzop|ter|tk|arg|uk|vv|koap|pdd|oruzh|upk|kas|fsb|fsin|vs|sud|ord|gt)([0-9]+)',name,re.I)
    if law:
        return ('Получить текст страницы ' if law[1] else 'Показать/закрыть страницу ') + law[3] + ' документа ' + law[2].upper()
    remainder=name.split('_',1)[-1]
    tokens=re.findall(r'[A-Z]+(?=[A-Z][a-z]|$)|[A-Z]?[a-z]+|[0-9]+',remainder)
    if tokens and tokens[0] in VERBS:
        intent=VERBS[tokens[0]]+' '+' '.join(NOUNS.get(x,x) for x in tokens[1:])
    else:
        intent=remainder
    effects='; операции: '+', '.join(row['commands']) if row['commands'] else ''
    return row['subsystem']+': '+intent+effects+'; код: '+row['first_statement'][:100]


def masked(text):
    """Mask strings/comments before finding real call sites (not source assertions)."""
    out = list(text)
    quoted = False
    i = 0
    while i < len(text):
        ch = text[i]
        if ch == '`':
            out[i:i+2] = ' ' * len(out[i:i+2]); i += 2; continue
        if ch == '"':
            out[i] = ' '
            if quoted and text[i:i+2] == '""':
                out[i+1] = ' '; i += 2; continue
            quoted = not quoted
        elif quoted:
            if ch != '\n': out[i] = ' '
        elif ch == ';' and (i == 0 or text[i-1].isspace()):
            end = text.find('\n', i)
            end = len(text) if end < 0 else end
            out[i:end] = ' ' * (end-i); i = end; continue
        i += 1
    return ''.join(out)


def inventory(root=ROOT):
    graph = SourceGraph(root); graph.flatten()
    rows, events, source_hashes = [], [], {}
    for path in graph.files:
        rel = path.relative_to(root).as_posix(); text = read_source(path)
        source_hashes[rel] = hashlib.sha256(path.read_bytes()).hexdigest()
        spans = functions(text)
        for name, start, end, body in spans:
            line = text.count('\n', 0, start)+1
            code = masked(body)
            commands = list(dict.fromkeys(re.findall(r'(?im)^\s*(Gui|GuiControl|IniRead|IniWrite|FileRead|FileAppend|FileCopy|FileDelete|FileMove|SendEvent|SendInput|SetTimer|Hotkey|Hotstring|SoundPlay|WinActivate|WinHide|WinShow|Run|ExitApp)\b', code)))
            statements = [x.strip() for x in body.splitlines()[1:] if x.strip() and x.strip() not in ('{', '}') and not x.lstrip().startswith((';', 'global', 'local', 'static'))]
            rows.append({'name': name, 'file': rel, 'line': line, 'end_line': text.count('\n', 0, end)+1,
                'kind': 'test' if rel.startswith('tests/') else 'application',
                'subsystem': SUBSYSTEMS.get(path.stem, 'тесты' if rel.startswith('tests/') else path.stem),
                'purpose': PURPOSES.get(name), 'commands': commands,
                'call_candidates': list(dict.fromkeys(re.findall(r'\b([A-Za-z_]\w*)\s*\(', code[code.find('{')+1:]))),
                'winapi': list(dict.fromkeys(re.findall(r'DllCall\("([^"]+)"', body))),
                'first_statement': ' / '.join(statements[:2])[:200],
                'sha256': hashlib.sha256(body.encode('cp1251')).hexdigest()})
        outside = list(text)
        for _, start, end, _ in spans: outside[start:end] = ['\n' if x == '\n' else ' ' for x in text[start:end]]
        outside = ''.join(outside)
        for m in re.finditer(r'(?m)^([A-Za-z_]\w*):\s*(?:;[^\n]*)?$', outside):
            line = text.count('\n', 0, m.start())+1
            following = text[m.end():].splitlines()
            action = next((x.strip() for x in following if x.strip() and not x.lstrip().startswith(';')), '')
            events.append({'name': m[1], 'file': rel, 'line': line, 'action': action[:180]})
    names = {r['name'].lower():r['name'] for r in rows}
    assert len(names) == len(rows), 'Duplicate function names'
    for r in rows:
        r['calls'] = [names[n.lower()] for n in r.pop('call_candidates') if n.lower() in names]
    callers = collections.defaultdict(list)
    for r in rows:
        for n in r['calls']: callers[n].append(r['name'])
    for r in rows: r['callers'] = callers[r['name']]
    catalog=[]
    bindings=read_source(Path(root)/'app/bindings.ahk')
    state=read_source(Path(root)/'app/state.ahk')
    defaults=dict(re.findall(r'(?m)^global (\w+) := \"([^\"]*)\"$',state))
    handlers=dict(re.findall(r'labelMap\[\"([^\"]+)\"\] := \"([^\"]+)\"',bindings))
    for line,code in enumerate(bindings.splitlines(),1):
        if 'catalog.Push({Token:' not in code:continue
        fields=dict(re.findall(r'(\w+): \"([^\"]*)\"',code))
        if not fields.get('Token'):continue
        fields.update(file='app/bindings.ahk',line=line,handler=handlers.get(fields['Token'],''))
        fields['default_hotkey']=defaults.get(fields.get('HotkeyVar',''),'')
        fields['default_trigger']=defaults.get(fields.get('TriggerVar',''),'')
        catalog.append(fields)
    return {'functions': rows, 'events': events, 'catalog':catalog,'source_sha256': source_hashes}


HOOK = '''
__AuditCoverage_Hit(name) {
    global __AuditCoverageCounts, __AuditCoveragePath
    if !IsObject(__AuditCoverageCounts) {
        __AuditCoverageCounts := {}
        EnvGet, __AuditCoveragePath, AHK_AUDIT_COVERAGE
        OnExit(Func("__AuditCoverage_Save"), -1)
    }
    __AuditCoverageCounts[name] := __AuditCoverageCounts.HasKey(name) ? __AuditCoverageCounts[name] + 1 : 1
}
__AuditCoverage_Save(reason := "", code := 0) {
    global __AuditCoverageCounts, __AuditCoveragePath
    if (__AuditCoveragePath = "" || !IsObject(__AuditCoverageCounts))
        return
    file := FileOpen(__AuditCoveragePath, "w", "UTF-8")
    if !IsObject(file)
        return
    for name, count in __AuditCoverageCounts
        file.Write(name . "|" . count . "`r`n")
    file.Close()
}
'''


def instrument(source, target):
    """Counter hooks only in a separate copy. Preserve AHK's first scope statement."""
    source, target = Path(source).resolve(), Path(target).resolve()
    if target.is_relative_to(source): raise ValueError('Instrumented copy must be outside source tree')
    shutil.copytree(source, target, ignore=shutil.ignore_patterns('.git', '.build', 'dist', '__pycache__'), dirs_exist_ok=True)
    graph = SourceGraph(target); graph.flatten()
    count = 0
    for path in graph.files:
        text = read_source(path); inserts = []
        for name, start, end, body in functions(text):
            head = re.match(r'^[A-Za-z_]\w*\([^\n]*\)(?: *\{|[ \t]*\n\{)', body)
            offset = head.end()
            # All definitions in this project have a newline after the brace.
            assert body[offset:offset+1] == '\n', name
            offset += 1
            lines = body[offset:].splitlines(keepends=True)
            for line in lines:
                stripped = line.strip()
                if not stripped or stripped.startswith(';') or re.match(r'^(?:global|local|static)(?:\s|$)', stripped) or stripped.startswith(','):
                    offset += len(line)
                else:
                    break
            inserts.append((start+offset, '    __AuditCoverage_Hit("' + name + '")\n'))
            count += 1
        for offset, addition in reversed(inserts): text = text[:offset] + addition + text[offset:]
        path.write_bytes(text.replace('\n','\r\n').encode('cp1251'))
    path = target/'app/host.ahk'
    path.write_bytes(path.read_bytes() + HOOK.replace('\n','\r\n').encode('cp1251'))
    return count


def write_index(output, coverage=None):
    data = inventory()
    coverage = coverage or {}
    lines = ['AHK FOR GOS — КАРТА ФУНКЦИЙ И ОБРАБОТЧИКОВ',
      'Формат: имя | файл:строки | назначение/операции | вызовы | фактические входы при трассировке.',
      'Вход в функцию НЕ означает успешное действие или проверку всех её веток.',
      'ИГРА/СЕРВЕР/OBS: НЕ ПРОВЕРЕНЫ. Нулевые счётчики = функция не достигнута этими сценариями.',
      'Трассировка выполняется только на отдельно помеченных копиях. Оригинальные EXE и AHK не инструментированы.', '']
    for kind in ('application','test'):
        rows = [r for r in data['functions'] if r['kind']==kind]
        lines.append(('ФУНКЦИИ ПРИЛОЖЕНИЯ' if kind=='application' else 'ФУНКЦИИ ТЕСТОВ') + ': ' + str(len(rows)))
        for r in rows:
            counters = coverage.get(r['name'], {})
            r['coverage'] = counters
            r['description'] = describe(r)
            purpose = describe(r)
            evidence = ', '.join(f'{form}={value}' for form,value in sorted(counters.items())) or 'трассировка ещё не импортирована'
            lines.append(f"{r['name']} | {r['file']}:{r['line']}-{r['end_line']} | {purpose} | calls: {', '.join(r['calls']) or '-'} | входы: {evidence}")
        lines.append('')
    lines.append('ИМЕНОВАННЫЕ ОБРАБОТЧИКИ: ' + str(len(data['events'])))
    for r in data['events']: lines.append(f"{r['name']} | {r['file']}:{r['line']} | {r['action']}")
    lines += ['', 'КАТАЛОГ ПОЛЬЗОВАТЕЛЬСКИХ ДЕЙСТВИЙ: '+str(len(data['catalog'])), 'Указаны исходные значения; настройки конкретного пользователя здесь не читаются.']
    for r in data['catalog']:
        lines.append(f"{r['Token']} | {r.get('Label','')} | {r['file']}:{r['line']} | handler: {r['handler'] or 'см. диспетчер каталога'} | hotkey: {r['default_hotkey'] or '(не задана)'} | TXT: {r['default_trigger'] or '(не задан)'} | {r.get('HotkeyVar','')} / {r.get('TriggerVar','')}")
    output = Path(output); output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text('\r\n'.join(lines)+'\r\n', encoding='utf-8-sig', newline='')
    output.with_suffix('.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    return data


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output',type=Path)
    p.add_argument('--instrument-copy',type=Path)
    args=p.parse_args()
    if args.instrument_copy: print('Instrumented counters:',instrument(ROOT,args.instrument_copy))
    if args.output:
        d=write_index(args.output)
        print('Indexed',len(d['functions']),'functions and',len(d['events']),'event labels')


if __name__=='__main__': main()
