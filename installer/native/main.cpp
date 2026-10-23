#include "core.hpp"
#include <objbase.h>
#include <shellapi.h>
namespace gos {
int RunUI(bool, const fs::path &report = {}, bool removalFixture = false);
}
int WINAPI wWinMain(HINSTANCE, HINSTANCE, PWSTR, int) {
  CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  int result = 0;
  bool quiet = false;
  HANDLE instance = nullptr;
  try {
    int argc = 0;
    LPWSTR *argv = CommandLineToArgvW(GetCommandLineW(), &argc);
    if (!argv)
      return 2;
    std::vector<std::wstring> args;
    for (int i = 1; i < argc; i++)
      args.emplace_back(argv[i]);
    LocalFree(argv);
    quiet = !args.empty() && args[0] != L"--preview";
    if (args.size() == 2 && args[0] == L"--self-test") {
      result = gos::SelfTest(args[1]);
    } else if (args.size() == 4 && args[0] == L"--self-test" &&
               args[2] == L"--legacy-fixture") {
      result = gos::SelfTest(args[1], args[3]);
    } else if (args.size() == 2 && args[0] == L"--self-test-removal") {
      result = gos::RunUI(false, args[1], true);
    } else if (args.size() == 4 && args[0] == L"--finish-remove" &&
               args[2] == L"--wait-pid") {
      // The helper only removes the two remaining product files in a valid
      // owned root.
      DWORD pid = std::stoul(args[3]);
      HANDLE parent = OpenProcess(SYNCHRONIZE, FALSE, pid);
      if (parent) {
        DWORD wait = WaitForSingleObject(parent, 30000);
        CloseHandle(parent);
        if (wait != WAIT_OBJECT_0)
          return 3;
      }
      result = gos::FinishRemove(args[1]) ? 0 : 4;
      // Windows 10+ can unlink a running image using POSIX disposition. If the
      // OS does not support it, only this uniquely named .tmp helper remains
      // for Temp cleanup.
      HANDLE own = CreateFileW(
          gos::SelfPath().c_str(), DELETE,
          FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, nullptr,
          OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT, nullptr);
      if (own != INVALID_HANDLE_VALUE) {
        struct Disposition {
          DWORD flags;
        } d{0x1 | 0x2 | 0x10};
        SetFileInformationByHandle(own, (FILE_INFO_BY_HANDLE_CLASS)21, &d,
                                   sizeof(d));
        CloseHandle(own);
      }
    } else if (args.size() == 2 && args[0] == L"--ui-test") {
      result = gos::RunUI(true, args[1]);
    } else if (args.empty() || (args.size() == 1 && args[0] == L"--preview")) {
      instance = CreateMutexW(nullptr, TRUE, L"Local\\AHKFORGOS.Setup.UI.1");
      if (!instance || GetLastError() == ERROR_ALREADY_EXISTS) {
        MessageBoxW(nullptr, L"Установщик или удаление уже открыто.",
                    gos::Product, MB_ICONINFORMATION);
        if (instance)
          CloseHandle(instance);
        CoUninitialize();
        return 0;
      }
      result = gos::RunUI(!args.empty());
    } else
      throw std::runtime_error("Unknown argument");
  } catch (const std::exception &e) {
    if (!quiet)
      MessageBoxW(nullptr, gos::Wide(e.what()).c_str(), gos::Product,
                  MB_ICONERROR);
    result = 2;
  }
  if (instance) {
    ReleaseMutex(instance);
    CloseHandle(instance);
  }
  CoUninitialize();
  return result;
}
