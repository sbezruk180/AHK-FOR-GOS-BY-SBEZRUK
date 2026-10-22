#include "core.hpp"
#include <algorithm>
#include <bcrypt.h>
#include <iomanip>
#include <memory>
#include <set>
#include <shellapi.h>
#include <shlobj.h>
#include <shobjidl.h>
#include <sstream>
#include <stdexcept>
#include <tlhelp32.h>
#include <winver.h>
namespace gos {
static void Fail(const std::wstring &s) { throw std::runtime_error(Utf8(s)); }
std::wstring Wide(const std::string &s) {
  if (s.empty())
    return {};
  int n = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, s.data(),
                              (int)s.size(), nullptr, 0);
  if (!n)
    Fail(L"Неверный UTF-8 в пакете.");
  std::wstring w(n, 0);
  MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, s.data(), (int)s.size(),
                      w.data(), n);
  return w;
}
std::string Utf8(const std::wstring &w) {
  if (w.empty())
    return {};
  int n = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, w.data(),
                              (int)w.size(), nullptr, 0, nullptr, nullptr);
  if (!n)
    throw std::runtime_error("Invalid UTF16");
  std::string s(n, 0);
  WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, w.data(), (int)w.size(),
                      s.data(), n, nullptr, nullptr);
  return s;
}
std::wstring LastErrorText(const std::wstring &p) {
  DWORD e = GetLastError();
  wchar_t *b = nullptr;
  FormatMessageW(FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM |
                     FORMAT_MESSAGE_IGNORE_INSERTS,
                 nullptr, e, 0, (LPWSTR)&b, 0, nullptr);
  std::wstring s =
      p + L" (" + std::to_wstring(e) + L"): " + (b ? b : L"ошибка Windows");
  if (b)
    LocalFree(b);
  return s;
}
std::string Hash(const std::vector<unsigned char> &b) {
  BCRYPT_ALG_HANDLE a = nullptr;
  BCRYPT_HASH_HANDLE h = nullptr;
  DWORD len = 0, n = 0;
  std::vector<unsigned char> obj, out(32);
  if (BCryptOpenAlgorithmProvider(&a, BCRYPT_SHA256_ALGORITHM, nullptr, 0) < 0)
    Fail(L"SHA-256 недоступен.");
  BCryptGetProperty(a, BCRYPT_OBJECT_LENGTH, (PUCHAR)&len, sizeof(len), &n, 0);
  obj.resize(len);
  NTSTATUS st = BCryptCreateHash(a, &h, obj.data(), len, nullptr, 0, 0);
  if (st >= 0 && !b.empty())
    st = BCryptHashData(h, const_cast<PUCHAR>(b.data()), (ULONG)b.size(), 0);
  if (st >= 0)
    st = BCryptFinishHash(h, out.data(), 32, 0);
  if (h)
    BCryptDestroyHash(h);
  BCryptCloseAlgorithmProvider(a, 0);
  if (st < 0)
    Fail(L"Ошибка SHA-256.");
  std::ostringstream s;
  for (auto c : out)
    s << std::hex << std::setw(2) << std::setfill('0') << (unsigned)c;
  return s.str();
}
std::vector<unsigned char> Read(const fs::path &p) {
  HANDLE h = CreateFileW(p.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr,
                         OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT, nullptr);
  if (h == INVALID_HANDLE_VALUE)
    Fail(LastErrorText(L"Не прочитать " + p.wstring()));
  BY_HANDLE_FILE_INFORMATION info{};
  if (!GetFileInformationByHandle(h, &info) ||
      info.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) {
    CloseHandle(h);
    Fail(L"Ссылка вместо файла: " + p.wstring());
  }
  LARGE_INTEGER n{};
  GetFileSizeEx(h, &n);
  if (n.QuadPart < 0 || n.QuadPart > 256 * 1024 * 1024) {
    CloseHandle(h);
    Fail(L"Слишком большой файл.");
  }
  std::vector<unsigned char> b((size_t)n.QuadPart);
  DWORD got = 0;
  BOOL ok = b.empty() || ReadFile(h, b.data(), (DWORD)b.size(), &got, nullptr);
  CloseHandle(h);
  if (!ok || (!b.empty() && got != b.size()))
    Fail(L"Ошибка чтения: " + p.wstring());
  return b;
}
void Write(const fs::path &p, const std::vector<unsigned char> &b) {
  NoLinks(p.parent_path());
  fs::create_directories(p.parent_path());
  NoLinks(p);
  HANDLE h = CreateFileW(p.c_str(), GENERIC_WRITE, 0, nullptr, CREATE_ALWAYS,
                         FILE_ATTRIBUTE_NORMAL, nullptr);
  if (h == INVALID_HANDLE_VALUE)
    Fail(LastErrorText(L"Не записать " + p.wstring()));
  DWORD n = 0;
  BOOL ok = b.empty() || WriteFile(h, b.data(), (DWORD)b.size(), &n, nullptr);
  if (ok)
    ok = FlushFileBuffers(h);
  CloseHandle(h);
  if (!ok || (!b.empty() && n != b.size()))
    Fail(L"Ошибка записи: " + p.wstring());
}
static void Text(const fs::path &p, const std::string &s) {
  Write(p, std::vector<unsigned char>(s.begin(), s.end()));
}
fs::path SelfPath() {
  std::vector<wchar_t> b(32768);
  DWORD n = GetModuleFileNameW(nullptr, b.data(), (DWORD)b.size());
  if (!n || n >= b.size())
    Fail(L"Не определён путь программы.");
  return fs::path(std::wstring(b.data(), n));
}
static fs::path Known(REFKNOWNFOLDERID id) {
  PWSTR s = nullptr;
  HRESULT r = SHGetKnownFolderPath(id, 0, nullptr, &s);
  if (FAILED(r))
    Fail(L"Не найдена папка пользователя.");
  fs::path p(s);
  CoTaskMemFree(s);
  return p;
}
fs::path DefaultRoot() {
  return Known(FOLDERID_LocalAppData) / L"Programs" / L"AHK-FOR-GOS-BY-SBEZRUK";
}
fs::path DefaultData() {
  return Known(FOLDERID_RoamingAppData) / L"AHK FOR GOS";
}
static bool Same(const fs::path &a, const fs::path &b) {
  return _wcsicmp(a.lexically_normal().c_str(), b.lexically_normal().c_str()) ==
         0;
}
fs::path LocateRoot() {
  if (OwnedRoot(SelfPath().parent_path()))
    return SelfPath().parent_path();
  HKEY k;
  wchar_t p[32768];
  DWORD n = sizeof(p), t = 0;
  if (RegOpenKeyExW(HKEY_CURRENT_USER, RegistryKey, 0, KEY_READ, &k) ==
      ERROR_SUCCESS) {
    LONG r =
        RegQueryValueExW(k, L"InstallLocation", nullptr, &t, (BYTE *)p, &n);
    RegCloseKey(k);
    if (r == ERROR_SUCCESS && t == REG_SZ && n >= 2 && p[n / 2 - 1] == 0) {
      fs::path root = p;
      if (CanManage(root))
        return root;
    }
  }
  if (CanManage(SelfPath().parent_path()))
    return SelfPath().parent_path();
  return DefaultRoot();
}
bool SafeRelative(const std::wstring &s) {
  if (s.empty() || s.size() > 240 || s.front() == L'/' || s.front() == L'\\' ||
      s.find_first_of(L":|\r\n\t") != s.npos || s.back() == L'.' ||
      s.back() == L' ')
    return false;
  fs::path p(s);
  if (p.is_absolute() || p.has_root_path())
    return false;
  for (auto &c : p) {
    auto w = c.wstring();
    if (w == L".." || w == L"." || w.empty() || w.back() == L' ' ||
        w.back() == L'.')
      return false;
    auto base = w.substr(0, w.find(L'.'));
    std::transform(base.begin(), base.end(), base.begin(), ::towupper);
    if (base == L"CON" || base == L"PRN" || base == L"AUX" || base == L"NUL" ||
        (base.size() == 4 &&
         (base.substr(0, 3) == L"COM" || base.substr(0, 3) == L"LPT") &&
         iswdigit(base[3])))
      return false;
  }
  return true;
}
void NoLinks(const fs::path &p) {
  fs::path walk;
  for (auto &part : p.lexically_normal()) {
    walk /= part;
    DWORD a = GetFileAttributesW(walk.c_str());
    if (a != INVALID_FILE_ATTRIBUTES && (a & FILE_ATTRIBUTE_REPARSE_POINT))
      Fail(L"Нельзя использовать символьную ссылку или junction: " +
           walk.wstring());
  }
}
void ValidateRoot(const fs::path &p) {
  if (!p.is_absolute() || p.wstring().size() > 180 ||
      p.wstring().rfind(L"\\\\", 0) == 0 || p.lexically_normal() != p ||
      p == p.root_path())
    Fail(L"Выберите короткую локальную папку приложения, не корень диска.");
  std::vector<fs::path> blocked = {
      Known(FOLDERID_Profile),        Known(FOLDERID_Desktop),
      Known(FOLDERID_Documents),      Known(FOLDERID_LocalAppData),
      Known(FOLDERID_RoamingAppData), Known(FOLDERID_ProgramFiles),
      Known(FOLDERID_ProgramData),    DefaultData()};
  wchar_t win[MAX_PATH];
  GetWindowsDirectoryW(win, MAX_PATH);
  fs::path windows = win;
  for (auto &b : blocked)
    if (Same(p, b))
      Fail(L"Выберите отдельную подпапку для приложения.");
  auto ps = p.wstring(), ws = windows.wstring();
  if (_wcsnicmp(ps.c_str(), ws.c_str(), ws.size()) == 0 &&
      (ps.size() == ws.size() || ps[ws.size()] == L'\\'))
    Fail(L"Установка в системную папку запрещена.");
  NoLinks(p);
}
static std::set<std::wstring> Allowed() {
  HRSRC r = FindResourceW(nullptr, MAKEINTRESOURCEW(102), RT_RCDATA);
  if (!r)
    Fail(L"Нет списка файлов продукта.");
  auto p = (const char *)LockResource(LoadResource(nullptr, r));
  auto n = SizeofResource(nullptr, r);
  std::istringstream s(std::string(p, p + n));
  std::set<std::wstring> a;
  std::string line;
  while (std::getline(s, line)) {
    if (!line.empty() && line.back() == '\r')
      line.pop_back();
    auto w = Wide(line);
    if (!SafeRelative(w))
      Fail(L"Неверный список файлов.");
    a.insert(w);
  }
  return a;
}
bool OwnedRoot(const fs::path &root) {
  try {
    ValidateRoot(root);
    auto b = Read(root / L"install.manifest");
    return b.size() > 24 &&
           std::string(b.begin(), b.end()).rfind("AHKFORGOS-INSTALL-1\n", 0) ==
               0;
  } catch (...) {
    return false;
  }
}

