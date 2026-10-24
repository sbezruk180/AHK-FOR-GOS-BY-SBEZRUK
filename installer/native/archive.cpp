#include "core.hpp"
#include <algorithm>
#include <cctype>
#include <cstdint>
namespace gos {
// Read the central directory only. Never extract or decompress an archive.
bool ZipContainsAhk(const fs::path &path) {
  HANDLE file =
      CreateFileW(path.c_str(), GENERIC_READ,
                  FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                  nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
  if (file == INVALID_HANDLE_VALUE)
    return false;
  struct Close {
    HANDLE file;
    ~Close() { CloseHandle(file); }
  } close{file};
  LARGE_INTEGER size{};
  if (!GetFileSizeEx(file, &size) || size.QuadPart < 22)
    return false;
  auto read = [&](uint64_t offset, size_t count,
                  std::vector<unsigned char> &bytes) {
    if (offset > (uint64_t)size.QuadPart ||
        count > (uint64_t)size.QuadPart - offset)
      return false;
    LARGE_INTEGER at{};
    at.QuadPart = offset;
    if (!SetFilePointerEx(file, at, nullptr, FILE_BEGIN))
      return false;
    bytes.resize(count);
    DWORD got = 0;
    return ReadFile(file, bytes.data(), (DWORD)count, &got, nullptr) &&
           got == count;
  };
  auto n16 = [](const unsigned char *p) {
    return (unsigned)p[0] | ((unsigned)p[1] << 8);
  };
  auto n32 = [&](const unsigned char *p) {
    return (uint64_t)n16(p) | ((uint64_t)n16(p + 2) << 16);
  };
  auto n64 = [&](const unsigned char *p) {
    return n32(p) | (n32(p + 4) << 32);
  };
  std::vector<unsigned char> tail;
  size_t length = (size_t)std::min<uint64_t>(size.QuadPart, 65557);
  if (!read(size.QuadPart - length, length, tail))
    return false;
  for (size_t i = length - 22;; --i) {
    if (n32(tail.data() + i) == 0x06054b50 &&
        i + 22 + n16(tail.data() + i + 20) == length) {
      auto p = tail.data() + i;
      if (n16(p + 4) || n16(p + 6) || n16(p + 8) != n16(p + 10))
        return false;
      uint64_t count = n16(p + 10), bytes = n32(p + 12), offset = n32(p + 16);
      if (count == 65535 || bytes == 0xffffffff || offset == 0xffffffff) {
        auto end = (uint64_t)size.QuadPart - length + i;
        std::vector<unsigned char> locator, zip64;
        if (end < 20 || !read(end - 20, 20, locator) ||
            n32(locator.data()) != 0x07064b50 || n32(locator.data() + 4) ||
            n32(locator.data() + 16) != 1)
          return false;
        if (!read(n64(locator.data() + 8), 56, zip64) ||
            n32(zip64.data()) != 0x06064b50 || n32(zip64.data() + 16) ||
            n32(zip64.data() + 20) ||
            n64(zip64.data() + 24) != n64(zip64.data() + 32))
          return false;
        count = n64(zip64.data() + 32);
        bytes = n64(zip64.data() + 40);
        offset = n64(zip64.data() + 48);
      }
      if (!count || count > 200000 || bytes > 32 * 1024 * 1024)
        return false;
      std::vector<unsigned char> central;
      if (!read(offset, (size_t)bytes, central))
        return false;
      size_t at = 0;
      bool found = false;
      for (uint64_t item = 0; item < count; ++item) {
        if (at > central.size() || central.size() - at < 46)
          return false;
        auto entry = central.data() + at;
        if (n32(entry) != 0x02014b50)
          return false;
        size_t name = n16(entry + 28),
               record = 46 + name + n16(entry + 30) + n16(entry + 32);
        if (record > central.size() - at || n16(entry + 34))
          return false;
        std::string filename((char *)entry + 46, name);
        std::transform(filename.begin(), filename.end(), filename.begin(),
                       [](unsigned char c) { return (char)std::tolower(c); });
        if (filename.size() >= 4 && filename.find('\0') == filename.npos &&
            filename.compare(filename.size() - 4, 4, ".ahk") == 0)
          found = true;
        at += record;
      }
      return at == central.size() && found;
    }
    if (!i)
      break;
  }
  return false;
}
} // namespace gos
