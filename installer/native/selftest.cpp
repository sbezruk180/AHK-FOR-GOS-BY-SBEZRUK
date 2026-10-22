#include "core.hpp"
#include <algorithm>
#include <shellapi.h>
#include <sstream>
namespace gos {

static bool RunProbe(const Options &o, bool source) {
  auto exe = source ? o.root / L"runtime" / L"AutoHotkeyA32.exe"
                    : o.root / L"AHK_FOR_GOS.exe";
  auto data = o.data / (source ? L"source-probe" : L"exe-probe");
  std::wstring cmd = L"\"" + exe.wstring() + L"\" ";
  if (source)
    cmd += L"/ErrorStdOut /CP1251 \"" +
           (o.root / L"AHK_FOR_GOS_BY_SBEZRUK.ahk").wstring() + L"\" ";
  cmd += L"--runtime-info --data-dir \"" + data.wstring() + L"\"";
  STARTUPINFOW si{sizeof(si)};
  PROCESS_INFORMATION pi{};
  if (!CreateProcessW(exe.c_str(), cmd.data(), nullptr, nullptr, FALSE,
                      CREATE_NO_WINDOW, nullptr, o.root.c_str(), &si, &pi))
    return false;
  DWORD wait = WaitForSingleObject(pi.hProcess, 20000), exit = 1;
  if (wait != WAIT_OBJECT_0)
    TerminateProcess(pi.hProcess, 99);
  GetExitCodeProcess(pi.hProcess, &exit);
  CloseHandle(pi.hProcess);
  CloseHandle(pi.hThread);
  if (wait != WAIT_OBJECT_0 || exit != 0)
    return false;
  auto b = Read(data / L"runtime_info_report.txt");
  std::string text(b.begin(), b.end());
  return text.find("PointerSize=4") != text.npos &&
         text.find("Unicode=0") != text.npos &&
         text.find("LawDocuments=20") != text.npos &&
         text.find(source ? "Compiled=0" : "Compiled=1") != text.npos;
}

int SelfTest(const fs::path &report) {
  unsigned passed = 0, failed = 0;
  std::string log =
      "Native installer core tests. Only disposable Temp directories; no "
      "fixed-drive scan, real user profiles, registry or desktop changes.\r\n";
  auto check = [&](const std::string &name, bool ok) {
    log += (ok ? "PASS | " : "FAIL | ") + name + "\r\n";
    ok ? passed++ : failed++;
  };
  wchar_t temp[32768];
  GetTempPathW(32768, temp);
  auto base = fs::path(temp) /
              (L"AHKGOS-selftest-" + std::to_wstring(GetCurrentProcessId()) +
               L"-" + std::to_wstring(GetTickCount64()));
  fs::create_directories(base);
  std::atomic<bool> cancel(false);
  auto notify = [](const Progress &) {};
  try {
    check(
        "hash SHA256 standard vector",
        Hash(std::vector<unsigned char>{'a', 'b', 'c'}) ==
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
    for (auto p : {L"..\\evil.ahk", L"C:\\evil", L"\\\\server\\file",
                   L"folder\\..\\evil", L"a.ahk:stream", L"CON", L"aux.txt",
                   L"x\\LPT1.ahk", L"file. ", L".\\bad"})
      check("reject unsafe relative: " + Utf8(p), !SafeRelative(p));
    check("allow normal nested source path",
          SafeRelative(L"app\\reference_guides.ahk"));
    bool rejected = false;
    try {
      ValidateRoot(fs::path(temp).root_path());
    } catch (...) {
      rejected = true;
    }
    check("reject drive root", rejected);
    auto entries = Payload();
    check("embedded payload files", entries.size() > 60);
    bool runtime = false;
    for (auto &e : entries)
      if (e.name == L"runtime\\AutoHotkeyA32.exe")
        runtime = e.bytes.size() > 100000;
    check("official A32 runtime is embedded", runtime);
    auto entriesCount = entries.size();
    unsigned char bad[12]{};
    rejected = false;
    try {
      ParsePack(bad, sizeof(bad));
    } catch (...) {
      rejected = true;
    }
    check("reject invalid embedded package", rejected);
    Options o;
    o.root = base / L"app";
    o.data = base / L"profiles";
    o.integration = false;
    o.desktop = false;
    o.menu = false;
    o.mode = 1;
    auto installed = Install(o, cancel, notify);
    check("install EXE form", installed.ok);
    check("installed EXE exact hash",
          Hash(Read(o.root / L"AHK_FOR_GOS.exe")) ==
              std::find_if(entries.begin(), entries.end(), [](auto &e) {
                return e.name == L"AHK_FOR_GOS.exe";
              })->hash);
    if (!GetProcAddress(GetModuleHandleW(L"ntdll.dll"), "wine_get_version"))
      check("installed EXE boots real ANSI x86 runtime", RunProbe(o, false));
    else
      log += "SKIP | Wine64 environment has no 32-bit application runtime\r\n";
    check("EXE form does not install runtime",
          !fs::exists(o.root / L"runtime"));
    check("owned installation record", OwnedRoot(o.root));
    Write(o.data / L"profiles.ini", {'m', 'y', ' ', 'b', 'i', 'n', 'd', 's'});
    auto profile = Read(o.data / L"profiles.ini");
    cancel = true;
    auto aborted = Install(o, cancel, notify);
    cancel = false;
    check("cancel installation before writes",
          !aborted.ok && aborted.cancelled);
    check("cancel preserves current EXE",
          fs::exists(o.root / L"AHK_FOR_GOS.exe"));
    o.mode = 2;
    o.failAfter = 2;
    auto failure = Install(o, cancel, notify);
    o.failAfter = -1;
    check("simulated update failure", !failure.ok);
    check("rollback restores previous EXE",
          fs::exists(o.root / L"AHK_FOR_GOS.exe"));
    check("rollback preserves mode record", ReadRecord(o.root).mode == 1);
    check("rollback removes new source",
          !fs::exists(o.root / L"AHK_FOR_GOS_BY_SBEZRUK.ahk"));
    auto updated = Install(o, cancel, notify);
    check("switch EXE to source", updated.ok);
    check("source mode removes old EXE",
          !fs::exists(o.root / L"AHK_FOR_GOS.exe"));
    check(
        "source includes main and graph dependencies",
        fs::exists(o.root / L"AHK_FOR_GOS_BY_SBEZRUK.ahk") &&
            fs::exists(o.root / L"tests" / L"reference_guides_regression.ahk"));
    check("source includes runtime",
          fs::exists(o.root / L"runtime" / L"AutoHotkeyA32.exe"));
    if (!GetProcAddress(GetModuleHandleW(L"ntdll.dll"), "wine_get_version"))
      check("installed AHK boots bundled ANSI x86 runtime", RunProbe(o, true));
    else
      log += "SKIP | Wine64 environment cannot execute bundled A32\r\n";
    check("source includes laws", fs::exists(o.root / L"laws" / L"UK.txt"));
    check("profile bytes preserved across mode change",
          Read(o.data / L"profiles.ini") == profile);
    auto source = Read(o.root / L"app" / L"reference_guides.ahk");
    auto edited = source;
    edited.push_back(';');
    Write(o.root / L"app" / L"reference_guides.ahk", edited);
    auto again = Install(o, cancel, notify);
    check("upgrade source form", again.ok);
    bool backup = false;
    for (auto &p : fs::recursive_directory_iterator(o.data)) {
      if (p.path().filename() == L"reference_guides.ahk")
        backup = Read(p.path()) == edited;
    }
    check("edited program file backed up", backup);
    Write(o.root / L"my-unrelated.txt", {'k', 'e', 'e', 'p'});
    auto removed = Uninstall(o, true, cancel, notify);
    check("uninstall keep profiles", removed.ok);
    check("keep profiles preserves exact bytes",
          Read(o.data / L"profiles.ini") == profile);
    check("uninstall preserves unrelated files",
          fs::exists(o.root / L"my-unrelated.txt"));
    check("uninstall removes bundled A32",
          !fs::exists(o.root / L"runtime" / L"AutoHotkeyA32.exe"));
    fs::remove(o.root / L"my-unrelated.txt");
    Write(o.root / L"profiles.ini", profile);
    check("profile-preserving removal retains reinstall metadata",
          ReadRecord(o.root).profilesKept);
    auto reinstalled = Install(o, cancel, notify);
    check("reinstall after removal", reinstalled.ok);
    check("reinstall preserves portable profile beside source",
          Read(o.root / L"profiles.ini") == profile);
    check("reinstall reuses saved profiles",
          Read(o.data / L"profiles.ini") == profile);
    auto full = Uninstall(o, false, cancel, notify);
    check("full project removal", full.ok);
    check("full removes project data", !fs::exists(o.data));
    auto scanRoot = base / L"scan";
    fs::create_directories(scanRoot / L"nested");
    Write(scanRoot / L"one.ahk", {'x'});
    Write(scanRoot / L"nested" / L"two.AHK", {'y'});
    Write(scanRoot / L"unrelated.exe", {'z'});
    auto scanned = ScanAhk({scanRoot}, cancel, notify);
    check("scan finds both lower and uppercase AHK", scanned.files.size() == 2);
    check("scan never auto-selects files",
          std::none_of(scanned.files.begin(), scanned.files.end(),
                       [](auto &f) { return f.selected; }));
    check("scan does not delete or change files",
          Read(scanRoot / L"one.ahk") == std::vector<unsigned char>{'x'});
    cancel = true;
    auto interrupted = ScanAhk({scanRoot}, cancel, notify);
    cancel = false;
    check("scan cancellation", interrupted.cancelled);
    auto ownExecutable = scanRoot / L"renamed-helper.exe";
    auto exeEntry = std::find_if(entries.begin(), entries.end(), [](auto &e) {
      return e.name == L"AHK_FOR_GOS.exe";
    });
    Write(ownExecutable, exeEntry->bytes);
    auto withExe = ScanAhk({scanRoot}, cancel, notify);
    check("scan identifies this product EXE even renamed",
          withExe.files.size() == 3);
    check(
        "scan does not include other EXE",
        std::none_of(withExe.files.begin(), withExe.files.end(), [&](auto &f) {
          return f.path.filename() == L"unrelated.exe";
        }));
    auto noSelection = RecycleSelected(scanned.files, cancel, notify);
    check("no selection deletes nothing",
          noSelection.removed == 0 && fs::exists(scanRoot / L"one.ahk"));
    scanned.files[0].selected = true;
    Write(scanned.files[0].path, {'c', 'h', 'a', 'n', 'g', 'e', 'd'});
    auto changed = RecycleSelected(scanned.files, cancel, notify);
    check("changed file not recycled", changed.failed == 1 &&
                                           changed.removed == 0 &&
                                           fs::exists(scanned.files[0].path));
    Options legacyOptions = o;
    legacyOptions.root = base / L"legacy-source";
    legacyOptions.data = base / L"legacy-profiles";
    for (auto name : {L"AHK_FOR_GOS_BY_SBEZRUK.ahk", L"UDF.ahk", L"common.ahk",
                      L"laws\\UK.txt"}) {
      auto e = std::find_if(entries.begin(), entries.end(),
                            [&](auto &entry) { return entry.name == name; });
      if (e == entries.end())
        throw std::runtime_error("Missing source fixture entry");
      Write(legacyOptions.root / name, e->bytes);
    }
    Write(legacyOptions.root / L"foreign.ahk", {'k', 'e', 'e', 'p'});
    Write(legacyOptions.data / L"profiles.ini", profile);
    check("recognise existing source distribution without marker",
          CanManage(legacyOptions.root));
    check("legacy ownership detection is read only",
          !fs::exists(legacyOptions.root / L"install.manifest"));
    auto legacyRemoved = Uninstall(legacyOptions, true, cancel, notify);
    check("remove recognised legacy source dependencies",
          legacyRemoved.ok && !fs::exists(legacyOptions.root / L"UDF.ahk"));
    check("legacy removal preserves foreign AHK",
          fs::exists(legacyOptions.root / L"foreign.ahk"));
    check("legacy keep profiles preserves bytes",
          Read(legacyOptions.data / L"profiles.ini") == profile);
    legacyOptions.root = base / L"legacy-exe";
    Write(legacyOptions.root / L"AHK_FOR_GOS.exe", exeEntry->bytes);
    check("recognise previous EXE distribution", CanManage(legacyOptions.root));
    auto oldExeRemoved = Uninstall(legacyOptions, false, cancel, notify);
    check("remove legacy EXE and requested project data",
          oldExeRemoved.ok &&
              !fs::exists(legacyOptions.root / L"AHK_FOR_GOS.exe") &&
              !fs::exists(legacyOptions.data));
    Options fresh = o;
    fresh.root = base / L"fresh-retry";
    fresh.data = base / L"fresh-data";
    fresh.mode = 2;
    fresh.failAfter = 8;
    auto failedFresh = Install(fresh, cancel, notify);
    check("fresh installation failure is reported", !failedFresh.ok);
    check("rollback removes new empty directories",
          !fs::exists(fresh.root) || fs::is_empty(fresh.root));
    fresh.failAfter = -1;
    auto retried = Install(fresh, cancel, notify);
    check("fresh installation can retry after rollback", retried.ok);
    check("retry has a complete ownership record",
          ReadRecord(fresh.root).mode == 2);
    Uninstall(fresh, false, cancel, notify);
    auto rogue = base / L"rogue";
    fs::create_directories(rogue);
    Write(rogue / L"personal.txt", {'p'});
    o.root = rogue;
    check("install rejects occupied unrelated folder",
          !Install(o, cancel, notify).ok);
    check("uninstall rejects unrelated folder",
          !Uninstall(o, false, cancel, notify).ok);
    check("unrelated folder remains intact",
          fs::exists(rogue / L"personal.txt"));
    auto links = base / L"linked";
    BOOL symlink = CreateSymbolicLinkW(links.c_str(), scanRoot.c_str(),
                                       SYMBOLIC_LINK_FLAG_DIRECTORY | 0x2);
    DWORD attributes = GetFileAttributesW(links.c_str());
    if (symlink && attributes != INVALID_FILE_ATTRIBUTES &&
        (attributes & FILE_ATTRIBUTE_REPARSE_POINT)) {
      rejected = false;
      try {
        NoLinks(links / L"one.ahk");
      } catch (...) {
        rejected = true;
      }
      check("junction or symlink parent rejected", rejected);
      RemoveDirectoryW(links.c_str());
    } else
      log += "SKIP | symlink creation unavailable in this environment\r\n";
  } catch (const std::exception &e) {
    check(std::string("unexpected exception: ") + e.what(), false);
  }
  log += "Checks=" + std::to_string(passed + failed) +
         " Failed=" + std::to_string(failed) + "\r\n";
  std::vector<unsigned char> b(log.begin(), log.end());
  Write(report, b);
  std::error_code ec;
  fs::remove_all(base, ec);
  return failed ? 1 : 0;
}
} // namespace gos
