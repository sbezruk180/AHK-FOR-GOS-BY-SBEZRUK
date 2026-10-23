#pragma once
#ifndef UNICODE
#define UNICODE
#define _UNICODE
#endif
#define NOMINMAX
#include <atomic>
#include <filesystem>
#include <functional>
#include <mutex>
#include <string>
#include <vector>
#include <windows.h>
namespace gos {
namespace fs = std::filesystem;
constexpr wchar_t Product[] = L"AHK FOR GOS";
constexpr wchar_t RegistryKey[] =
    L"Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\AHKFORGOS";
struct Entry {
  std::wstring name;
  unsigned mask;
  std::vector<unsigned char> bytes;
  std::string hash;
};
struct Record {
  int mode = 1;
  bool profilesKept = false;
  std::vector<std::pair<std::wstring, std::string>> files;
};
struct Options {
  fs::path root;
  fs::path data;
  int mode = 1;
  bool desktop = true, menu = true, integration = true;
  bool allScripts = false;
  int failAfter = -1;
};
struct Progress {
  std::wstring detail;
  unsigned done = 0, total = 1;
};
using Notify = std::function<void(const Progress &)>;
struct Result {
  bool ok = false, cancelled = false;
  unsigned removed = 0, removedFolders = 0, failed = 0;
  std::wstring message;
  std::vector<std::wstring> warnings;
};
struct FoundFile {
  fs::path path;
  ULONGLONG size = 0;
  FILETIME modified{};
  DWORD volume = 0, indexHigh = 0, indexLow = 0;
  bool selected = false;
  bool directory = false;
  // A folder is offered only with a complete, link-free snapshot. The user
  // chooses the whole folder explicitly; additions or changes invalidate it.
  std::vector<FoundFile> contents;
};
struct ScanResult {
  std::vector<FoundFile> files;
  unsigned skipped = 0;
  bool cancelled = false;
};
std::wstring Wide(const std::string &);
std::string Utf8(const std::wstring &);
std::string Hash(const std::vector<unsigned char> &);
std::vector<unsigned char> Read(const fs::path &);
void Write(const fs::path &, const std::vector<unsigned char> &);
fs::path SelfPath();
fs::path DefaultRoot();
fs::path DefaultData();
fs::path LocateRoot();
fs::path ResolveRemovalRoot(const fs::path &);
bool SafeRelative(const std::wstring &);
void ValidateRoot(const fs::path &);
void NoLinks(const fs::path &);
bool OwnedRoot(const fs::path &);
bool CanManage(const fs::path &);
void PrepareRemoval(const fs::path &);
Record ReadRecord(const fs::path &);
std::vector<Entry> Payload();
std::vector<Entry> ParsePack(const unsigned char *, size_t);
std::vector<fs::path> FixedRoots();
ScanResult ScanAhk(const std::vector<fs::path> &, std::atomic<bool> &,
                   const Notify &);
Result RecycleSelected(const std::vector<FoundFile> &, std::atomic<bool> &,
                       const Notify &, bool shortcuts = false);
bool CanRecycleFolder(const fs::path &);
bool SafeCloudTag(DWORD);
void RemoveMatchingShortcuts(const std::vector<fs::path> &locations,
                             const std::vector<fs::path> &targets, Result &);
Result Install(const Options &, std::atomic<bool> &, const Notify &);
Result Uninstall(const Options &, bool keepData, std::atomic<bool> &,
                 const Notify &);
bool RunningFrom(const fs::path &);
void Launch(const fs::path &);
void OpenGuide();
bool FinishRemove(const fs::path &);
int SelfTest(const fs::path &, const fs::path &legacyFixture = {});
std::wstring LastErrorText(const std::wstring &prefix);
} // namespace gos
