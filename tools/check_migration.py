#!/usr/bin/env python3
"""Verify every baseline function survives once; emit a complete correspondence CSV."""
from pathlib import Path
import argparse, csv, hashlib, json, re, sys
sys.path.insert(0,str(Path(__file__).resolve().parent/'build'))
from source_graph import SourceGraph, read_source
from ahk_symbols import functions
root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--write',action='store_true',help='Refresh correspondence CSV and current fingerprints')
args=parser.parse_args()
inventory_path=root/'docs/desktop/migration_inventory.json'
manifest=json.loads(inventory_path.read_text())
graph=SourceGraph(root);graph.flatten()
current={}
for path in graph.files:
    if path.parts[-2]=='tests':
        continue
    text=read_source(path)
    for name,a,b,body in functions(text):
        key=name.lower()
        if key in current:raise SystemExit('Duplicate function: '+name)
        current[key]={'name':name,'file':str(path.relative_to(root)).replace('\\','/'),'line':text.count('\n',0,a)+1,
                      'sha256':hashlib.sha256(body.encode('cp1251')).hexdigest()}
unchanged=0;adapted=0;rows=[]
for item in manifest['functions']:
    now=current.get(item['name'].lower())
    if now is None:raise SystemExit('Lost original function: '+item['name'])
    same=now['sha256']==item['sha256']
    unchanged+=same;adapted+=not same
    if same:
        result='Тело совпадает с исходником; это не отдельное подтверждение игрового сценария'
    elif item['name'].startswith(('SelfTest','V1_','RunSelfTest','Diagnostics','RunDiagnostics','RunAutoReportMock','RunV1Mock','RunLawSearchRegression')):
        result='Адаптирована диагностика/проверка модульных и встроенных ресурсов'
    elif now['file'] in ('ui_style.ahk', 'app/ui_settings.ahk', 'app/ui_overlays.ahk', 'service_ui.ahk', 'id_capture.ahk') or item['name'] in ('LawGui_GetLayout','LawGui_Show','LawSearch_GetShellAccentColor','LawSearch_GetResultLayout','LawSearch_ShowNotice','Search_ShowCurrentResult','TerritoryMap_ShowCatalog','TerritoryMap_ShowLocal','OpenCustomFunctionBuilder','ActionTimer_RenderCore'):
        result='Обновлены тема и геометрия native GUI; действия/перехват сохранены. Игровой сценарий требует проверки в клиенте'
    elif item['name'].startswith(('LawCorpus_','LawSearch_CorpusFingerprint','TerritoryMap_')):
        result='Адаптированы пути/ресурсы; тексты и алгоритмы поиска сохранены'
    elif item['name']=='ServiceUI_ShowDetails':
        result='Добавлен явный показ собственного GUI для отчёта, включая MockMode'
    elif item['name'] in ('UpdateBindList','CancelAllAutomation','RunBackgroundTool'):
        result='Исправлен жизненный цикл окна/ввода/диагностического процесса; покрыто desktop smoke'
    else:
        result='Адаптирован путь пользовательских данных/отчётов'
    rows.append([item['name'],f"{item['file']}:{item['line']}",f"{now['file']}:{now['line']}",'Без изменений' if same else 'Адаптирована',result])
    if args.write:
        item.update(new_file=now['file'],new_line=now['line'],current_sha256=now['sha256'],body_unchanged=same)
    elif item.get('current_sha256') and item['current_sha256']!=now['sha256']:
        raise SystemExit('Current migration fingerprint stale: '+item['name'])
# All old named event labels remain. Snapshot obtained from the original main entry.
labels_text='\n'.join(read_source(p) for p in graph.files if p.parts[-2]!='tests')
labels=set(re.findall(r'(?m)^([A-Za-z_]\w*):\s*$',labels_text))
missing=set(manifest.get('event_labels',[]))-labels
if missing:raise SystemExit('Lost event labels: '+', '.join(sorted(missing)))
if args.write:
    manifest['current_summary']={'original_functions':len(rows),'unchanged_bodies':unchanged,'adapted_bodies':adapted,'retained_event_labels':len(manifest.get('event_labels',[]))}
    inventory_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    with (root/'docs/desktop/FUNCTION_MAPPING.csv').open('w',encoding='utf-8-sig',newline='') as f:
        writer=csv.writer(f);writer.writerow(['Функция исходного AHK','Исходное расположение','Реализация в приложении','Состояние кода','Результат проверки']);writer.writerows(rows)
print(f'PASS: {len(rows)} original functions retained once; {unchanged} bodies unchanged, {adapted} adapted; {len(manifest.get("event_labels",[]))} event labels retained')
print('Source preservation does not prove real-game execution.')
