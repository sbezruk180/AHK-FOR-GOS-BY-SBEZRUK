#include "core.hpp"
#include <cmath>
#include <commctrl.h>
#include <dwmapi.h>
#include <gdiplus.h>
#include <map>
#include <memory>
#include <shellapi.h>
#include <shlobj.h>
#include <thread>
#include <windowsx.h>
using namespace Gdiplus;
namespace gos {
#ifdef GOS_UNINSTALLER
constexpr bool Removing = true;
#else
constexpr bool Removing = false;
#endif
static HWND window = nullptr, pathEdit = nullptr, confirmEdit = nullptr,
            fileList = nullptr;
static float scale = 1;
static ULONG_PTR graphicsToken;
static int page = 0, returnPage = 0, choice = Removing ? 3 : 1;
static bool desktopLink = true, menuLink = true, readGuide = false, ack = false,
            bulk = false, preview = false;
static std::wstring rootText, statusText, reportFile;
static std::atomic<bool> cancelled(false), working(false);
static std::thread worker;
static std::mutex stateMutex;
static Progress live;
static Result completed;
static ScanResult scan;
static bool scanTask = false;
static float pageFade = 1;
static ULONGLONG pageStarted = 0;
static bool cleanupOnExit = false;
static fs::path uiReport;
static unsigned uiPassed = 0, uiFailed = 0;
static bool liveRemovalTest = false;
static fs::path fixtureData;
static std::string uiLog = "Native GUI smoke in preview mode. No install, "
                           "registry, scan, deletion or profile writes.\r\n";
static constexpr UINT UpdateMessage = WM_APP + 1, DoneMessage = WM_APP + 2;
static Color bg(255, 13, 15, 24), panel(255, 19, 22, 34), card(255, 25, 29, 44),
    stroke(255, 43, 47, 66), white(255, 241, 243, 255),
    muted(255, 153, 162, 187), purple(255, 139, 111, 255),
    green(255, 94, 223, 185);
struct Button {
  HWND h = nullptr;
  int id = 0;
  RectF rect;
  std::wstring title, detail, tag;
  int kind = 0;
  bool selected = false;
  float hover = 0;
};
static std::vector<std::unique_ptr<Button>> buttons;
static int S(float v) { return (int)std::lround(v * scale); }
static Color Mix(Color a, Color b, float t) {
  return Color(255, (BYTE)(a.GetR() + (b.GetR() - a.GetR()) * t),
               (BYTE)(a.GetG() + (b.GetG() - a.GetG()) * t),
               (BYTE)(a.GetB() + (b.GetB() - a.GetB()) * t));
}
static void Round(Graphics &g, const RectF &r, float radius, const Brush &brush,
                  const Pen *pen = nullptr) {
  GraphicsPath p;
  float d = radius * 2;
  p.AddArc(r.X, r.Y, d, d, 180, 90);
  p.AddArc(r.GetRight() - d, r.Y, d, d, 270, 90);
  p.AddArc(r.GetRight() - d, r.GetBottom() - d, d, d, 0, 90);
  p.AddArc(r.X, r.GetBottom() - d, d, d, 90, 90);
  p.CloseFigure();
  g.FillPath(&brush, &p);
  if (pen)
    g.DrawPath(pen, &p);
}
static void Text(Graphics &g, const std::wstring &s, float x, float y, float w,
                 float h, float size, Color color, bool bold = false,
                 StringAlignment alignment = StringAlignmentNear) {
  FontFamily ff(L"Segoe UI");
  Font f(&ff, size, bold ? FontStyleBold : FontStyleRegular, UnitPixel);
  SolidBrush b(color);
  StringFormat format;
  format.SetAlignment(alignment);
  format.SetTrimming(StringTrimmingEllipsisCharacter);
  format.SetFormatFlags(StringFormatFlagsLineLimit);
  RectF r(x, y, w, h);
  g.DrawString(s.c_str(), (INT)s.size(), &f, r, &format, &b);
}
static void Line(Graphics &g, float x, float y, float x2, float y2, Color color,
                 float width = 1) {
  Pen p(color, width);
  g.DrawLine(&p, x, y, x2, y2);
}
static void Check(Graphics &g, float x, float y, Color color, float size = 18) {
  Pen p(color, 2.4f);
  p.SetStartCap(LineCapRound);
  p.SetEndCap(LineCapRound);
  g.DrawLine(&p, x, y + size * .5f, x + size * .36f, y + size * .85f);
  g.DrawLine(&p, x + size * .36f, y + size * .85f, x + size, y);
}
static void Icon(Graphics &g, float x, float y, int type, Color color) {
  Pen p(color, 1.6f);
  if (type == 0) {
    g.DrawRectangle(&p, x, y + 2, 20.f, 15.f);
    Line(g, x + 5, y + 22, x + 15, y + 22, color, 1.5);
    Line(g, x + 10, y + 17, x + 10, y + 22, color, 1.5);
  } else if (type == 1) {
    PointF left[3]{{x + 6, y + 3}, {x, y + 10}, {x + 6, y + 17}};
    g.DrawLines(&p, left, 3);
    PointF pts[3]{{x + 14, y + 3}, {x + 20, y + 10}, {x + 14, y + 17}};
    g.DrawLines(&p, pts, 3);
    Line(g, x + 12, y, x + 8, y + 21, color, 1.5);
  } else if (type == 2) {
    g.DrawArc(&p, RectF(x, y, 20, 20), 15.f, 320.f);
    Line(g, x + 10, y + 5, x + 10, y + 11, color, 1.5);
    Line(g, x + 10, y + 11, x + 14, y + 13, color, 1.5);
  } else {
    PointF pts[] = {{x + 10, y},      {x + 20, y + 5}, {x + 18, y + 16},
                    {x + 10, y + 22}, {x + 2, y + 16}, {x, y + 5},
                    {x + 10, y}};
    g.DrawLines(&p, pts, 7);
    Check(g, x + 5, y + 7, color, 10);
  }
}
static void PaintButton(Button &b, DRAWITEMSTRUCT *d) {
  Graphics g(d->hDC);
  g.SetSmoothingMode(SmoothingModeAntiAlias);
  g.SetTextRenderingHint(TextRenderingHintClearTypeGridFit);
  g.ScaleTransform(scale, scale);
  float w = b.rect.Width, h = b.rect.Height;
  SolidBrush clear(b.rect.X < 228 ? Color(255, 16, 19, 30) : bg);
  g.FillRectangle(&clear, RectF(0, 0, w, h));
  bool disabled = !IsWindowEnabled(b.h);
  Color a = disabled ? Mix(card, panel, .5f) : card;
  bool focused = (d->itemState & ODS_FOCUS) != 0;
  Pen border(b.selected ? purple : stroke, b.selected ? 1.5f : 1.f);
  if (b.kind == 1) {
    LinearGradientBrush fill(
        PointF(0, 0), PointF(w, h),
        Mix(Color(255, 105, 80, 239), purple, b.hover),
        Mix(Color(255, 129, 89, 250), Color(255, 163, 128, 255), b.hover));
    if (disabled) {
      SolidBrush f(card);
      Round(g, RectF(0, 0, w - 1, h - 1), 10, f);
    } else
      Round(g, RectF(0, 0, w - 1, h - 1), 10, fill);
    Text(g, b.title, 12, (h - 24) / 2, w - 24, 28, 15, disabled ? muted : white,
         true, StringAlignmentCenter);
  } else if (b.kind == 2) {
    SolidBrush fill(
        Mix(panel, Color(255, 35, 31, 56), b.selected ? .85f : b.hover * .7f));
    Round(g, RectF(0, 0, w - 1, h - 1), 13, fill, &border);
    float cy = w < 400 ? 44.f : 20.f;
    SolidBrush circle(b.selected ? purple : stroke);
    g.FillEllipse(&circle, RectF(18, cy, 17, 17));
    if (b.selected) {
      SolidBrush inner(white);
      g.FillEllipse(&inner, RectF(23, cy + 5, 7, 7));
    }
    Text(g, b.title, 48, w < 400 ? 40.f : 16.f, w - 70, 28, 17, white, true);
    Text(g, b.detail, 48, w < 400 ? 72.f : 48.f, w - 70,
         h - (w < 400 ? 76.f : 56.f), 13.5f, muted);
    if (!b.tag.empty())
      Text(g, b.tag, w - 112, w < 400 ? 14.f : 19.f, 90, 20, 10,
           b.selected ? purple : muted, true, StringAlignmentFar);
  } else if (b.kind == 3) {
    SolidBrush fill(Mix(panel, card, b.hover));
    Round(g, RectF(0, 0, w - 1, h - 1), 8, fill);
    Pen p(b.selected ? purple : muted, 1.3f);
    SolidBrush sb(b.selected ? purple : panel);
    Round(g, RectF(8, (h - 18) / 2, 18, 18), 5, sb, &p);
    if (b.selected)
      Check(g, 12, (h - 12) / 2, white, 10);
    Text(g, b.title, 38, (h - 24) / 2, w - 50, 30, 14, white);
  } else if (b.kind == 4) {
    SolidBrush fill(Mix(bg, card, b.hover));
    Round(g, RectF(0, 0, w - 1, h - 1), 8, fill);
    Text(g, b.title, 8, (h - 24) / 2, w - 16, 28, 13, muted, false,
         StringAlignmentCenter);
  } else {
    SolidBrush fill(Mix(a, Color(255, 42, 45, 64), b.hover));
    Round(g, RectF(0, 0, w - 1, h - 1), 10, fill, &border);
    Text(g, b.title, 12, (h - 24) / 2, w - 24, 28, 14, white, false,
         StringAlignmentCenter);
  }
  if (focused) {
    Pen p(Color(255, 199, 184, 255), 1);
    SolidBrush transparent(Color(0, 0, 0, 0));
    Round(g, RectF(4, 4, w - 9, h - 9), 7, transparent, &p);
  }
}
static Button *FindButton(int id) {
  for (auto &b : buttons)
    if (b->id == id)
      return b.get();
  return nullptr;
}
static void Animate() { SetTimer(window, 1, 16, nullptr); }
static void AddButton(int id, float x, float y, float w, float h,
                      const std::wstring &title, int kind = 0,
                      const std::wstring &detail = L"", bool selected = false,
                      const std::wstring &tag = L"") {
  auto b = std::make_unique<Button>();
  b->id = id;
  b->rect = RectF(x, y, w, h);
  b->title = title;
  b->detail = detail;
  b->tag = tag;
  b->selected = selected;
  b->kind = kind;
  b->h = CreateWindowExW(0, L"BUTTON", title.c_str(),
                         WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_OWNERDRAW,
                         S(x), S(y), S(w), S(h), window, (HMENU)(INT_PTR)id,
                         GetModuleHandleW(nullptr), nullptr);
  buttons.push_back(std::move(b));
}
static std::wstring EditText(HWND h) {
  int n = GetWindowTextLengthW(h);
  std::wstring s(n + 1, 0);
  GetWindowTextW(h, s.data(), n + 1);
  s.resize(n);
  return s;
}
static void CreateEdit(HWND &h, int id, float x, float y, float w, float height,
                       const std::wstring &value) {
  h = CreateWindowExW(0, L"EDIT", value.c_str(),
                      WS_CHILD | WS_VISIBLE | WS_TABSTOP | ES_AUTOHSCROLL,
                      S(x + 10), S(y + 8), S(w - 20), S(height - 12), window,
                      (HMENU)(INT_PTR)id, GetModuleHandleW(nullptr), nullptr);
  static HFONT font = nullptr;
  static int fontHeight = 0;
  if (font && fontHeight != S(14)) {
    DeleteObject(font);
    font = nullptr;
  }
  fontHeight = S(14);
  if (!font)
    font =
        CreateFontW(-S(14), 0, 0, 0, 400, FALSE, FALSE, FALSE, DEFAULT_CHARSET,
                    0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");
  SendMessageW(h, WM_SETFONT, (WPARAM)font, TRUE);
  SendMessageW(h, EM_SETMARGINS, EC_LEFTMARGIN | EC_RIGHTMARGIN,
               MAKELPARAM(S(12), S(12)));
  SendMessageW(h, EM_LIMITTEXT, id == 201 ? 180 : 20, 0);
}
static void BuildPage(int next) {
  if (pathEdit) {
    rootText = EditText(pathEdit);
    DestroyWindow(pathEdit);
    pathEdit = nullptr;
  }
  if (confirmEdit) {
    DestroyWindow(confirmEdit);
    confirmEdit = nullptr;
  }
  if (fileList) {
    DestroyWindow(fileList);
    fileList = nullptr;
  }
  for (auto &b : buttons)
    DestroyWindow(b->h);
  buttons.clear();
  page = next;
  pageFade = 0;
  pageStarted = GetTickCount64();
  AddButton(90, 934, 17, 32, 32, L"—", 4);
  AddButton(91, 976, 17, 32, 32, L"×", 4);
  AddButton(80, 30, 585, 168, 38, L"Как пользоваться", 4);
  AddButton(81, 30, 627, 168, 32, L"О проекте ↗", 4);
  if (page == 0 && !Removing) {
    AddButton(101, 272, 315, 344, 126, L"Самостоятельный EXE", 2,
              L"Готов к запуску.\nAutoHotkey не требуется.", choice == 1,
              L"РЕКОМЕНДУЕМ");
    AddButton(102, 632, 315, 344, 126, L"Исходники AHK", 2,
              L"AutoHotkey включён.\nМожно редактировать код.", choice == 2,
              L"ДЛЯ НАСТРОЙКИ");
    AddButton(10, 746, 624, 230, 46, L"Продолжить  →", 1);
  } else if (page == 0 && Removing) {
    AddButton(101, 272, 198, 704, 96, L"Все AHK на компьютере", 2,
              L"Файлы .ahk и папки с ними целиком, включая содержимое.\n"
              L"Просмотр списка и ручной выбор перед удалением.",
              choice == 1, L"ПРОВЕРКА");
    AddButton(102, 272, 308, 704, 96, L"Только AHK FOR GOS — полностью", 2,
              L"Файлы приложения, локальный runtime, настройки,\nпрофили, логи "
              L"и созданные ярлыки.",
              choice == 2);
    AddButton(
        103, 272, 418, 704, 96, L"Удалить приложение, оставить профили", 2,
        L"Ваши бинды, профили и настройки сохранятся\nдля следующей установки.",
        choice == 3, L"СОХРАНИТЬ");
    AddButton(10, 746, 624, 230, 46, L"Продолжить  →", 1);
  } else if (page == 1) {
    if (!Removing) {
      CreateEdit(pathEdit, 201, 272, 247, 572, 40, rootText);
      AddButton(30, 858, 247, 118, 40, L"Изменить…");
      AddButton(40, 272, 325, 704, 42, L"Создать ярлык на рабочем столе", 3,
                L"", desktopLink);
      AddButton(41, 272, 377, 704, 42, L"Добавить ярлыки в меню «Пуск»", 3, L"",
                menuLink);
      AddButton(42, 272, 429, 704, 42, L"Показать инструкцию после установки",
                3, L"", readGuide);
      AddButton(10, 746, 624, 230, 46, L"Установить  →", 1);
    } else {
      CreateEdit(pathEdit, 201, 272, 234, 572, 40, rootText);
      AddButton(30, 858, 234, 118, 40, L"Изменить…");
      AddButton(10, 716, 624, 260, 46,
                choice == 1 ? L"Найти файлы .ahk  →" : L"Удалить приложение",
                1);
    }
    AddButton(11, 272, 624, 110, 46, L"Назад");
  } else if (page == 2) {
    AddButton(12, 772, 624, 204, 46, L"Остановить", 0);
  } else if (page == 3) {
    AddButton(10, 746, 624, 230, 46,
              Removing ? L"Закрыть" : L"Запустить AHK  →", 1);
    if (!Removing)
      AddButton(11, 272, 624, 130, 46, L"Завершить");
    AddButton(32, 272, 512, 206, 42, L"Открыть папку", 0);
    if (!reportFile.empty())
      AddButton(33, 494, 512, 190, 42, L"Отчёт операции", 0);
  } else if (page == 4) {
    AddButton(11, 272, 624, 150, 46, L"Вернуться");
  } else if (page == 5) {
    AddButton(50, 272, 190, 160, 36, L"Выбрать все");
    AddButton(51, 444, 190, 160, 36, L"Снять выбор");
    fileList = CreateWindowExW(
        WS_EX_CLIENTEDGE, WC_LISTVIEWW, L"Найденные AHK и EXE проекта",
        WS_CHILD | WS_VISIBLE | WS_TABSTOP | LVS_REPORT | LVS_SHOWSELALWAYS,
        S(272), S(238), S(704), S(242), window, (HMENU)202,
        GetModuleHandleW(nullptr), nullptr);
    ListView_SetExtendedListViewStyle(fileList, LVS_EX_CHECKBOXES |
                                                    LVS_EX_FULLROWSELECT |
                                                    LVS_EX_DOUBLEBUFFER);
    ListView_SetBkColor(fileList, RGB(19, 22, 34));
    ListView_SetTextBkColor(fileList, RGB(19, 22, 34));
    ListView_SetTextColor(fileList, RGB(225, 229, 245));
    LVCOLUMNW col{};
    col.mask = LVCF_TEXT | LVCF_WIDTH;
    col.cx = S(590);
    col.pszText = (LPWSTR)L"Полный путь";
    ListView_InsertColumn(fileList, 0, &col);
    col.cx = S(95);
    col.pszText = (LPWSTR)L"Размер";
    ListView_InsertColumn(fileList, 1, &col);
    bulk = true;
    SendMessageW(fileList, WM_SETREDRAW, FALSE, 0);
    for (size_t i = 0; i < scan.files.size(); i++) {
      auto path = (scan.files[i].directory ? L"[ПАПКА ЦЕЛИКОМ] " : L"[ФАЙЛ] ") +
                  scan.files[i].path.wstring();
      LVITEMW item{};
      item.mask = LVIF_TEXT;
      item.iItem = (int)i;
      item.pszText = path.data();
      ListView_InsertItem(fileList, &item);
      auto size = std::to_wstring((scan.files[i].size + 1023) / 1024) + L" КБ";
      ListView_SetItemText(fileList, (int)i, 1, size.data());
      ListView_SetCheckState(fileList, (int)i, scan.files[i].selected);
    }
    SendMessageW(fileList, WM_SETREDRAW, TRUE, 0);
    bulk = false;
    CreateEdit(confirmEdit, 203, 272, 529, 220, 37, L"");
    AddButton(43, 510, 522, 466, 48, L"Папки целиком, включая все файлы внутри",
              3, L"", ack);
    AddButton(11, 272, 624, 110, 46, L"Назад");
    AddButton(10, 700, 624, 276, 46, L"Удалить выбранное", 1);
    EnableWindow(FindButton(10)->h, FALSE);
  } else if (page == 6) {
    AddButton(11, 272, 624, 150, 46, L"Вернуться");
    if (!reportFile.empty())
      AddButton(33, 684, 624, 292, 46, L"Открыть подробный отчёт", 1);
  }
  if (!buttons.empty())
    SetFocus(FindButton(10) ? FindButton(10)->h : buttons.back()->h);
  InvalidateRect(window, nullptr, FALSE);
  Animate();
}
static void Hero(Graphics &g) {
  SolidBrush background(bg);
  g.FillRectangle(&background, 0, 0, 1040, 704);
  SolidBrush sidebar(Color(255, 16, 19, 30));
  g.FillRectangle(&sidebar, 0, 0, 228, 704);
  Line(g, 228, 0, 228, 704, Color(255, 34, 38, 54));
  Text(g, L"A", 32, 35, 36, 40, 28, white, true);
  SolidBrush accent(purple);
  g.FillRectangle(&accent, 34, 78, 25, 3);
  Text(g, L"AHK FOR GOS", 77, 43, 130, 22, 14, white, true);
  Text(g, Removing ? L"УДАЛЕНИЕ" : L"DESKTOP EDITION", 32, 103, 174, 22, 10,
       muted, true);
  // A vector emblem: crisp at any DPI, no downloaded art or web view.
  GraphicsPath star;
  PointF points[8]{{114, 171}, {126, 216}, {172, 229}, {126, 242},
                   {114, 287}, {101, 242}, {56, 229},  {101, 216}};
  star.AddPolygon(points, 8);
  PathGradientBrush glow(&star);
  glow.SetCenterColor(Color(255, 192, 171, 255));
  Color edge[] = {Color(255, 103, 72, 225)};
  int count = 1;
  glow.SetSurroundColors(edge, &count);
  g.FillPath(&glow, &star);
  Pen ring(Color(255, 46, 39, 76), 1);
  g.DrawEllipse(&ring, 47, 162, 134, 134);
  g.DrawEllipse(&ring, 34, 149, 160, 160);
  SolidBrush orb(purple);
  g.FillEllipse(&orb, 175, 191, 6, 6);
  std::vector<std::wstring> steps =
      Removing ? std::vector<std::wstring>{L"Режим удаления",
                                           L"Проверка файлов", L"Готово"}
               : std::vector<std::wstring>{L"Выбор версии", L"Настройка",
                                           L"Установка", L"Готово"};
  int current = page == 4 ? returnPage : page;
  int active =
      Removing
          ? (current == 0 ? 0 : (current == 3 ? 2 : 1))
          : (current == 0 ? 0 : (current == 1 ? 1 : (current == 3 ? 3 : 2)));
  for (size_t i = 0; i < steps.size(); i++) {
    float y = 355 + (float)i * 42;
    SolidBrush fill((int)i == active ? Color(255, 41, 33, 66)
                                     : Color(255, 24, 28, 42));
    g.FillEllipse(&fill, RectF(32, y, 23, 23));
    if ((int)i < active && page != 6)
      Check(g, 39, y + 6, green, 10);
    else
      Text(g, std::to_wstring(i + 1), 32, y + 2, 23, 19, 12,
           (int)i == active ? purple : muted, true, StringAlignmentCenter);
    Text(g, steps[i], 70, y + 1, 136, 25, 13, (int)i == active ? white : muted,
         (int)i == active);
  }
  Text(g, L"v1.1  /  SBezruk180", 32, 665, 170, 22, 10,
       Color(255, 111, 121, 149));
  Text(g, Removing ? L"AHK FOR GOS / UNINSTALL" : L"AHK FOR GOS / SETUP", 272,
       29, 500, 24, 10, muted, true);
}
static void Pill(Graphics &g, const std::wstring &s, float x, float y, float w,
                 Color fg = green) {
  SolidBrush f(Mix(panel, fg, .09f));
  Round(g, RectF(x, y, w, 26), 13, f);
  Text(g, s, x + 10, y + 6, w - 20, 17, 10, fg, true);
}
static void Body(Graphics &g) {
  if (page == 0 && !Removing) {
    Pill(g, L"AMAZING ONLINE  ·  WINDOWS 10 / 11", 272, 86, 294);
    Text(g, L"Всё для игры.\nВ одном помощнике.", 270, 132, 710, 120, 43, white,
         true);
    Text(g,
         L"Установите AHK FOR GOS так, как удобно вам.\nБинды, профили и "
         L"инструменты — готовы к настройке.",
         274, 261, 700, 44, 14, muted);
    SolidBrush note(Color(255, 31, 27, 43));
    Pen border(Color(255, 61, 45, 74));
    Round(g, RectF(272, 470, 704, 112), 12, note, &border);
    Text(g, L"Используйте осознанно", 294, 486, 650, 26, 14,
         Color(255, 217, 197, 240), true);
    Text(g,
         L"Автор не несёт ответственности за блокировки, санкции, потерю "
         L"аккаунта\nи последствия использования. Проверяйте правила сервера: "
         L"наличие\nфункции не означает, что администрация разрешает её "
         L"применение.",
         294, 517, 650, 58, 13, muted);
    Text(g, L"Без консоли  ·  Без интернета при установке", 272, 641, 440, 28,
         12, muted);
  } else if (page == 0 && Removing) {
    Pill(g, L"ВАШИ ФАЙЛЫ — ВАШ ВЫБОР", 272, 86, 256);
    Text(g, L"Как будем удалять?", 270, 132, 710, 60, 35, white, true);
    Text(g, L"Чужие EXE и установленный отдельно AutoHotkey не удаляются.", 272,
         543, 704, 36, 13, muted);
    Text(g,
         L"В первом режиме .ahk удаляются только после просмотра\nнайденных "
         L"файлов и отдельного подтверждения.",
         272, 575, 704, 38, 12, muted);
  } else if (page == 1) {
    SolidBrush inputFill(card);
    Pen inputBorder(stroke);
    Round(g, RectF(272, Removing ? 234.f : 247.f, 572, 40), 9, inputFill,
          &inputBorder);
    Pill(g,
         Removing
             ? L"ПРОВЕРКА ПЕРЕД УДАЛЕНИЕМ"
             : (choice == 1 ? L"ВЫБРАНА ВЕРСИЯ .EXE" : L"ВЫБРАНА ВЕРСИЯ .AHK"),
         272, 86, 280);
    Text(g, Removing ? L"Сначала проверим детали." : L"Настроим под вас.", 270,
         133, 710, 65, 35, white, true);
    Text(g, L"Папка приложения", 272, 215 - (Removing ? 14 : 0), 650, 25, 13,
         white, true);
    if (!Removing) {
      Text(g,
           L"Существующие профили и бинды будут сохранены.\nАссоциации чужих "
           L"AHK и системные настройки не меняются.",
           272, 494, 704, 46, 13, muted);
      Text(g, L"Профили: " + DefaultData().wstring(), 272, 558, 704, 40, 11,
           muted);
    } else {
      SolidBrush fill(panel);
      Round(g, RectF(272, 310, 704, 230), 12, fill);
      Icon(g, 296, 334, choice == 3 ? 3 : 2, choice == 3 ? green : purple);
      Text(g,
           choice == 3 ? L"Профили останутся с вами"
                       : (choice == 2 ? L"Удаляется только этот проект"
                                      : L"Найдём AHK на локальных дисках"),
           336, 331, 600, 34, 20, white, true);
      std::wstring text =
          choice == 3
              ? L"Удалятся файлы программы, локальный runtime и "
                L"ярлыки.\nНастройки, профили, бинды и журналы "
                L"сохранятся.\n\nПри переустановке они будут доступны "
                L"автоматически."
              : (choice == 2
                     ? L"Удалятся установленные файлы AHK FOR GOS, его "
                       L"локальный\nruntime, настройки, профили, журналы и "
                       L"созданные ярлыки.\n\nДругие программы и "
                       L"пользовательские скрипты не затрагиваются."
                     : L"Сканирование ничего не удаляет. Следующий экран "
                       L"покажет\nточные пути; по умолчанию ни один файл не "
                       L"выбран.\n\nПо возможности используется корзина. "
                       L"Недоступные папки\nи ссылки пропускаются и отражаются "
                       L"в результате.");
      Text(g, text, 296, 384, 650, 144, 14, muted);
    }
  } else if (page == 2) {
    Pill(g, scanTask ? L"ТОЛЬКО ПОИСК — БЕЗ УДАЛЕНИЯ" : L"ВЫПОЛНЯЕТСЯ ОПЕРАЦИЯ",
         272, 86, 300);
    Text(g,
         scanTask
             ? L"Ищем скрипты и AHK FOR GOS."
             : (Removing ? L"Удаляем выбранное." : L"Готовим всё к запуску."),
         270, 150, 720, 75, 35, white, true);
    Progress p;
    {
      std::lock_guard<std::mutex> lock(stateMutex);
      p = live;
    }
    Text(g, p.detail, 272, 270, 704, 80, 16, muted);
    SolidBrush track(Color(255, 35, 37, 55));
    Round(g, RectF(272, 385, 704, 7), 3, track);
    if (p.total) {
      float amount = std::clamp((float)p.done / p.total, 0.f, 1.f);
      LinearGradientBrush fill(Point(272, 385), Point(976, 392),
                               Color(255, 102, 78, 236), purple);
      if (amount > 0)
        Round(g, RectF(272, 385, std::max(7.f, 704 * amount), 7), 3, fill);
      Text(g, std::to_wstring((int)(amount * 100)) + L"%", 272, 415, 704, 50,
           27, white, true);
    } else {
      float offset = (GetTickCount64() % 1600) / 1600.f;
      SolidBrush fill(purple);
      Round(g, RectF(272 + offset * 544, 385, 160, 7), 3, fill);
      Text(g, L"Можно остановить поиск в любой момент.", 272, 421, 704, 40, 13,
           muted);
    }
    Text(g, L"Пожалуйста, не запускайте приложение во время операции.", 272,
         512, 704, 40, 13, muted);
  } else if (page == 3) {
    SolidBrush fill(Color(255, 24, 50, 46));
    g.FillEllipse(&fill, 272, 102, 70, 70);
    Check(g, 291, 124, green, 30);
    Text(g, Removing ? L"Готово." : L"Можно начинать.", 270, 201, 704, 70, 42,
         white, true);
    Text(g, completed.message, 272, 292, 704, 92, 19, white);
    Text(
        g,
        Removing
            ? (choice == 3
                   ? L"Профили и настройки сохранены для следующей установки."
                   : L"Список выполненных действий доступен в отчёте операции.")
            : L"Откройте меню клавишей F10, настройте профиль и "
              L"бинды.\nИнструкция всегда доступна слева — изучайте в своём "
              L"темпе.",
        272, 392, 704, 70, 15, muted);
    if (!completed.warnings.empty())
      Text(g,
           L"Есть замечания: " + std::to_wstring(completed.warnings.size()) +
               L". Откройте отчёт перед закрытием.",
           272, 572, 704, 35, 13, Color(255, 227, 190, 118));
  } else if (page == 4) {
    Pill(g, L"НЕОБЯЗАТЕЛЬНАЯ ИНСТРУКЦИЯ", 272, 86, 280);
    Text(g, L"Быстрый старт.", 270, 132, 704, 65, 36, white, true);
    std::vector<std::pair<std::wstring, std::wstring>> items = {
        {L"01   Запустите игру и помощник",
         L"Используйте созданный ярлык. Игра и AHK должны работать\nс "
         L"одинаковым уровнем прав. Администратор обычно не требуется."},
        {L"02   Заполните профиль — F10",
         L"Укажите должность, звание и фамилию, затем настройте бинды.\nОба "
         L"варианта установки используют одну папку профилей."},
        {L"03   Проверьте ввод и ID",
         L"Выберите режим отправки и проверьте его в игре. При "
         L"включённом\nAuto ID: F1 — принять предложение, F2 — отклонить."},
        {L"04   Окна, команды и правила сервера",
         L"Текст прав: !правагуи. Настройки: F10. Параметры можно "
         L"изменить.\nПроверяйте правила сервера; скрытие в OBS зависит от "
         L"Windows и захвата."}};
    for (size_t i = 0; i < items.size(); i++) {
      float y = 212 + i * 91;
      SolidBrush f(panel);
      Round(g, RectF(272, y, 704, 80), 10, f);
      Text(g, items[i].first, 290, y + 12, 660, 25, 15, white, true);
      Text(g, items[i].second, 290, y + 39, 660, 35, 12.5f, muted);
    }
  } else if (page == 5) {
    SolidBrush inputFill(card);
    Pen inputBorder(stroke);
    Round(g, RectF(272, 529, 220, 37), 9, inputFill, &inputBorder);
    Pill(g, L"НИЧЕГО НЕ ВЫБРАНО АВТОМАТИЧЕСКИ", 272, 86, 330,
         Color(255, 227, 190, 118));
    Text(g, L"Папка — со всем содержимым.", 270, 132, 704, 60, 30, white, true);
    Text(g, L"Для подтверждения введите УДАЛИТЬ", 272, 496, 704, 24, 13, muted);
    Text(g,
         L"Файлов и папок: " + std::to_wstring(scan.files.size()) +
             L" · Пропущено объектов: " + std::to_wstring(scan.skipped),
         272, 585, 704, 24, 12, muted);
  } else if (page == 6) {
    Pill(g, L"ОПЕРАЦИЯ НЕ ЗАВЕРШЕНА", 272, 86, 270, Color(255, 227, 190, 118));
    Text(g, L"Нужно ваше внимание.", 270, 145, 704, 65, 34, white, true);
    Text(g, statusText, 272, 247, 704, 220, 16, muted);
    Text(g,
         L"Проверьте путь, закройте работающий AHK и повторите.\nФайлы, "
         L"которые не удалось удалить, указаны в отчёте.",
         272, 498, 704, 70, 13, muted);
  }
}
static void Draw(HDC dc) {
  RECT rect;
  GetClientRect(window, &rect);
  HDC memory = CreateCompatibleDC(dc);
  HBITMAP bitmap = CreateCompatibleBitmap(dc, rect.right, rect.bottom);
  auto old = SelectObject(memory, bitmap);
  {
    Graphics g(memory);
    g.SetSmoothingMode(SmoothingModeAntiAlias);
    g.SetTextRenderingHint(TextRenderingHintClearTypeGridFit);
    g.ScaleTransform(scale, scale);
    Hero(g);
    Body(g);
    if (pageFade < 1) {
      SolidBrush fade(Color((BYTE)(80 * (1 - pageFade)), 13, 15, 24));
      g.FillRectangle(&fade, 245, 65, 790, 545);
    }
  }
  BitBlt(dc, 0, 0, rect.right, rect.bottom, memory, 0, 0, SRCCOPY);
  SelectObject(memory, old);
  DeleteObject(bitmap);
  DeleteDC(memory);
}
static Options CurrentOptions() {
  Options o;
  o.root = fs::path(rootText).lexically_normal();
  if (o.root.filename().empty() && o.root != o.root.root_path())
    o.root = o.root.parent_path();
  o.data = DefaultData();
  if (liveRemovalTest) {
    o.data = fixtureData;
    o.integration = false;
  }
  o.mode = Removing ? 1 : choice;
  o.allScripts = Removing && choice == 1;
  o.desktop = desktopLink;
  o.menu = menuLink;
  return o;
}
static void SaveReport(const Result &r) {
  wchar_t tmp[32768];
  GetTempPathW(32768, tmp);
  auto p = fs::path(tmp) / (L"AHKGOS-Operation-" +
                            std::to_wstring(GetCurrentProcessId()) + L".txt");
  std::string s = "AHK FOR GOS — installer / uninstaller\r\n" +
                  Utf8(r.message) + "\r\nDeleted=" + std::to_string(r.removed) +
                  " Folders=" + std::to_string(r.removedFolders) +
                  " Failed=" + std::to_string(r.failed) +
                  "\r\nRoot=" + Utf8(rootText) + "\r\n";
  for (auto &w : r.warnings)
    s += Utf8(w) + "\r\n";
  std::vector<unsigned char> b(3 + s.size());
  b[0] = 0xef;
  b[1] = 0xbb;
  b[2] = 0xbf;
  std::copy(s.begin(), s.end(), b.begin() + 3);
  try {
    Write(p, b);
    reportFile = p.wstring();
  } catch (...) {
    reportFile.clear();
  }
}
static void Work(int task) {
  if (preview) {
    MessageBoxW(window, L"Это демонстрационный режим. Файлы не изменяются.",
                Product, MB_ICONINFORMATION);
    return;
  }
  if (working.load())
    return;
  try {
    auto options = CurrentOptions();
    ValidateRoot(options.root);
    if (task == 2) {
      options.root = ResolveRemovalRoot(options.root);
      rootText = options.root.wstring();
      ReadRecord(options.root);
    }
    if (Removing && CanManage(options.root) && RunningFrom(options.root))
      throw std::runtime_error(Utf8(L"Закройте AHK FOR GOS перед удалением."));
    cancelled = false;
    working = true;
    scanTask = task == 3;
    {
      std::lock_guard<std::mutex> lock(stateMutex);
      live = {L"Проверяем файлы…", 0, scanTask ? 0u : 1u};
    }
    BuildPage(2);
    if (worker.joinable())
      worker.join();
    worker = std::thread([options, task] {
      CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
      Result r;
      auto notify = [](const Progress &p) {
        {
          std::lock_guard<std::mutex> lock(stateMutex);
          live = p;
        }
        PostMessageW(window, UpdateMessage, 0, 0);
      };
      try {
        if (task == 3) {
          auto found = ScanAhk(FixedRoots(), cancelled, notify);
          {
            std::lock_guard<std::mutex> lock(stateMutex);
            scan = std::move(found);
          }
          r.ok = !cancelled.load();
          r.cancelled = cancelled.load();
        } else if (task == 1)
          r = Install(options, cancelled, notify);
        else {
          Result external;
          bool wholeRoot =
              task == 4 &&
              std::any_of(scan.files.begin(), scan.files.end(), [&](auto &f) {
                auto path = options.root.wstring(), parent = f.path.wstring();
                return f.selected && f.directory &&
                       (_wcsicmp(path.c_str(), parent.c_str()) == 0 ||
                        (path.size() > parent.size() &&
                         path[parent.size()] == L'\\' &&
                         _wcsnicmp(path.c_str(), parent.c_str(),
                                   parent.size()) == 0));
              });
          if (task == 4 && !wholeRoot && CanManage(options.root))
            PrepareRemoval(options.root);
          if (task == 4)
            external = RecycleSelected(scan.files, cancelled, notify, true);
          if (!cancelled.load()) {
            r = Uninstall(options, choice == 3, cancelled, notify);
            r.removed += external.removed;
            r.removedFolders += external.removedFolders;
            r.failed += external.failed;
            r.warnings.insert(r.warnings.end(), external.warnings.begin(),
                              external.warnings.end());
            if (task == 4)
              r.message += L"\n" + external.message;
            if (r.failed) {
              r.ok = false;
              r.message = L"Удаление завершено не полностью. Неудалённые файлы "
                          L"указаны в отчёте.";
            }
          } else {
            r = external;
            r.cancelled = true;
            r.ok = false;
          }
        }
      } catch (const std::exception &e) {
        r.message = Wide(e.what());
      }
      {
        std::lock_guard<std::mutex> lock(stateMutex);
        completed = std::move(r);
      }
      PostMessageW(window, DoneMessage, task, 0);
      CoUninitialize();
    });
    Animate();
  } catch (const std::exception &e) {
    statusText = Wide(e.what());
    BuildPage(6);
  }
}
static void Browse() {
  IFileDialog *d = nullptr;
  if (SUCCEEDED(CoCreateInstance(CLSID_FileOpenDialog, nullptr,
                                 CLSCTX_INPROC_SERVER, IID_IFileDialog,
                                 (void **)&d))) {
    DWORD f;
    d->GetOptions(&f);
    d->SetOptions(f | FOS_PICKFOLDERS | FOS_FORCEFILESYSTEM |
                  FOS_PATHMUSTEXIST);
    d->SetTitle(Removing ? L"Выберите папку установленного AHK FOR GOS"
                         : L"Выберите папку назначения AHK FOR GOS");
    if (SUCCEEDED(d->Show(window))) {
      IShellItem *item;
      if (SUCCEEDED(d->GetResult(&item))) {
        PWSTR path;
        if (SUCCEEDED(item->GetDisplayName(SIGDN_FILESYSPATH, &path))) {
          fs::path p = path;
          CoTaskMemFree(path);
          if (!Removing && !OwnedRoot(p) &&
              p.filename() != L"AHK-FOR-GOS-BY-SBEZRUK")
            p /= L"AHK-FOR-GOS-BY-SBEZRUK";
          SetWindowTextW(pathEdit, p.c_str());
        }
        item->Release();
      }
    }
    d->Release();
  }
}
static void ReviewReady() {
  if (page != 5 || !confirmEdit)
    return;
  bool any = std::any_of(scan.files.begin(), scan.files.end(),
                         [](auto &f) { return f.selected; });
  auto b = FindButton(10);
  if (b)
    EnableWindow(b->h, ack && any && EditText(confirmEdit) == L"УДАЛИТЬ");
}
static void Close() {
  if (working.load()) {
    if (MessageBoxW(window,
                    L"Остановить текущую операцию? Закрытие станет доступно "
                    L"после остановки.",
                    Product, MB_YESNO | MB_ICONQUESTION) == IDYES) {
      cancelled = true;
      if (auto b = FindButton(12))
        EnableWindow(b->h, FALSE);
    }
    return;
  }
  DestroyWindow(window);
}
static void Command(int id) {
  if (id == 91) {
    Close();
    return;
  }
  if (id == 90) {
    ShowWindow(window, SW_MINIMIZE);
    return;
  }
  if (id == 80) {
    if (working.load())
      return;
    if (page == 4) {
      BuildPage(returnPage);
      return;
    }
    returnPage = page;
    BuildPage(4);
    return;
  }
  if (id == 81) {
    OpenGuide();
    return;
  }
  if (id == 30) {
    Browse();
    return;
  }
  if (id == 32) {
    auto p = Removing && choice == 3 ? DefaultData() : fs::path(rootText);
    ShellExecuteW(window, L"open", p.c_str(), nullptr, nullptr, SW_SHOWNORMAL);
    return;
  }
  if (id == 33) {
    ShellExecuteW(window, L"open", reportFile.c_str(), nullptr, nullptr,
                  SW_SHOWNORMAL);
    return;
  }
  if (id >= 101 && id <= 103) {
    choice = id - 100;
    for (auto &b : buttons)
      if (b->id >= 101 && b->id <= 103) {
        b->selected = b->id == id;
        InvalidateRect(b->h, nullptr, FALSE);
      }
    return;
  }
  if (id == 40 || id == 41 || id == 42 || id == 43) {
    bool *value = id == 40
                      ? &desktopLink
                      : (id == 41 ? &menuLink : (id == 42 ? &readGuide : &ack));
    *value = !*value;
    auto b = FindButton(id);
    b->selected = *value;
    InvalidateRect(b->h, nullptr, FALSE);
    ReviewReady();
    return;
  }
  if (id == 50 || id == 51) {
    bulk = true;
    for (size_t i = 0; i < scan.files.size(); i++) {
      scan.files[i].selected = id == 50;
      ListView_SetCheckState(fileList, (int)i, id == 50);
    }
    bulk = false;
    ReviewReady();
    return;
  }
  if (id == 12) {
    cancelled = true;
    EnableWindow(FindButton(12)->h, FALSE);
    return;
  }
  if (id == 11) {
    if (page == 3) {
      Close();
      return;
    }
    if (page == 4) {
      BuildPage(returnPage);
      return;
    }
    if (page == 6) {
      BuildPage(1);
      return;
    }
    if (page == 5) {
      BuildPage(0);
      return;
    }
    BuildPage(0);
    return;
  }
  if (id == 10) {
    if (page == 0) {
      BuildPage(1);
      return;
    }
    if (page == 1) {
      if (pathEdit)
        rootText = EditText(pathEdit);
      Work(Removing ? (choice == 1 ? 3 : 2) : 1);
      return;
    }
    if (page == 3) {
      if (!Removing) {
        try {
          Launch(fs::path(rootText));
        } catch (const std::exception &e) {
          MessageBoxW(window, Wide(e.what()).c_str(), Product, MB_ICONERROR);
          return;
        }
      }
      Close();
      return;
    }
    if (page == 5) {
      if (EditText(confirmEdit) != L"УДАЛИТЬ" || !ack)
        return;
      Work(4);
      return;
    }
  }
}

static void UiCheck(const std::string &name, bool ok) {
  uiLog += (ok ? "PASS | " : "FAIL | ") + name + "\r\n";
  ok ? uiPassed++ : uiFailed++;
}
static void UiLayout() {
  RECT client;
  GetClientRect(window, &client);
  bool good = true;
  std::vector<RECT> rects;
  for (auto &b : buttons) {
    RECT r;
    GetWindowRect(b->h, &r);
    MapWindowPoints(nullptr, window, (POINT *)&r, 2);
    good = good && r.left >= 0 && r.top >= 0 && r.right <= client.right &&
           r.bottom <= client.bottom;
    for (auto &other : rects) {
      RECT intersection;
      if (IntersectRect(&intersection, &r, &other))
        good = false;
    }
    rects.push_back(r);
  }
  UiCheck("native controls within client without overlap", good);
  UiCheck("keyboard has tab target",
          GetNextDlgTabItem(window, nullptr, FALSE) != nullptr);
}
static void Snapshot(const wchar_t *name) {
  UpdateWindow(window);
  RECT r;
  GetClientRect(window, &r);
  HDC dc = GetDC(window), mem = CreateCompatibleDC(dc);
  HBITMAP bmp = CreateCompatibleBitmap(dc, r.right, r.bottom);
  auto old = SelectObject(mem, bmp);
  RedrawWindow(window, nullptr, nullptr,
               RDW_INVALIDATE | RDW_ALLCHILDREN | RDW_UPDATENOW);
  SetForegroundWindow(window);
  POINT origin{0, 0};
  ClientToScreen(window, &origin);
  HDC screen = GetDC(nullptr);
  BOOL painted = BitBlt(mem, 0, 0, r.right, r.bottom, screen, origin.x,
                        origin.y, SRCCOPY | CAPTUREBLT);
  UiCheck("window is foreground for actual screen verification",
          GetForegroundWindow() == window);
  if (auto primary = FindButton(10);
      primary && primary->kind == 1 && IsWindowEnabled(primary->h)) {
    COLORREF pixel =
        GetPixel(screen, origin.x + S(primary->rect.X + 10),
                 origin.y + S(primary->rect.Y + primary->rect.Height / 2));
    UiCheck("visible primary button survives parent repaint",
            GetBValue(pixel) > 150 && GetRValue(pixel) > 70);
  }
  ReleaseDC(nullptr, screen);
  BITMAPINFO info{};
  info.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
  info.bmiHeader.biWidth = r.right;
  info.bmiHeader.biHeight = -r.bottom;
  info.bmiHeader.biPlanes = 1;
  info.bmiHeader.biBitCount = 32;
  info.bmiHeader.biCompression = BI_RGB;
  std::vector<unsigned char> pixels(r.right * r.bottom * 4);
  SelectObject(mem, old);
  int rows =
      GetDIBits(mem, bmp, 0, r.bottom, pixels.data(), &info, DIB_RGB_COLORS);
  DeleteObject(bmp);
  DeleteDC(mem);
  ReleaseDC(window, dc);
  BITMAPFILEHEADER header{};
  header.bfType = 0x4d42;
  header.bfOffBits = sizeof(header) + sizeof(BITMAPINFOHEADER);
  header.bfSize = header.bfOffBits + (DWORD)pixels.size();
  std::vector<unsigned char> file(header.bfSize);
  memcpy(file.data(), &header, sizeof(header));
  memcpy(file.data() + sizeof(header), &info.bmiHeader, sizeof(info.bmiHeader));
  memcpy(file.data() + header.bfOffBits, pixels.data(), pixels.size());
  if (painted && rows == r.bottom) {
    Write(uiReport.parent_path() /
              (std::wstring(Removing ? L"uninstall-" : L"setup-") + name +
               L".bmp"),
          file);
  }
  size_t bright = 0;
  for (size_t i = 0; i + 3 < pixels.size(); i += 4)
    if (pixels[i] > 100 && pixels[i + 1] > 100 && pixels[i + 2] > 100)
      bright++;
  UiCheck("real Win32 window renders nonempty content to bitmap",
          painted && rows == r.bottom && bright > 400);
}
static void UiStep() {
  static int step = 0;
  try {
    if (liveRemovalTest) {
      if (step == 0) {
        UiCheck("real installed uninstaller starts", !preview && Removing);
        Command(103);
        Command(10);
        ++step;
      } else if (step == 1) {
        UiCheck("real keep-profile selection", choice == 3 && page == 1);
        Command(10);
        ++step;
      } else if (!working.load()) {
        UiCheck("actual UI removal succeeds", page == 3 && completed.ok);
        auto root = fs::path(rootText);
        UiCheck("renamed application removed by actual UI",
                !fs::exists(root / L"GOS helper (old).exe"));
        UiCheck("profile survives actual UI removal",
                fs::exists(fixtureData / L"profiles.ini"));
        uiLog += "Checks=" + std::to_string(uiPassed + uiFailed) +
                 " Failed=" + std::to_string(uiFailed) + "\r\n";
        Write(uiReport, std::vector<unsigned char>(uiLog.begin(), uiLog.end()));
        KillTimer(window, 2);
        DestroyWindow(window);
      }
      return;
    }
    switch (step++) {
    case 0:
      UiLayout();
      Snapshot(L"home");
      UiCheck("mode cards exist", FindButton(101) && FindButton(102));
      Command(102);
      UiCheck("mode selection changes", choice == 2);
      Command(10);
      UiCheck("next opens settings", page == 1 && IsWindow(pathEdit));
      break;
    case 1:
      UiLayout();
      Snapshot(L"options");
      UiCheck("path edit has absolute target",
              fs::path(EditText(pathEdit)).is_absolute());
      if (!Removing) {
        bool was = desktopLink;
        Command(40);
        UiCheck("shortcut switch works", desktopLink != was);
        Command(40);
      }
      Command(80);
      UiCheck("optional guide opens", page == 4);
      break;
    case 2:
      UiLayout();
      Snapshot(L"help");
      Command(11);
      UiCheck("guide returns to previous page", page == 1);
      if (Removing) {
        scan.files.clear();
        FoundFile a;
        a.path = L"C:\\example\\personal.ahk";
        scan.files.push_back(a);
        ack = false;
        BuildPage(5);
      } else {
        completed.ok = true;
        completed.message = L"Preview completed";
        BuildPage(3);
      }
      break;
    case 3:
      UiLayout();
      if (Removing) {
        Snapshot(L"review");
        UiCheck("deletion starts disabled",
                !IsWindowEnabled(FindButton(10)->h));
        Command(50);
        SetWindowTextW(confirmEdit, L"УДАЛИТЬ");
        UiCheck("typed confirmation alone cannot enable removal",
                !IsWindowEnabled(FindButton(10)->h));
        Command(43);
        UiCheck("selection plus typing plus acknowledgement enables removal",
                IsWindowEnabled(FindButton(10)->h));
        Command(51);
        UiCheck("clearing selection disables removal",
                !IsWindowEnabled(FindButton(10)->h));
      } else {
        UiCheck("completion has launch button", FindButton(10) != nullptr);
        Snapshot(L"done");
      }
      break;
    default:
      KillTimer(window, 2);
      uiLog += "Checks=" + std::to_string(uiPassed + uiFailed) +
               " Failed=" + std::to_string(uiFailed) + "\r\n";
      Write(uiReport, std::vector<unsigned char>(uiLog.begin(), uiLog.end()));
      DestroyWindow(window);
      break;
    }
  } catch (const std::exception &e) {
    UiCheck(e.what(), false);
    Write(uiReport, std::vector<unsigned char>(uiLog.begin(), uiLog.end()));
    DestroyWindow(window);
  }
}

static LRESULT CALLBACK WindowProc(HWND h, UINT m, WPARAM w, LPARAM l) {
  switch (m) {
  case WM_CREATE:
    window = h;
    return 0;
  case WM_ERASEBKGND:
    return 1;
  case WM_PRINTCLIENT:
    Draw((HDC)w);
    return 0;
  case WM_PAINT: {
    PAINTSTRUCT p;
    HDC dc = BeginPaint(h, &p);
    Draw(dc);
    EndPaint(h, &p);
    return 0;
  }
  case WM_DRAWITEM: {
    auto d = (DRAWITEMSTRUCT *)l;
    if (auto b = FindButton((int)d->CtlID)) {
      PaintButton(*b, d);
      return TRUE;
    }
    break;
  }
  case WM_COMMAND:
    if ((int)LOWORD(w) == 203 && HIWORD(w) == EN_CHANGE) {
      ReviewReady();
      return 0;
    }
    if (HIWORD(w) == BN_CLICKED) {
      Command(LOWORD(w));
      return 0;
    }
    break;
  case WM_CTLCOLORSTATIC:
  case WM_CTLCOLOREDIT: {
    SetTextColor((HDC)w, RGB(235, 237, 250));
    SetBkColor((HDC)w, RGB(25, 29, 44));
    static HBRUSH b = CreateSolidBrush(RGB(25, 29, 44));
    return (LRESULT)b;
  }
  case WM_NOTIFY: {
    auto n = (NMHDR *)l;
    if (n->hwndFrom == fileList && n->code == LVN_ITEMCHANGED && !bulk) {
      auto item = (NMLISTVIEW *)l;
      if (item->iItem >= 0 && (size_t)item->iItem < scan.files.size() &&
          (item->uChanged & LVIF_STATE)) {
        scan.files[item->iItem].selected =
            ListView_GetCheckState(fileList, item->iItem) != 0;
        ReviewReady();
      }
    }
    return 0;
  }
  case WM_DPICHANGED: {
    RECT area;
    SystemParametersInfoW(SPI_GETWORKAREA, 0, &area, 0);
    scale = std::min(LOWORD(w) / 96.f,
                     std::min((area.right - area.left - 30) / 1040.f,
                              (area.bottom - area.top - 30) / 704.f));
    scale = std::max(.65f, scale);
    auto r = (RECT *)l;
    SetWindowPos(h, nullptr, r->left, r->top, S(1040), S(704),
                 SWP_NOZORDER | SWP_NOACTIVATE);
    BuildPage(page);
    return 0;
  }
  case WM_NCHITTEST: {
    POINT p{GET_X_LPARAM(l), GET_Y_LPARAM(l)};
    ScreenToClient(h, &p);
    if (p.y < S(64) && p.x < S(925))
      return HTCAPTION;
    break;
  }
  case WM_MOUSEMOVE:
    Animate();
    break;
  case WM_TIMER: {
    if (w == 2) {
      UiStep();
      return 0;
    }
    if (w != 1)
      break;
    POINT p;
    GetCursorPos(&p);
    bool again = false;
    for (auto &b : buttons) {
      RECT r;
      GetWindowRect(b->h, &r);
      float target = PtInRect(&r, p) && IsWindowEnabled(b->h) ? 1.f : 0.f;
      float diff = target - b->hover;
      if (fabs(diff) > .01f) {
        b->hover += diff * .22f;
        again = true;
        InvalidateRect(b->h, nullptr, FALSE);
      }
    }
    float t = std::min(1.f, (GetTickCount64() - pageStarted) / 220.f);
    if (t != pageFade) {
      pageFade = t;
      InvalidateRect(h, nullptr, FALSE);
      again = true;
    }
    if (working.load() && scanTask) {
      InvalidateRect(h, nullptr, FALSE);
      again = true;
    }
    if (!again)
      KillTimer(h, 1);
    return 0;
  }
  case UpdateMessage:
    InvalidateRect(h, nullptr, FALSE);
    return 0;
  case DoneMessage: {
    if (worker.joinable())
      worker.join();
    working = false;
    if (w == 3) {
      if (completed.cancelled) {
        BuildPage(1);
        return 0;
      }
      if (completed.ok) {
        ack = false;
        BuildPage(5);
      } else {
        statusText = completed.message;
        BuildPage(6);
      }
      return 0;
    }
    SaveReport(completed);
    if (completed.ok) {
      cleanupOnExit = Removing;
      BuildPage(3);
      if (readGuide && !Removing) {
        returnPage = 3;
        BuildPage(4);
      }
    } else {
      statusText = completed.message;
      BuildPage(6);
    }
    return 0;
  }
  case WM_CLOSE:
    Close();
    return 0;
  case WM_DESTROY:
    PostQuitMessage(0);
    return 0;
  }
  return DefWindowProcW(h, m, w, l);
}
static LRESULT CALLBACK ButtonHook(HWND h, UINT m, WPARAM w, LPARAM l, UINT_PTR,
                                   DWORD_PTR) {
  if (m == WM_MOUSEMOVE || m == WM_MOUSELEAVE) {
    Animate();
    if (m == WM_MOUSEMOVE) {
      TRACKMOUSEEVENT t{sizeof(t), TME_LEAVE, h, 0};
      TrackMouseEvent(&t);
    }
  }
  return DefSubclassProc(h, m, w, l);
}

int RunUI(bool demo, const fs::path &report, bool removalFixture) {
  uiReport = report;
  preview = demo;
  liveRemovalTest = removalFixture;
  if (removalFixture) {
    auto root = SelfPath().parent_path();
    wchar_t temp[32768];
    GetTempPathW(32768, temp);
    auto tempRoot = fs::path(temp).lexically_normal();
    if (tempRoot.filename().empty())
      tempRoot = tempRoot.parent_path();
    auto base = root.parent_path();
    auto marker = root / L".uninstall-fixture";
    if (!Removing || demo || root.filename() != L"interactive-app" ||
        base.parent_path().lexically_normal() != tempRoot ||
        base.filename().wstring().rfind(L"AHKGOS-selftest-", 0) != 0 ||
        report.parent_path() != base || !fs::exists(marker))
      throw std::runtime_error(
          "Live removal tests require a disposable Temp fixture");
    auto bytes = Read(marker);
    if (std::string(bytes.begin(), bytes.end()) != "AHKGOS-DISPOSABLE-1")
      throw std::runtime_error("Invalid disposable removal marker");
    DeleteFileW(marker.c_str());
    fixtureData = base / L"interactive-profiles";
    rootText = root.wstring();
    uiLog = "Actual installed uninstaller UI in disposable Temp fixture. No "
            "user profiles, registry, desktop or fixed-drive scan.\r\n";
  } else
    rootText = (Removing ? LocateRoot() : DefaultRoot()).wstring();
  GdiplusStartupInput input;
  GdiplusStartup(&graphicsToken, &input, nullptr);
  INITCOMMONCONTROLSEX cc{sizeof(cc),
                          ICC_LISTVIEW_CLASSES | ICC_STANDARD_CLASSES};
  InitCommonControlsEx(&cc);
  auto dpiFn = (UINT(WINAPI *)())GetProcAddress(GetModuleHandleW(L"user32.dll"),
                                                "GetDpiForSystem");
  if (dpiFn)
    scale = dpiFn() / 96.f;
  RECT work;
  SystemParametersInfoW(SPI_GETWORKAREA, 0, &work, 0);
  scale = std::min(scale, std::min((work.right - work.left - 30) / 1040.f,
                                   (work.bottom - work.top - 30) / 704.f));
  scale = std::max(.65f, scale);
  WNDCLASSW cls{};
  cls.hInstance = GetModuleHandleW(nullptr);
  cls.lpfnWndProc = WindowProc;
  cls.lpszClassName = L"AHKGOS.Native.Setup";
  cls.hCursor = LoadCursorW(nullptr, IDC_ARROW);
  cls.hIcon = LoadIconW(cls.hInstance, MAKEINTRESOURCEW(1));
  RegisterClassW(&cls);
  HWND h = CreateWindowExW(
      WS_EX_APPWINDOW, cls.lpszClassName,
      Removing ? L"AHK FOR GOS — удаление" : L"AHK FOR GOS — установка",
      WS_POPUP | WS_SYSMENU | WS_MINIMIZEBOX | WS_CLIPCHILDREN,
      (work.right - S(1040)) / 2, (work.bottom - S(704)) / 2, S(1040), S(704),
      nullptr, nullptr, cls.hInstance, nullptr);
  if (!h)
    return 2;
  BOOL dark = TRUE;
  DwmSetWindowAttribute(h, 20, &dark, sizeof(dark));
  int round = 2;
  DwmSetWindowAttribute(h, 33, &round, sizeof(round));
  BuildPage(0);
  ShowWindow(h, SW_SHOW);
  SetForegroundWindow(h);
  UpdateWindow(h);
  if (!uiReport.empty())
    SetTimer(h, 2, 320, nullptr);
  MSG msg;
  while (GetMessageW(&msg, nullptr, 0, 0) > 0) {
    for (auto &b : buttons)
      SetWindowSubclass(b->h, ButtonHook, 1, 0);
    if (msg.message == WM_KEYDOWN && msg.wParam == VK_ESCAPE) {
      if (page == 4)
        BuildPage(returnPage);
      else
        Close();
      continue;
    }
    if (!IsDialogMessageW(h, &msg)) {
      TranslateMessage(&msg);
      DispatchMessageW(&msg);
    }
  }
  if (worker.joinable()) {
    cancelled = true;
    worker.join();
  }
  if (cleanupOnExit && Removing && !preview) {
    try {
      auto root = fs::path(rootText);
      if (_wcsicmp(SelfPath().parent_path().c_str(), root.c_str()) == 0) {
        wchar_t temp[32768];
        GetTempPathW(32768, temp);
        auto helper =
            fs::path(temp) /
            (L"AHKGOS-cleanup-" + std::to_wstring(GetCurrentProcessId()) +
             L"-" + std::to_wstring(GetTickCount64()) + L".tmp");
        NoLinks(helper);
        fs::copy_file(SelfPath(), helper);
        std::wstring cmd = L"\"" + helper.wstring() + L"\" --finish-remove \"" +
                           root.wstring() + L"\" --wait-pid " +
                           std::to_wstring(GetCurrentProcessId());
        STARTUPINFOW si{sizeof(si)};
        PROCESS_INFORMATION pi{};
        if (CreateProcessW(helper.c_str(), cmd.data(), nullptr, nullptr, FALSE,
                           CREATE_NO_WINDOW, nullptr, temp, &si, &pi)) {
          CloseHandle(pi.hThread);
          CloseHandle(pi.hProcess);
        } else
          throw std::runtime_error(
              Utf8(LastErrorText(L"Не запустить завершение удаления. Повторите "
                                 L"запуск унинсталлера из другой папки.")));
      }
    } catch (const std::exception &e) {
      MessageBoxW(nullptr, Wide(e.what()).c_str(), Product, MB_ICONERROR);
    }
  }
  for (auto &b : buttons)
    if (IsWindow(b->h))
      DestroyWindow(b->h);
  GdiplusShutdown(graphicsToken);
  return uiFailed ? 1 : 0;
}
} // namespace gos
