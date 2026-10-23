#include "core.hpp"
#include <algorithm>
#include <shellapi.h>
#include <shobjidl.h>
#include <sstream>
#include <thread>
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

static bool TestLink(const fs::path &path, const fs::path &target,
                     const std::wstring &args = L"") {
  fs::create_directories(path.parent_path());
  IShellLinkW *link = nullptr;
  if (FAILED(CoCreateInstance(CLSID_ShellLink, nullptr, CLSCTX_INPROC_SERVER,
                              IID_IShellLinkW, (void **)&link)))
    return false;
  link->SetPath(target.c_str());
  link->SetArguments(args.c_str());
  IPersistFile *file = nullptr;
  bool ok = false;
  if (SUCCEEDED(link->QueryInterface(IID_IPersistFile, (void **)&file))) {
    ok = SUCCEEDED(file->Save(path.c_str(), TRUE));
    file->Release();
  }
  link->Release();
  return ok;
}
static bool RunRemovalProbe(const fs::path &exe, const fs::path &report) {
  std::wstring command = L"\"" + exe.wstring() + L"\" --self-test-removal \"" +
                         report.wstring() + L"\"";
  STARTUPINFOW si{sizeof(si)};
  PROCESS_INFORMATION pi{};
  if (!CreateProcessW(exe.c_str(), command.data(), nullptr, nullptr, FALSE, 0,
                      nullptr, exe.parent_path().c_str(), &si, &pi))
    return false;
  DWORD wait = WaitForSingleObject(pi.hProcess, 30000), exit = 1;
  if (wait != WAIT_OBJECT_0)
    TerminateProcess(pi.hProcess, 99);
  GetExitCodeProcess(pi.hProcess, &exit);
  CloseHandle(pi.hProcess);
  CloseHandle(pi.hThread);
  if (wait != WAIT_OBJECT_0 || exit || !fs::exists(report))
    return false;
  auto bytes = Read(report);
  std::string text(bytes.begin(), bytes.end());
  return text.find("Failed=0") != text.npos;
}

