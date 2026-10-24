#!/usr/bin/env python3
"""Save real Chromium search pages; distinguish results from challenges/network errors."""
import argparse
import asyncio
import base64
from datetime import datetime, timezone
import json
from pathlib import Path
import shutil
from urllib.parse import parse_qs, urlsplit

ENGINES = {
    'google': ('https://www.google.com/search?q=ahk+for+gos&hl=ru', '#search a:has(h3)'),
    'bing': ('https://www.bing.com/search?q=ahk+for+gos', '#b_results li.b_algo h2 a'),
    'yandex': ('https://yandex.ru/search/?text=ahk%20for%20gos', '.serp-item .OrganicTitle-Link'),
    'duckduckgo': ('https://html.duckduckgo.com/html/?q=ahk+for+gos', '.result__a'),
    'github': ('https://github.com/search?q=ahk+for+gos&type=repositories', 'a[href="/sbezruk180/AHK-FOR-GOS-BY-SBEZRUK"]'),
}
REPOSITORY = 'github.com/sbezruk180/ahk-for-gos-by-sbezruk'


def target_url(url):
    """Decode search result redirects, never count the query itself as a result."""
    query = parse_qs(urlsplit(url).query)
    if urlsplit(url).path == '/url':
        return query.get('q', query.get('url', [url]))[0]
    if urlsplit(url).hostname in ('www.bing.com', 'bing.com') and urlsplit(url).path == '/ck/a':
        value = query.get('u', [''])[0]
        if value.startswith('a1'):
            try:
                value = value[2:]
                return base64.urlsafe_b64decode(value + '=' * (-len(value) % 4)).decode()
            except (ValueError, UnicodeError):
                pass
    return url


async def main(output, executable):
    from playwright.async_api import async_playwright
    output.mkdir(parents=True, exist_ok=True)
    async with async_playwright() as p:
        browser = await p.chromium.launch(executable_path=executable, headless=True, args=['--no-sandbox'])
        async def inspect(name, query):
            url, selector = query
            page = await browser.new_page(viewport={'width':1440, 'height':1000}, locale='ru-RU')
            result = {'engine':name, 'query':'ahk for gos', 'requested_url':url,
                      'checked_at':datetime.now(timezone.utc).isoformat()}
            try:
                response = await page.goto(url, wait_until='domcontentloaded', timeout=35000)
                await page.wait_for_timeout(2000)
                if name == 'bing':
                    try:
                        await page.locator('#b_results li.b_algo').first.wait_for(state='visible', timeout=10000)
                    except Exception:
                        pass
                text = await page.locator('body').inner_text(timeout=5000)
                links = await page.locator(selector).evaluate_all('(items)=>items.map(x=>({title:x.innerText,url:x.href}))')
                for link in links:
                    link['target_url'] = target_url(link['url'])
                matches = [x for x in links if REPOSITORY in x['target_url'].lower()]
                # A challenge is not evidence that the repository is absent from the index.
                page_title = await page.title()
                challenge_text = (page_title + '\n' + text[:3000]).lower()
                challenge = '/sorry/' in page.url or any(x in challenge_text for x in (
                    'captcha', 'unusual traffic', 'подтвердите, что вы не робот',
                    'проверка браузера', 'verify you are human', 'not a robot', 'anomaly.js',
                    'подозрительный трафик', 'following challenge', 'вы не робот'))
                visible_results = await page.locator(selector).evaluate_all('(items)=>items.filter(x=>x.getClientRects().length && getComputedStyle(x).visibility !== "hidden").length')
                result.update(visible_result_count=visible_results, status=response.status if response else None, final_url=page.url,
                              title=await page.title(), results=links, repository_results=matches,
                              verdict='found' if matches else 'blocked_or_challenged' if challenge else 'results_not_visible' if links and not visible_results else 'not_found_in_visible_results' if links else 'no_results_extracted')
                (output / f'{name}.txt').write_text(text, encoding='utf-8')
                await page.screenshot(path=str(output / f'{name}.png'), full_page=False)
            except Exception as exc:
                result.update(verdict='request_failed', error=str(exc))
            finally:
                await page.close()
            print(json.dumps(result, ensure_ascii=False), flush=True)
            return result
        results = await asyncio.gather(*(inspect(name, query) for name, query in ENGINES.items()))
        await browser.close()
    (output / 'results.json').write_text(json.dumps(results, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    lines = ['# Проверка поиска AHK FOR GOS', '', 'Запрос: `ahk for gos`. Проверено Chromium через Playwright. Результат зависит от региона, времени и поисковой системы.', '', '| Поиск | Результат |', '| --- | --- |']
    labels = {'found':'Ссылка на проект найдена', 'blocked_or_challenged':'Проверка робота/блокировка; наличие в индексе не установлено', 'not_found_in_visible_results':'Среди извлечённых результатов ссылка не найдена', 'no_results_extracted':'Результаты не удалось извлечь; вывод об индексации не сделан', 'request_failed':'Ошибка проверки; выдача не проверена', 'results_not_visible':'В DOM есть ссылки, но они не отображаются; выдача не подтверждена'}
    for item in results:
        lines.append(f"| [{item['engine']}]({item['requested_url']}) | {labels[item['verdict']]} |")
    lines += ['', 'Детали и время проверки: [results.json](results.json). Снимки браузера и видимый текст сохранены рядом.', '', 'Эта проверка не гарантирует позиции и не отправляет поисковикам запрос на индексацию.']
    (output / 'README.md').write_text('\n'.join(lines)+'\n', encoding='utf-8')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--browser', default=shutil.which('google-chrome') or shutil.which('chromium'))
    args = parser.parse_args()
    asyncio.run(main(args.output, args.browser))