static bool ProductExe(const fs::path &p);
static std::vector<std::pair<std::wstring, std::string>> KnownFiles() {
  HRSRC r = FindResourceW(nullptr, MAKEINTRESOURCEW(104), RT_RCDATA);
  if (!r)
    Fail(L"Нет каталога известных файлов.");
  auto p = (const char *)LockResource(LoadResource(nullptr, r));
  std::istringstream stream(std::string(p, p + SizeofResource(nullptr, r)));
  std::vector<std::pair<std::wstring, std::string>> known;
  std::string line;
  while (std::getline(stream, line)) {
    auto divider = line.find('|');
    if (divider == line.npos)
      Fail(L"Неверный каталог файлов.");
    auto name = Wide(line.substr(0, divider));
    if (!SafeRelative(name))
      Fail(L"Небезопасный каталог файлов.");
    known.push_back({name, line.substr(divider + 1)});
  }
  return known;
}
static Record LegacyRecord(const fs::path &root) {
  auto known = KnownFiles();
  bool owned = ProductExe(root / L"AHK_FOR_GOS.exe");
  auto main = std::find_if(known.begin(), known.end(), [](auto &e) {
    return e.first == L"AHK_FOR_GOS_BY_SBEZRUK.ahk";
  });
  if (!owned && main != known.end() && fs::exists(root / main->first))
    owned = Hash(Read(root / main->first)) == main->second;
  if (!owned)
    Fail(L"Не найдена проверяемая установка AHK FOR GOS. Выберите папку "
         L"проекта.");
  Record record;
  record.mode = fs::exists(root / L"AHK_FOR_GOS_BY_SBEZRUK.ahk") ? 2 : 1;
  for (auto &e : known) {
    auto file = root / e.first;
    if (!fs::exists(file) || fs::is_directory(file))
      continue;
    NoLinks(file);
    auto hash = Hash(Read(file));
    if (hash == e.second || (e.first == L"AHK_FOR_GOS.exe" && ProductExe(file)))
      record.files.push_back({e.first, hash});
  }
  if (record.files.empty())
    Fail(L"В папке нет проверяемых файлов этого проекта.");
  return record;
}

