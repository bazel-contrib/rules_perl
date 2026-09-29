// Checks the OpenSSL the openssl module built: its version string names the
// version the module pins, and it computes a known SHA-256 digest.
#include <openssl/crypto.h>
#include <openssl/evp.h>
#include <openssl/opensslv.h>

#include <cstdio>
#include <cstring>

int main() {
  const char* version = OpenSSL_version(OPENSSL_VERSION);
  std::printf("%s\n", version);
  if (std::strstr(version, OPENSSL_VERSION_STR) == nullptr) {
    std::fprintf(stderr, "version string does not contain %s\n", OPENSSL_VERSION_STR);
    return 1;
  }

  // SHA-256("abc"), from FIPS 180-2.
  static const unsigned char want[32] = {
      0xba, 0x78, 0x16, 0xbf, 0x8f, 0x01, 0xcf, 0xea, 0x41, 0x41, 0x40,
      0xde, 0x5d, 0xae, 0x22, 0x23, 0xb0, 0x03, 0x61, 0xa3, 0x96, 0x17,
      0x7a, 0x9c, 0xb4, 0x10, 0xff, 0x61, 0xf2, 0x00, 0x15, 0xad};
  unsigned char got[EVP_MAX_MD_SIZE];
  unsigned int len = 0;
  if (!EVP_Digest("abc", 3, got, &len, EVP_sha256(), nullptr)) {
    std::fprintf(stderr, "EVP_Digest failed\n");
    return 1;
  }
  if (len != sizeof(want) || std::memcmp(got, want, sizeof(want)) != 0) {
    std::fprintf(stderr, "wrong SHA-256 of \"abc\"\n");
    return 1;
  }
  return 0;
}