int SelfTest(const fs::path &report, const fs::path &legacyFixture) {
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
    Options renamed = o;
    renamed.root = base / L"renamed-installed";
    renamed.data = base / L"renamed-profiles";
    renamed.mode = 2;
    check("install rename fixture", Install(renamed, cancel, notify).ok);
    fs::rename(renamed.root / L"AHK_FOR_GOS_BY_SBEZRUK.ahk",
               renamed.root / L"AHK FOR GOS (new name).ahk");
    fs::rename(renamed.root / L"app" / L"actions.ahk",
               renamed.root / L"app" / L"actions (copy).ahk");
    Write(renamed.data / L"profiles.ini", profile);
    auto renameRemoved = Uninstall(renamed, true, cancel, notify);
    check("manifest removal finds renamed main and module",
          renameRemoved.ok &&
              !fs::exists(renamed.root / L"AHK FOR GOS (new name).ahk") &&
              !fs::exists(renamed.root / L"app" / L"actions (copy).ahk"));
    check("keep profiles also removes empty installation folder",
          !fs::exists(renamed.root) &&
              Read(renamed.data / L"profiles.ini") == profile);
    check("cloud tag accepted",
          SafeCloudTag(0x9000001A) && SafeCloudTag(0x9000F01A));
    check("junction symlink and unknown tags rejected",
          !SafeCloudTag(0xA0000003) && !SafeCloudTag(0xA000000C) &&
              !SafeCloudTag(0x80000015));
    check("common drive root never offered as whole folder",
          !CanRecycleFolder(base.root_path()));
    auto scanRoot = base / L"scan";
    fs::create_directories(scanRoot / L"nested");
    Write(scanRoot / L"one.ahk", {'x'});
    Write(scanRoot / L"nested" / L"two.AHK", {'y'});
    Write(scanRoot / L"unrelated.exe", {'z'});
    auto scanned = ScanAhk({scanRoot}, cancel, notify);
    check("scan finds both lower and uppercase AHK",
          std::count_if(scanned.files.begin(), scanned.files.end(),
                        [](auto &f) { return !f.directory; }) == 2);
    check(
        "scan offers folder including non-AHK contents",
        std::count_if(scanned.files.begin(), scanned.files.end(), [](auto &f) {
          return f.directory && f.contents.size() == 4;
        }) == 1);
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
          std::count_if(withExe.files.begin(), withExe.files.end(),
                        [](auto &f) { return !f.directory; }) == 3);
    check(
        "scan does not include other EXE",
        std::none_of(withExe.files.begin(), withExe.files.end(), [&](auto &f) {
          return f.path.filename() == L"unrelated.exe";
        }));
    auto noSelection = RecycleSelected(scanned.files, cancel, notify);
    check("no selection deletes nothing",
          noSelection.removed == 0 && fs::exists(scanRoot / L"one.ahk"));
    auto changedFile = std::find_if(scanned.files.begin(), scanned.files.end(),
                                    [](auto &f) { return !f.directory; });
    changedFile->selected = true;
    Write(changedFile->path, {'c', 'h', 'a', 'n', 'g', 'e', 'd'});
    auto changed = RecycleSelected(scanned.files, cancel, notify);
    check("changed file not recycled", changed.failed == 1 &&
                                           changed.removed == 0 &&
                                           fs::exists(changedFile->path));
    auto folderOnly = withExe.files;
    for (auto &f : folderOnly)
      f.selected = f.directory;
    auto folderChanged = RecycleSelected(folderOnly, cancel, notify);
    check("changed folder contents refuse whole-folder deletion",
          folderChanged.failed == 1 && fs::exists(scanRoot));
    auto shortcuts = base / L"shortcuts";
    check("create renamed shortcut fixture",
          TestLink(shortcuts / L"GOS (old version).lnk", ownExecutable));
    check("create source shortcut fixture with global interpreter",
          TestLink(shortcuts / L"AHK test renamed.lnk", SelfPath(),
                   L"\"" + (scanRoot / L"one.ahk").wstring() + L"\""));
    check("create unrelated shortcut fixture",
          TestLink(shortcuts / L"Keep me.lnk", SelfPath()));
    Result shortcutResult;
    RemoveMatchingShortcuts({shortcuts}, {scanRoot}, shortcutResult);
    check("remove renamed shortcuts by target or script argument",
          shortcutResult.removed == 2 &&
              !fs::exists(shortcuts / L"GOS (old version).lnk") &&
              !fs::exists(shortcuts / L"AHK test renamed.lnk"));
    check("preserve unrelated shortcut",
          fs::exists(shortcuts / L"Keep me.lnk"));
    auto wholeFolder = ScanAhk({scanRoot}, cancel, notify);
    for (auto &f : wholeFolder.files)
      f.selected = f.directory;
    // Only this disposable test directory is being removed. Exercise Windows'
    // extra permanent-delete prompt as well on volumes without a recycle bin.
    std::atomic<bool> recycleDone(false);
    std::thread confirmFixture([&] {
      while (!recycleDone.load()) {
        EnumWindows(
            [](HWND h, LPARAM) -> BOOL {
              DWORD pid = 0;
              GetWindowThreadProcessId(h, &pid);
              wchar_t cls[32]{};
              GetClassNameW(h, cls, 32);
              if (pid == GetCurrentProcessId() && !wcscmp(cls, L"#32770") &&
                  GetDlgItem(h, IDYES))
                PostMessageW(h, WM_COMMAND, IDYES, 0);
              return TRUE;
            },
            0);
        Sleep(50);
      }
    });
    auto recycledFolder = RecycleSelected(wholeFolder.files, cancel, notify);
    recycleDone = true;
    confirmFixture.join();
    check("selected whole folder including non-AHK files is really removed",
          recycledFolder.ok && recycledFolder.removedFolders == 2 &&
              recycledFolder.removed == 4 && !fs::exists(scanRoot));
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
    legacyOptions.root = base / L"legacy-renamed-exe";
    Write(legacyOptions.root / L"GOS Police 2026.exe", exeEntry->bytes);
    check("recognise renamed portable EXE", CanManage(legacyOptions.root));
    auto aliasExeRemoved = Uninstall(legacyOptions, true, cancel, notify);
    check("remove renamed portable EXE and its directory",
          aliasExeRemoved.ok && !fs::exists(legacyOptions.root));
    if (!legacyFixture.empty()) {
      Options old = o;
      old.root =
          base / L"legacy-wrapper" /
          L"AHK-FOR-GOS-BY-SBEZRUK-6b1a595605375e44d7d8aefed31aa768a710ce74";
      old.data = base / L"legacy60-data";
      fs::create_directories(old.root.parent_path());
      fs::copy(legacyFixture, old.root, fs::copy_options::recursive);
      Write(old.root / L"profiles.ini", profile);
      fs::rename(old.root / L"AHK_FOR_GOS_BY_SBEZRUK.ahk",
                 old.root / L"GOS old renamed.ahk");
      check("recognise actual 6b1a595 archive with renamed entry",
            CanManage(old.root));
      auto oldRemoved = Uninstall(old, true, cancel, notify);
      unsigned remainingFiles = 0;
      for (auto &e : fs::recursive_directory_iterator(old.root))
        if (e.is_regular_file() && e.path().filename() != L"profiles.ini" &&
            e.path().filename() != L"install.manifest")
          ++remainingFiles;
      check("all 60 historical archive files removed",
            oldRemoved.ok && !remainingFiles);
      check("old portable profile bytes retained",
            Read(old.root / L"profiles.ini") == profile);
      check("archive subdirectories removed",
            !fs::exists(old.root / L"tests") &&
                !fs::exists(old.root / L"laws") &&
                !fs::exists(old.root / L"tools"));
      check("wrapper directory resolves actual archive",
            ResolveRemovalRoot(old.root.parent_path()) == old.root);
      auto already = Uninstall(old, true, cancel, notify);
      check("nothing-to-remove is not reported as successful deletion",
            !already.ok);
      auto oldFull = Uninstall(old, false, cancel, notify);
      check("full deletion cleans remaining legacy profiles and root",
            oldFull.ok && !fs::exists(old.root));
    } else
      log += "SKIP | exact historical archive fixture not supplied\r\n";
    Options interactive = o;
    interactive.root = base / L"interactive-app";
    interactive.data = base / L"interactive-profiles";
    interactive.mode = 1;
    check("install actual UI deletion fixture",
          Install(interactive, cancel, notify).ok);
    Write(interactive.data / L"profiles.ini", profile);
    fs::rename(interactive.root / L"AHK_FOR_GOS.exe",
               interactive.root / L"GOS helper (old).exe");
    auto installedUninstaller =
        interactive.root / L"Удалить GOS (new name).exe";
    fs::rename(interactive.root / L"Uninstall.exe", installedUninstaller);
    Write(interactive.root / L".uninstall-fixture",
          {'A', 'H', 'K', 'G', 'O', 'S', '-', 'D', 'I', 'S', 'P', 'O', 'S', 'A',
           'B', 'L', 'E', '-', '1'});
    check(
        "actual installed renamed uninstaller GUI deletes application",
        RunRemovalProbe(installedUninstaller, base / L"actual-removal-ui.txt"));
    for (unsigned retry = 0; retry < 100 && fs::exists(interactive.root);
         ++retry)
      Sleep(100);
    check("renamed running uninstaller and application folder self-remove",
          !fs::exists(interactive.root));
    check("real UI removal preserves profile bytes",
          Read(interactive.data / L"profiles.ini") == profile);
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