Record ReadRecord(const fs::path &root) {
  ValidateRoot(root);
  if (!fs::exists(root / L"install.manifest"))
    return LegacyRecord(root);
  auto b = Read(root / L"install.manifest");
  std::istringstream in(std::string(b.begin(), b.end()));
  std::string line;
  if (!std::getline(in, line) || line != "AHKFORGOS-INSTALL-1")
    Fail(L"Эта папка не является установкой AHK FOR GOS.");
  Record r;
  if (!std::getline(in, line) || (line != "1" && line != "2"))
    Fail(L"Неверная запись установки.");
  r.mode = std::stoi(line);
  auto allowed = Allowed();
  std::set<std::wstring> seen;
  while (std::getline(in, line)) {
    if (line.empty())
      continue;
    auto pos = line.find('|');
    if (pos == line.npos)
      Fail(L"Неверный манифест.");
    auto name = Wide(line.substr(0, pos));
    auto hash = line.substr(pos + 1);
    if (!SafeRelative(name) || !allowed.count(name) ||
        !seen.insert(name).second || hash.size() != 64 ||
        hash.find_first_not_of("0123456789abcdef") != hash.npos ||
        r.files.size() > 2000)
      Fail(L"Недопустимая запись манифеста.");
    r.files.push_back({name, hash});
  }
  if (r.files.empty())
    Fail(L"Пустой манифест.");
  return r;
}
bool CanManage(const fs::path &root) {
  try {
    ReadRecord(root);
    return true;
  } catch (...) {
    return false;
  }
}
static std::string RecordText(const Record &r) {
  std::string s = "AHKFORGOS-INSTALL-1\n" + std::to_string(r.mode) + "\n";
  for (auto &e : r.files)
    s += Utf8(e.first) + "|" + e.second + "\n";
  return s;
}
void PrepareRemoval(const fs::path &root) {
  auto record = ReadRecord(root);
  if (RunningFrom(root))
    Fail(L"Закройте AHK FOR GOS перед удалением.");
  if (!fs::exists(root / L"install.manifest"))
    Text(root / L"install.manifest", RecordText(record));
}
std::vector<Entry> ParsePack(const unsigned char *p, size_t n) {
  size_t at = 0;
  auto take = [&](size_t len) {
    if (len > n - at)
      Fail(L"Обрезанный установочный пакет.");
    auto q = p + at;
    at += len;
    return q;
  };
  auto magic = take(8);
  if (memcmp(magic, "AHKGOS01", 8))
    Fail(L"Неверная версия пакета.");
  auto num = [&](unsigned count) {
    ULONGLONG v = 0;
    auto q = take(count);
    for (unsigned i = 0; i < count; i++)
      v |= (ULONGLONG)q[i] << (8 * i);
    return v;
  };
  auto count = num(4);
  if (!count || count > 2000)
    Fail(L"Неверное число файлов.");
  std::vector<Entry> entries;
  std::set<std::wstring> names;
  for (unsigned i = 0; i < count; i++) {
    Entry e;
    e.mask = (unsigned)num(1);
    auto len = num(2), size = num(8);
    auto hash = take(32);
    std::ostringstream hs;
    for (unsigned j = 0; j < 32; j++)
      hs << std::hex << std::setw(2) << std::setfill('0') << (unsigned)hash[j];
    e.hash = hs.str();
    auto name = take((size_t)len);
    e.name = Wide(std::string((const char *)name, (size_t)len));
    auto key = e.name;
    std::transform(key.begin(), key.end(), key.begin(), ::towlower);
    if (!SafeRelative(e.name) || !names.insert(key).second || e.mask < 1 ||
        e.mask > 3 || size > 128 * 1024 * 1024)
      Fail(L"Недопустимый путь или размер в пакете.");
    auto bytes = take((size_t)size);
    e.bytes.assign(bytes, bytes + size);
    if (Hash(e.bytes) != e.hash)
      Fail(L"Повреждён файл пакета: " + e.name);
    entries.push_back(std::move(e));
  }
  if (at != n)
    Fail(L"Лишние данные в пакете.");
  return entries;
}
std::vector<Entry> Payload() {
  auto r = FindResourceW(nullptr, MAKEINTRESOURCEW(101), RT_RCDATA);
  if (!r)
    Fail(L"В этой программе нет установочного пакета.");
  auto p = (unsigned char *)LockResource(LoadResource(nullptr, r));
  return ParsePack(p, SizeofResource(nullptr, r));
}
bool RunningFrom(const fs::path &root) {
  HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if (snap == INVALID_HANDLE_VALUE)
    Fail(L"Не удалось проверить запущенные процессы.");
  PROCESSENTRY32W pe{sizeof(pe)};
  bool found = false;
  if (Process32FirstW(snap, &pe))
    do {
      if (pe.th32ProcessID == GetCurrentProcessId())
        continue;
      HANDLE h = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE,
                             pe.th32ProcessID);
      if (h) {
        wchar_t b[32768];
        DWORD len = 32768;
        if (QueryFullProcessImageNameW(h, 0, b, &len)) {
          fs::path p = b;
          auto candidate = p.lexically_normal().wstring(),
               prefix = root.lexically_normal().wstring() + L"\\";
          if (_wcsnicmp(candidate.c_str(), prefix.c_str(), prefix.size()) == 0)
            found = true;
        }
        CloseHandle(h);
      }
    } while (!found && Process32NextW(snap, &pe));
  CloseHandle(snap);
  return found;
}
static void Link(const fs::path &where, const fs::path &target,
                 const std::wstring &args, const fs::path &cwd) {
  NoLinks(where);
  fs::create_directories(where.parent_path());
  IShellLinkW *l = nullptr;
  HRESULT r = CoCreateInstance(CLSID_ShellLink, nullptr, CLSCTX_INPROC_SERVER,
                               IID_IShellLinkW, (void **)&l);
  if (FAILED(r))
    Fail(L"Не удалось создать ярлык.");
  l->SetPath(target.c_str());
  l->SetArguments(args.c_str());
  l->SetWorkingDirectory(cwd.c_str());
  l->SetDescription(L"AHK FOR GOS BY SBEZRUK");
  l->SetIconLocation((cwd / L"Uninstall.exe").c_str(), 0);
  IPersistFile *f = nullptr;
  r = l->QueryInterface(IID_IPersistFile, (void **)&f);
  if (SUCCEEDED(r)) {
    r = f->Save(where.c_str(), TRUE);
    f->Release();
  }
  l->Release();
  if (FAILED(r))
    Fail(L"Не удалось сохранить ярлык.");
}
static fs::path Menu() { return Known(FOLDERID_Programs) / L"AHK FOR GOS"; }
static void Shortcuts(const Options &o) {
  auto target = o.mode == 1 ? o.root / L"AHK_FOR_GOS.exe"
                            : o.root / L"runtime" / L"AutoHotkeyA32.exe";
  std::wstring args =
      o.mode == 1
          ? L""
          : L"/CP1251 \"" + (o.root / L"AHK_FOR_GOS_BY_SBEZRUK.ahk").wstring() +
                L"\" ";
  args += L" --data-dir \"" + o.data.wstring() + L"\"";
  if (o.desktop)
    Link(Known(FOLDERID_Desktop) / L"AHK FOR GOS.lnk", target, args, o.root);
  if (o.menu) {
    Link(Menu() / L"AHK FOR GOS.lnk", target, args, o.root);
    Link(Menu() / L"Удалить AHK FOR GOS.lnk", o.root / L"Uninstall.exe", L"",
         o.root);
  }
}
static void Register(const Options &o) {
  HKEY k;
  if (RegCreateKeyExW(HKEY_CURRENT_USER, RegistryKey, 0, nullptr, 0, KEY_WRITE,
                      nullptr, &k, nullptr) != ERROR_SUCCESS)
    Fail(L"Не удалось добавить приложение в список Windows.");
  auto set = [&](const wchar_t *n, const std::wstring &s) {
    LONG r = RegSetValueExW(k, n, 0, REG_SZ, (const BYTE *)s.c_str(),
                            (DWORD)((s.size() + 1) * 2));
    if (r != ERROR_SUCCESS) {
      RegCloseKey(k);
      Fail(L"Не удалось сохранить регистрацию Windows.");
    }
  };
  set(L"DisplayName", Product);
  set(L"Publisher", L"SBezruk180");
  set(L"DisplayVersion", L"1.0");
  set(L"InstallLocation", o.root.wstring());
  set(L"UninstallString",
      L"\"" + (o.root / L"Uninstall.exe").wstring() + L"\"");
  set(L"DisplayIcon", (o.root / L"Uninstall.exe").wstring() + L",0");
  set(L"InstallMode", o.mode == 1 ? L"exe" : L"ahk");
  DWORD one = 1;
  RegSetValueExW(k, L"NoModify", 0, REG_DWORD, (BYTE *)&one, 4);
  RegSetValueExW(k, L"NoRepair", 0, REG_DWORD, (BYTE *)&one, 4);
  RegCloseKey(k);
}
static std::vector<fs::path> Parents(fs::path p, const fs::path &root) {
  std::vector<fs::path> v;
  while (p != root && p.has_relative_path()) {
    v.push_back(p);
    p = p.parent_path();
  }
  return v;
}
static void EmptyDirs(const fs::path &root, const Record &r) {
  std::set<fs::path> dirs;
  for (auto &e : r.files)
    for (auto &p : Parents((root / e.first).parent_path(), root))
      dirs.insert(p);
  std::vector<fs::path> v(dirs.begin(), dirs.end());
  std::sort(v.begin(), v.end(), [](auto &a, auto &b) {
    return a.native().size() > b.native().size();
  });
  for (auto &p : v)
    RemoveDirectoryW(p.c_str());
}
static bool ProductExe(const fs::path &p) {
  DWORD x = 0, n = GetFileVersionInfoSizeW(p.c_str(), &x);
  if (!n || n > 1024 * 1024)
    return false;
  std::vector<BYTE> b(n);
  if (!GetFileVersionInfoW(p.c_str(), 0, n, b.data()))
    return false;
  LPVOID value = nullptr;
  UINT len = 0;
  return VerQueryValueW(b.data(), L"\\StringFileInfo\\040904B0\\ProductName",
                        &value, &len) &&
         len > 0 && std::wstring((wchar_t *)value) == Product;
}
static bool Legacy(const fs::path &root) {
  return ProductExe(root / L"AHK_FOR_GOS.exe");
}
static void CopyCancelled(std::atomic<bool> &c) {
  if (c.load())
    throw std::runtime_error("CANCELLED");
}
Result Install(const Options &o, std::atomic<bool> &cancel,
               const Notify &notify) {
  Result result;
  fs::path stage;
  std::vector<fs::path> written, backed;
  std::vector<Entry> entries;
  Record old, record;
  bool hadRecord = false, committed = false;
  try {
    ValidateRoot(o.root);
    NoLinks(o.data);
    if (o.mode != 1 && o.mode != 2)
      Fail(L"Неверный тип установки.");
    if (RunningFrom(o.root))
      Fail(L"Закройте AHK FOR GOS перед установкой или обновлением.");
    if (fs::exists(o.root)) {
      hadRecord = fs::exists(o.root / L"install.manifest");
      if (hadRecord)
        old = ReadRecord(o.root);
      else if (!fs::is_empty(o.root))
        old = ReadRecord(o.root);
    }
    entries = Payload();
    stage = o.root.parent_path() /
            (L".ahkgos-stage-" + std::to_wstring(GetCurrentProcessId()) + L"-" +
             std::to_wstring(GetTickCount64()));
    NoLinks(stage);
    fs::create_directories(stage / L"new");
    unsigned total = 0;
    for (auto &e : entries)
      if (e.mask & o.mode)
        total++;
    unsigned done = 0;
    record.mode = o.mode;
    for (auto &e : entries) {
      if (!(e.mask & o.mode))
        continue;
      CopyCancelled(cancel);
      notify({L"Подготовка: " + e.name, done, total * 2 + 1});
      Write(stage / L"new" / e.name, e.bytes);
      record.files.push_back({e.name, e.hash});
      done++;
    }
    fs::create_directories(o.root);
    for (auto &e : record.files) {
      CopyCancelled(cancel);
      auto destination = o.root / e.first;
      NoLinks(destination);
      if (fs::exists(destination)) {
        bool known =
            std::any_of(old.files.begin(), old.files.end(),
                        [&](auto &item) { return item.first == e.first; });
        if (!known && !(Legacy(o.root) && e.first == L"AHK_FOR_GOS.exe"))
          Fail(L"Файл уже существует и не принадлежит прежней установке: " +
               destination.wstring());
        if (Same(destination, SelfPath()))
          Fail(L"Установщик нельзя запускать из папки назначения.");
        auto backup = stage / L"old" / e.first;
        fs::create_directories(backup.parent_path());
        fs::rename(destination, backup);
        backed.push_back(e.first);
      }
      fs::create_directories(destination.parent_path());
      fs::rename(stage / L"new" / e.first, destination);
      written.push_back(e.first);
      notify({L"Установка: " + e.first, ++done, total * 2 + 1});
      if (o.failAfter >= 0 && (int)written.size() >= o.failAfter)
        Fail(L"TEST: simulated write failure");
    }
    CopyCancelled(cancel);
    fs::create_directories(o.data);
    NoLinks(o.data);
    Text(o.root / L"install.manifest.new", RecordText(record));
    if (!MoveFileExW((o.root / L"install.manifest.new").c_str(),
                     (o.root / L"install.manifest").c_str(),
                     MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH))
      Fail(LastErrorText(L"Не сохранить запись установки"));
    committed = true;
    // Commit point: keep edited previous program files in the user's backup
    // folder.
    for (auto &e : old.files) {
      auto previous = stage / L"old" / e.first;
      if (!fs::exists(previous) &&
          std::none_of(record.files.begin(), record.files.end(),
                       [&](auto &current) { return current.first == e.first; }))
        previous = o.root / e.first;
      if (fs::exists(previous) && Hash(Read(previous)) != e.second) {
        auto saved = o.data / L"backups" /
                     (L"before-update-" + std::to_wstring(GetTickCount64())) /
                     e.first;
        fs::create_directories(saved.parent_path());
        fs::copy_file(previous, saved);
        result.warnings.push_back(L"Изменённый файл сохранён: " +
                                  saved.wstring());
      }
    }
    for (auto &e : old.files)
      if (std::none_of(record.files.begin(), record.files.end(),
                       [&](auto &f) { return f.first == e.first; })) {
        auto p = o.root / e.first;
        NoLinks(p);
        if (fs::exists(p) && !DeleteFileW(p.c_str()))
          result.warnings.push_back(L"Старый файл не удалён: " + p.wstring());
      }
    EmptyDirs(o.root, old);
    if (o.integration) {
      try {
        Shortcuts(o);
      } catch (const std::exception &e) {
        result.warnings.push_back(Wide(e.what()));
      }
      try {
        Register(o);
      } catch (const std::exception &e) {
        result.warnings.push_back(Wide(e.what()));
      }
    }
    if (o.integration && GetACP() != 1251)
      result.warnings.push_back(
          L"Системная ANSI-кодировка не CP1251. Проверьте русский ввод и "
          L"следуйте инструкции; установщик не меняет системную локаль.");
    fs::remove_all(stage);
    notify({L"Готово. Профили сохранены.", total * 2 + 1, total * 2 + 1});
    result.ok = true;
    result.message = L"AHK FOR GOS установлен";
    return result;
  } catch (const std::exception &e) {
    if (committed) {
      result.ok = true;
      result.message = L"AHK FOR GOS установлен с замечаниями.";
      result.warnings.push_back(Wide(e.what()));
      if (!stage.empty())
        result.warnings.push_back(L"Резервная папка: " + stage.wstring());
      return result;
    }
    for (auto it = written.rbegin(); it != written.rend(); ++it) {
      std::error_code ec;
      fs::remove(o.root / (*it), ec);
    }
    for (auto it = backed.rbegin(); it != backed.rend(); ++it) {
      std::error_code ec;
      fs::create_directories((o.root / (*it)).parent_path(), ec);
      fs::rename(stage / L"old" / (*it), o.root / (*it), ec);
      if (ec)
        result.warnings.push_back(L"Не восстановлен файл: " +
                                  (o.root / (*it)).wstring());
    }
    if (!stage.empty() && result.warnings.empty()) {
      std::error_code ec;
      fs::remove_all(stage, ec);
    }
    if (!stage.empty())
      DeleteFileW((o.root / L"install.manifest.new").c_str());
    result.cancelled = std::string(e.what()) == "CANCELLED";
    result.message =
        result.cancelled
            ? (result.warnings.empty()
                   ? L"Установка отменена. Прежние файлы восстановлены."
                   : L"Установка отменена; не все файлы восстановлены. "
                     L"Откройте отчёт.")
            : Wide(e.what());
    return result;
  }
}
static void RemoveLinkIfOwned(const fs::path &link, const fs::path &root) {
  if (!fs::exists(link))
    return;
  NoLinks(link);
  IShellLinkW *l = nullptr;
  if (FAILED(CoCreateInstance(CLSID_ShellLink, nullptr, CLSCTX_INPROC_SERVER,
                              IID_IShellLinkW, (void **)&l)))
    return;
  IPersistFile *f = nullptr;
  if (SUCCEEDED(l->QueryInterface(IID_IPersistFile, (void **)&f))) {
    if (SUCCEEDED(f->Load(link.c_str(), STGM_READ))) {
      wchar_t b[32768];
      WIN32_FIND_DATAW d{};
      if (SUCCEEDED(l->GetPath(b, 32768, &d, SLGP_RAWPATH))) {
        auto prefix = root.wstring() + L"\\";
        if (_wcsnicmp(b, prefix.c_str(), prefix.size()) == 0)
          DeleteFileW(link.c_str());
      }
    }
    f->Release();
  }
  l->Release();
}
static void RemoveTreeNoLinks(const fs::path &root, Result &result,
                              std::atomic<bool> *cancel = nullptr) {
  if (!fs::exists(root))
    return;
  NoLinks(root);
  std::error_code ec;
  std::vector<fs::path> files, dirs;
  for (fs::recursive_directory_iterator
           it(root, fs::directory_options::skip_permission_denied, ec),
       end;
       it != end; it.increment(ec)) {
    if (ec) {
      result.failed++;
      ec.clear();
      continue;
    }
    if (cancel)
      CopyCancelled(*cancel);
    auto p = it->path();
    DWORD a = GetFileAttributesW(p.c_str());
    if (a & FILE_ATTRIBUTE_REPARSE_POINT) {
      it.disable_recursion_pending();
      result.warnings.push_back(L"Ссылка пропущена: " + p.wstring());
      continue;
    }
    if (a & FILE_ATTRIBUTE_DIRECTORY)
      dirs.push_back(p);
    else
      files.push_back(p);
  }
  for (auto &p : files) {
    if (cancel)
      CopyCancelled(*cancel);
    if (DeleteFileW(p.c_str()))
      result.removed++;
    else {
      result.failed++;
      result.warnings.push_back(L"Не удалён: " + p.wstring());
    }
  }
  std::sort(dirs.begin(), dirs.end(), [](auto &a, auto &b) {
    return a.native().size() > b.native().size();
  });
  for (auto &p : dirs)
    if (!RemoveDirectoryW(p.c_str()) &&
        GetLastError() != ERROR_PATH_NOT_FOUND &&
        GetLastError() != ERROR_FILE_NOT_FOUND) {
      result.failed++;
      result.warnings.push_back(L"Папка не удалена: " + p.wstring());
    }
  if (!RemoveDirectoryW(root.c_str()) &&
      GetLastError() != ERROR_PATH_NOT_FOUND &&
      GetLastError() != ERROR_FILE_NOT_FOUND) {
    result.failed++;
    result.warnings.push_back(L"Папка не удалена: " + root.wstring());
  }
}
Result Uninstall(const Options &o, bool keepData, std::atomic<bool> &cancel,
                 const Notify &notify) {
  Result result;
  try {
    ValidateRoot(o.root);
    if (o.allScripts && !CanManage(o.root)) {
      if (o.integration && !Same(o.data, DefaultData()))
        Fail(L"Неизвестная папка данных.");
      RemoveTreeNoLinks(o.data, result, &cancel);
      result.ok = !result.failed;
      result.message =
          L"Выбранные файлы обработаны. Общие данные AHK FOR GOS удалены.";
      return result;
    }
    PrepareRemoval(o.root);
    auto record = ReadRecord(o.root);
    if (RunningFrom(o.root))
      Fail(L"Закройте AHK FOR GOS перед удалением.");
    unsigned i = 0;
    for (auto &e : record.files) {
      CopyCancelled(cancel);
      auto p = o.root / e.first;
      NoLinks(p);
      if (Same(p, SelfPath()))
        continue;
      notify({L"Удаление: " + e.first, ++i, (unsigned)record.files.size() + 1});
      if (!fs::exists(p))
        continue;
      if (DeleteFileW(p.c_str()))
        result.removed++;
      else {
        result.failed++;
        result.warnings.push_back(L"Не удалён: " + p.wstring());
      }
    }
    if (!keepData) {
      if (!Same(o.data, DefaultData()) && o.integration)
        Fail(L"Неизвестная папка профилей: удаление отменено.");
      RemoveTreeNoLinks(o.data, result, &cancel);
      for (auto name : {L"profiles.ini", L"profiles_updated.ini", L"themes.ini",
                        L"custom_functions.ini", L"error_log.txt"}) {
        auto p = o.root / name;
        NoLinks(p);
        if (fs::exists(p) && !DeleteFileW(p.c_str()))
          result.failed++;
      }
      for (auto name : {L"logs", L"backups"})
        RemoveTreeNoLinks(o.root / name, result, &cancel);
    }
    if (o.integration) {
      RemoveLinkIfOwned(Known(FOLDERID_Desktop) / L"AHK FOR GOS.lnk", o.root);
      RemoveLinkIfOwned(Menu() / L"AHK FOR GOS.lnk", o.root);
      RemoveLinkIfOwned(Menu() / L"Удалить AHK FOR GOS.lnk", o.root);
      RemoveDirectoryW(Menu().c_str());
      if (!result.failed && Same(LocateRoot(), o.root))
        RegDeleteTreeW(HKEY_CURRENT_USER, RegistryKey);
    }
    EmptyDirs(o.root, record);
    if (!Same(SelfPath(), o.root / L"Uninstall.exe") && !result.failed) {
      DeleteFileW((o.root / L"install.manifest").c_str());
      RemoveDirectoryW(o.root.c_str());
    }
    notify({L"Удаление завершено", 1, 1});
    result.ok = result.failed == 0;
    result.message =
        result.ok ? (keepData ? L"Приложение удалено. Профили сохранены."
                              : L"Приложение и его данные удалены.")
                  : L"Некоторые файлы недоступны. Их пути указаны в отчёте.";
    return result;
  } catch (const std::exception &e) {
    result.cancelled = std::string(e.what()) == "CANCELLED";
    result.message = result.cancelled
                         ? L"Удаление остановлено. Оставшиеся файлы можно "
                           L"удалить повторным запуском."
                         : Wide(e.what());
    return result;
  }
}
std::vector<fs::path> FixedRoots() {
  wchar_t drives[512];
  DWORD n = GetLogicalDriveStringsW(512, drives);
  if (!n || n >= 512)
    Fail(L"Не получен список дисков.");
  std::vector<fs::path> roots;
  for (wchar_t *p = drives; *p; p += wcslen(p) + 1)
    if (GetDriveTypeW(p) == DRIVE_FIXED)
      roots.emplace_back(p);
  return roots;
}
ScanResult ScanAhk(const std::vector<fs::path> &roots,
                   std::atomic<bool> &cancel, const Notify &notify) {
  ScanResult r;
  unsigned visited = 0;
  for (auto &root : roots) {
    std::vector<fs::path> stack{root};
    while (!stack.empty()) {
      if (cancel.load()) {
        r.cancelled = true;
        return r;
      }
      auto dir = stack.back();
      stack.pop_back();
      WIN32_FIND_DATAW d{};
      HANDLE h = FindFirstFileExW((dir / L"*").c_str(), FindExInfoBasic, &d,
                                  FindExSearchNameMatch, nullptr,
                                  FIND_FIRST_EX_LARGE_FETCH);
      if (h == INVALID_HANDLE_VALUE) {
        r.skipped++;
        continue;
      }
      do {
        if (cancel.load())
          break;
        if (!wcscmp(d.cFileName, L".") || !wcscmp(d.cFileName, L".."))
          continue;
        auto p = dir / d.cFileName;
        if (d.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) {
          r.skipped++;
          continue;
        }
        if (d.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)
          stack.push_back(p);
        else if (_wcsicmp(p.extension().c_str(), L".ahk") == 0 ||
                 (_wcsicmp(p.extension().c_str(), L".exe") == 0 &&
                  d.nFileSizeHigh == 0 && d.nFileSizeLow >= 1000000 &&
                  d.nFileSizeLow <= 64000000 && ProductExe(p))) {
          HANDLE f = CreateFileW(
              p.c_str(), FILE_READ_ATTRIBUTES,
              FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, nullptr,
              OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT, nullptr);
          BY_HANDLE_FILE_INFORMATION info{};
          if (f != INVALID_HANDLE_VALUE &&
              GetFileInformationByHandle(f, &info) &&
              !(info.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT)) {
            FoundFile item;
            item.path = p;
            item.size =
                ((ULONGLONG)info.nFileSizeHigh << 32) | info.nFileSizeLow;
            item.modified = info.ftLastWriteTime;
            item.volume = info.dwVolumeSerialNumber;
            item.indexHigh = info.nFileIndexHigh;
            item.indexLow = info.nFileIndexLow;
            r.files.push_back(item);
          } else
            r.skipped++;
          if (f != INVALID_HANDLE_VALUE)
            CloseHandle(f);
        }
        if (++visited % 200 == 0)
          notify({L"Проверено объектов: " + std::to_wstring(visited) +
                      L" · Найдено файлов: " + std::to_wstring(r.files.size()),
                  0, 0});
      } while (FindNextFileW(h, &d));
      FindClose(h);
    }
  }
  return r;
}
Result RecycleSelected(const std::vector<FoundFile> &files,
                       std::atomic<bool> &cancel, const Notify &notify) {
  Result r;
  unsigned done = 0, total = 0;
  for (auto &f : files)
    if (f.selected)
      total++;
  for (auto &f : files) {
    if (!f.selected)
      continue;
    if (cancel.load()) {
      r.cancelled = true;
      break;
    }
    try {
      NoLinks(f.path);
      HANDLE h = CreateFileW(
          f.path.c_str(), FILE_READ_ATTRIBUTES,
          FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, nullptr,
          OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT, nullptr);
      BY_HANDLE_FILE_INFORMATION i{};
      BOOL ok = h != INVALID_HANDLE_VALUE && GetFileInformationByHandle(h, &i);
      if (h != INVALID_HANDLE_VALUE)
        CloseHandle(h);
      if (!ok || i.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT ||
          i.dwVolumeSerialNumber != f.volume ||
          i.nFileIndexHigh != f.indexHigh || i.nFileIndexLow != f.indexLow ||
          i.nFileSizeHigh != (DWORD)(f.size >> 32) ||
          i.nFileSizeLow != (DWORD)f.size ||
          CompareFileTime(&i.ftLastWriteTime, &f.modified) != 0)
        Fail(L"Файл изменился после сканирования: " + f.path.wstring());
      std::wstring multi = f.path.wstring();
      multi.push_back(0);
      multi.push_back(0);
      SHFILEOPSTRUCTW op{};
      op.wFunc = FO_DELETE;
      op.pFrom = multi.c_str();
      op.fFlags = FOF_ALLOWUNDO | FOF_NOCONFIRMATION | FOF_NOERRORUI |
                  FOF_SILENT | FOF_WANTNUKEWARNING;
      int code = SHFileOperationW(&op);
      if (code || op.fAnyOperationsAborted)
        Fail(L"Не перемещён в корзину: " + f.path.wstring());
      r.removed++;
    } catch (const std::exception &e) {
      r.failed++;
      r.warnings.push_back(Wide(e.what()));
    }
    notify({L"В корзину: " + f.path.wstring(), ++done, total});
  }
  r.ok = !r.failed && !r.cancelled;
  r.message = L"Выбранные файлы: удалено " + std::to_wstring(r.removed) +
              L", ошибок " + std::to_wstring(r.failed);
  return r;
}
void Launch(const fs::path &root) {
  auto record = ReadRecord(root);
  auto file = record.mode == 1 ? root / L"AHK_FOR_GOS.exe"
                               : root / L"runtime" / L"AutoHotkeyA32.exe";
  std::wstring args =
      record.mode == 1
          ? L""
          : L"/CP1251 \"" + (root / L"AHK_FOR_GOS_BY_SBEZRUK.ahk").wstring() +
                L"\" ";
  args += L" --data-dir \"" + DefaultData().wstring() + L"\"";
  auto r = ShellExecuteW(nullptr, L"open", file.c_str(), args.c_str(),
                         root.c_str(), SW_SHOWNORMAL);
  if ((INT_PTR)r <= 32)
    Fail(L"Не удалось запустить приложение.");
}
void OpenGuide() {
  ShellExecuteW(nullptr, L"open",
                L"https://github.com/sbezruk180/AHK-FOR-GOS-BY-SBEZRUK",
                nullptr, nullptr, SW_SHOWNORMAL);
}
bool FinishRemove(const fs::path &root) {
  try {
    auto r = ReadRecord(root);
    for (auto &e : r.files) {
      auto p = root / e.first;
      NoLinks(p);
      if (fs::exists(p) && e.first != L"Uninstall.exe")
        return false;
    }
    NoLinks(root / L"Uninstall.exe");
    if (!DeleteFileW((root / L"Uninstall.exe").c_str()) &&
        GetLastError() != ERROR_FILE_NOT_FOUND)
      return false;
    DeleteFileW((root / L"install.manifest").c_str());
    EmptyDirs(root, r);
    RemoveDirectoryW(root.c_str());
    return true;
  } catch (...) {
    return false;
  }
}
} // namespace gos
