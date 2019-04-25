#include <stdexcept>
#include <sstream>
#include <iostream>
#include <fstream>

#include <time.h>
#include <benchmark.h>

extern "C" {
#include <EverCrypt_AEAD.h>
#ifdef HAVE_VALE
#include <EverCrypt_Vale.h>
#endif
}

#ifdef HAVE_OPENSSL
#include <openssl/evp.h>
#endif

class AEADBenchmark : public Benchmark
{
  protected:
    size_t key_sz, msg_len, ad_len = 128;
    uint8_t *tag;
    uint8_t iv[16]; // 12 used; old vale likes to have 16 anyways.
    uint8_t *key;
    uint8_t *plain;
    uint8_t *cipher;
    uint8_t *ad = 0;
    std::string algorithm;

  public:
    static std::string column_headers() { return "\"Provider\", \"Algorithm\", \"Size [b]\"" + Benchmark::column_headers() + ", \"Avg Cycles/Byte\""; }

    AEADBenchmark(size_t key_sz_bits, size_t tag_len, size_t msg_len) : Benchmark()
    {
      if (key_sz_bits != 128 && key_sz_bits != 192 && key_sz_bits != 256)
        throw std::logic_error("Need key_sz in {128, 192, 256}");

      if (msg_len == 0)
        throw std::logic_error("Need msg_len > 0");

      this->key_sz = key_sz_bits/8;
      this->msg_len = msg_len;

      key = new uint8_t[key_sz];
      plain = new uint8_t[msg_len];
      cipher = new uint8_t[msg_len];
      tag = new uint8_t[tag_len];
      ad = new uint8_t[ad_len];

      randomize(ad, ad_len);
    }

    void set_name(const std::string & provider, const std::string & algorithm)
    {
      Benchmark::set_name(provider);
      this->algorithm = algorithm;
    }

    virtual ~AEADBenchmark()
    {
      delete[](ad);
      delete[](tag);
      delete[](cipher);
      delete[](plain);
      delete[](key);
    }

    virtual void bench_setup(const BenchmarkSettings & s)
    {
      randomize((char*)key, key_sz);
      randomize((char*)plain, msg_len);
    }

    virtual void report(std::ostream & rs, const BenchmarkSettings & s) const
    {
      rs << "\"" << name << "\""
        << "," << "\"" << algorithm << "\""
        << "," << msg_len;
      Benchmark::report(rs, s);
      rs << "," << (ctotal/(double)msg_len)/(double)s.samples << "\n";
    }
};

void type2name_evercrypt(AEADBenchmark & b, int type)
{
  switch (type) {
      case Spec_AEAD_AES128_GCM: b.set_name("EverCrypt", "AES128\\nGCM"); break;
      case Spec_AEAD_AES256_GCM: b.set_name("EverCrypt", "AES256\\nGCM"); break;
      case Spec_AEAD_CHACHA20_POLY1305: b.set_name("EverCrypt", "Chacha20\\nPoly1305"); break;
      case Spec_AEAD_AES128_CCM: b.set_name("EverCrypt", "AES128\\nCCM"); break;
      case Spec_AEAD_AES256_CCM: b.set_name("EverCrypt", "AES256\\nCCM"); break;
      case Spec_AEAD_AES128_CCM8: b.set_name("EverCrypt", "AES128\\nCCM8"); break;
      case Spec_AEAD_AES256_CCM8: b.set_name("EverCrypt", "AES256\\nCCM8"); break;
      default: throw new std::logic_error("Unknown AEAD algorithm");
    }
}

template<uint8_t type, size_t key_size_bits, size_t tag_len>
class EverCryptAEADEncrypt : public AEADBenchmark
{
  protected:
    EverCrypt_AEAD_state_s *state;

  public:
    EverCryptAEADEncrypt(size_t msg_len) :
      AEADBenchmark(key_size_bits, tag_len, msg_len)
      { type2name_evercrypt(*this, type); }
    virtual void bench_setup(const BenchmarkSettings & s)
    {
      AEADBenchmark::bench_setup(s);
      if (EverCrypt_AEAD_create_in(type, &state, (uint8_t*)key) != EverCrypt_Error_Success)
        throw std::logic_error("AEAD context creation failed");
    }
    virtual void bench_func()
    {
      #ifdef _DEBUG
      if (
      #endif
        EverCrypt_AEAD_encrypt(state, (uint8_t*)iv, (uint8_t*)ad, ad_len, (uint8_t*)plain, msg_len, (uint8_t*)cipher, (uint8_t*)tag)
      #ifdef _DEBUG
        != EverCrypt_Error_Success) throw std::logic_error("AEAD encryption failed")
      #endif
      ;
    }
    virtual void bench_cleanup(const BenchmarkSettings & s)
    {
      EverCrypt_AEAD_free(state);
      AEADBenchmark::bench_cleanup(s);
    }
    virtual ~EverCryptAEADEncrypt() { }
};

template<uint8_t type, size_t key_size_bits, size_t tag_len>
class EverCryptAEADDecrypt : public AEADBenchmark
{
  protected:
    EverCrypt_AEAD_state_s *state;

  public:
    EverCryptAEADDecrypt(size_t msg_len) :
      AEADBenchmark(key_size_bits, tag_len, msg_len)
      { type2name_evercrypt(*this, type); }
    virtual void bench_setup(const BenchmarkSettings & s)
    {
      AEADBenchmark::bench_setup(s);
      if (EverCrypt_AEAD_create_in(type, &state, (uint8_t*)key) != EverCrypt_Error_Success)
        throw std::logic_error("AEAD context creation failed");

      EverCrypt_AEAD_encrypt(state, (uint8_t*)iv, (uint8_t*)ad, ad_len, (uint8_t*)plain, msg_len, (uint8_t*)cipher, (uint8_t*)tag);
    }
    virtual void bench_func()
    {
      #ifdef _DEBUG
      if (
      #endif
        EverCrypt_AEAD_decrypt(state, (uint8_t*)iv, (uint8_t*)ad, ad_len, (uint8_t*)cipher, msg_len, (uint8_t*)tag, (uint8_t*)plain)
      #ifdef _DEBUG
        != EverCrypt_Error_Success) throw std::logic_error("AEAD decryption failed")
      #endif
      ;
    }
    virtual void bench_cleanup(const BenchmarkSettings & s)
    {
      EverCrypt_AEAD_free(state);
      AEADBenchmark::bench_cleanup(s);
    }
    virtual ~EverCryptAEADDecrypt() { }
};

#ifdef HAVE_VALE
template<size_t key_size_bits, size_t tag_len>
class OldValeEncrypt : public AEADBenchmark
{
  protected:
    gcm_args args;

  public:
    OldValeEncrypt(size_t msg_len) :
      AEADBenchmark(key_size_bits, tag_len, msg_len)
      {
        switch(key_size_bits) {
          case 128: set_name("Vale (old)", "AES128\\nGCM"); break;
          case 256: set_name("Vale (old)", "AES256\\nGCM"); break;
          default: throw new std::logic_error("Unknown algorithm");
        }
      }
    virtual void bench_setup(const BenchmarkSettings & s)
    {
      AEADBenchmark::bench_setup(s);
      args.plain = (uint8_t*)plain;
      args.plain_len = msg_len;
      args.aad = (uint8_t*)ad;
      args.aad_len = ad_len;
      args.iv = (uint8_t*)iv;
      args.cipher = (uint8_t*)cipher;
      args.tag = (uint8_t*)tag;

      args.expanded_key = new uint8_t[15 * (128/8)];
      switch(key_size_bits) {
        case 128: old_aes128_key_expansion((uint8_t*)key, args.expanded_key); break;
        case 256: old_aes256_key_expansion((uint8_t*)key, args.expanded_key); break;
      }
    }
    virtual void bench_func()
    {
      switch(key_size_bits) {
      case 128: old_gcm128_encrypt(&args);
      case 256: old_gcm256_encrypt(&args);
      }
    }
    virtual void bench_cleanup(const BenchmarkSettings & s)
    {
      delete[](args.expanded_key);
      AEADBenchmark::bench_cleanup(s);
    }
    virtual ~OldValeEncrypt() {}
};

template<size_t key_size_bits, size_t tag_len>
class OldValeDecrypt : public AEADBenchmark
{
  protected:
    gcm_args args;

  public:
    OldValeDecrypt(size_t msg_len) :
      AEADBenchmark(key_size_bits, tag_len, msg_len)
      {
        switch(key_size_bits) {
          case 128: set_name("Vale (old)", "AES128\\nGCM"); break;
          case 256: set_name("Vale (old)", "AES256\\nGCM"); break;
          default: throw new std::logic_error("Unknown algorithm");
        }
      }
    virtual void bench_setup(const BenchmarkSettings & s)
    {
      AEADBenchmark::bench_setup(s);
      args.plain = (uint8_t*)plain;
      args.plain_len = msg_len;
      args.aad = (uint8_t*)ad;
      args.aad_len = ad_len;
      args.iv = (uint8_t*)iv;
      args.cipher = (uint8_t*)cipher;
      args.tag = (uint8_t*)tag;
      args.expanded_key = new uint8_t[15 * (128/8)];
      switch(key_size_bits) {
        case 128: old_aes128_key_expansion((uint8_t*)key, args.expanded_key); old_gcm128_encrypt(&args); break;
        case 256: old_aes256_key_expansion((uint8_t*)key, args.expanded_key); old_gcm256_encrypt(&args); break;
      }
      std::swap(args.cipher, args.plain);
    }
    virtual void bench_func()
    {
      #ifdef _DEBUG
      switch(key_size_bits) {
      case 128: if (old_gcm128_decrypt(&args) != 0) throw std::logic_error("Vale decryption failed"); break;
      case 256: if (old_gcm256_decrypt(&args) != 0) throw std::logic_error("Vale decryption failed"); break;
      }
      #else
      switch(key_size_bits) {
      case 128: old_gcm128_decrypt(&args); break;
      case 256: old_gcm256_decrypt(&args); break;
      }
      #endif
    }
    virtual void bench_cleanup(const BenchmarkSettings & s)
    {
      delete[](args.expanded_key);
      AEADBenchmark::bench_cleanup(s);
    }
    virtual ~OldValeDecrypt() {}
};
#endif

#ifdef HAVE_OPENSSL
// See https://github.com/openssl/openssl/blob/master/demos/evp/aesgcm.c

static void type2name(AEADBenchmark & b, int type, size_t key_size_bits, size_t tag_len)
{
  switch (type) {
    case 0:
      switch(key_size_bits) {
        case 128: b.set_name("OpenSSL", "AES128\\nGCM"); break;
        case 256: b.set_name("OpenSSL", "AES256\\nGCM"); break;
        default: throw new std::logic_error("Unknown algorithm");
      }
      break;
    case 1: b.set_name("OpenSSL", "Chacha20\\nPoly1305"); break;
    default: throw new std::logic_error("Unknown algorithm");
  }
}

template<int type, size_t key_size_bits, size_t tag_len>
class OpenSSLEncrypt : public AEADBenchmark
{
  protected:
  static const EVP_CIPHER *evp_cipher;
    EVP_CIPHER_CTX *ctx;
    int outlen;

  public:
    OpenSSLEncrypt(size_t msg_len) :
      AEADBenchmark(key_size_bits, tag_len, msg_len)
      {
        type2name(*this, type, key_size_bits, tag_len);
        ctx = EVP_CIPHER_CTX_new();
      }
    virtual void bench_setup(const BenchmarkSettings & s)
    {
      AEADBenchmark::bench_setup(s);
      EVP_EncryptInit_ex(ctx, evp_cipher, NULL, NULL, NULL);
      if ((EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_AEAD_SET_IVLEN, 12, NULL) <= 0) ||
          (EVP_EncryptInit_ex(ctx, NULL, NULL, key, iv)  <= 0))
          throw std::logic_error("OpenSSL encryption initialization failed");
    }
    virtual void bench_func()
    {
      #ifdef _DEBUG
      if ((ad_len > 0 && EVP_EncryptUpdate(ctx, NULL, &outlen, ad, ad_len) <= 0) ||
          (EVP_EncryptUpdate(ctx, cipher, &outlen, plain, msg_len) <= 0) ||
          (EVP_EncryptFinal_ex(ctx, cipher, &outlen) <= 0))
          throw std::logic_error("OpenSSL encryption failed E");
      #else
      if (ad_len > 0) EVP_EncryptUpdate(ctx, NULL, &outlen, ad, ad_len);
      EVP_EncryptUpdate(ctx, cipher, &outlen, plain, msg_len);
      EVP_EncryptFinal_ex(ctx, cipher, &outlen);
      #endif
    }
    virtual ~OpenSSLEncrypt() { EVP_CIPHER_CTX_free(ctx); }
};

template<> const EVP_CIPHER *OpenSSLEncrypt<0, 128, 16>::evp_cipher = EVP_aes_128_gcm();
template<> const EVP_CIPHER *OpenSSLEncrypt<0, 256, 16>::evp_cipher = EVP_aes_256_gcm();
template<> const EVP_CIPHER *OpenSSLEncrypt<1, 256, 16>::evp_cipher = EVP_chacha20_poly1305();

template<size_t type, size_t key_size_bits, size_t tag_len>
class OpenSSLDecrypt : public AEADBenchmark
{
  protected:
    static const EVP_CIPHER *evp_cipher;
    EVP_CIPHER_CTX *ctx;
    int outlen;

  public:
    OpenSSLDecrypt(size_t msg_len) :
      AEADBenchmark(key_size_bits, tag_len, msg_len)
      {
        type2name(*this, type, key_size_bits, tag_len);
        ctx = EVP_CIPHER_CTX_new();
      }
    virtual void bench_setup(const BenchmarkSettings & s)
    {
      AEADBenchmark::bench_setup(s);
      EVP_DecryptInit_ex(ctx, evp_cipher, NULL, NULL, NULL);
      if ((EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_AEAD_SET_IVLEN, 12, NULL) <= 0) ||
          (EVP_EncryptInit_ex(ctx, NULL, NULL, key, iv) <= 0) ||
          (ad_len > 0 && EVP_EncryptUpdate(ctx, NULL, &outlen, ad, ad_len) <= 0) ||
          (EVP_EncryptUpdate(ctx, cipher, &outlen, plain, msg_len) <= 0) ||
          (EVP_EncryptFinal_ex(ctx, cipher, &outlen) <= 0) ||
          (EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_AEAD_GET_TAG, 16, tag) <= 0) ||
          (EVP_DecryptInit_ex(ctx, NULL, NULL, key, iv) <= 0))
          throw std::logic_error("OpenSSL decryption initialization failed");
    }
    virtual void bench_func()
    {
      #ifdef _DEBUG
      if (((ad_len > 0) && EVP_DecryptUpdate(ctx, NULL, &outlen, ad, ad_len) <= 0) ||
          EVP_DecryptUpdate(ctx, plain, &outlen, cipher, msg_len)  <= 0 ||
          EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_AEAD_SET_TAG, tag_len, (void *)tag)  <= 0 ||
          EVP_DecryptFinal_ex(ctx, plain, &outlen) <= 0)
          throw std::logic_error("OpenSSL tag validation failed")
      #else
      if (ad_len > 0) EVP_DecryptUpdate(ctx, NULL, &outlen, ad, ad_len);
      EVP_DecryptUpdate(ctx, plain, &outlen, cipher, msg_len);
      EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_AEAD_SET_TAG, tag_len, (void *)tag);
      EVP_DecryptFinal_ex(ctx, plain, &outlen);
      #endif
      ;
    }
    virtual ~OpenSSLDecrypt() { EVP_CIPHER_CTX_free(ctx); }
};

template<> const EVP_CIPHER *OpenSSLDecrypt<0, 128, 16>::evp_cipher = EVP_aes_128_gcm();
template<> const EVP_CIPHER *OpenSSLDecrypt<0, 256, 16>::evp_cipher = EVP_aes_256_gcm();
template<> const EVP_CIPHER *OpenSSLDecrypt<1, 256, 16>::evp_cipher = EVP_chacha20_poly1305();
#endif

void bench_aead_encrypt(const BenchmarkSettings & s)
{
  size_t data_sizes[] = { 1024, 2048, 4096, 8192, 16384, 32768, 65536 };

  Benchmark::plot_spec_t plot_specs_cycles;
  Benchmark::plot_spec_t plot_specs_bytes;

  for (size_t ds: data_sizes)
  {
    std::stringstream dsstr;
    dsstr << ds;

    std::stringstream data_filename;
    data_filename << "bench_aead_" << ds << ".csv";

    if (plot_specs_cycles.empty())
    {
      plot_specs_cycles.push_back(std::make_pair(data_filename.str(), "using 'Avg':xticlabels(strcol('Algorithm')) title '" + dsstr.str() + " b'"));
      plot_specs_bytes.push_back(std::make_pair(data_filename.str(), "using 'Avg Cycles/Byte':xticlabels(strcol('Algorithm')) title '" + dsstr.str() + " b'"));
    }
    else
    {
      plot_specs_cycles.push_back(std::make_pair(data_filename.str(), "using 'Avg' title '" + dsstr.str() + " b'"));
      plot_specs_bytes.push_back(std::make_pair(data_filename.str(), "using 'Avg Cycles/Byte' title '" + dsstr.str() + " b'"));
    }

    std::list<Benchmark*> todo = {
      new EverCryptAEADEncrypt<Spec_AEAD_AES128_GCM, 128, 16>(ds),
      new EverCryptAEADEncrypt<Spec_AEAD_AES256_GCM, 256, 16>(ds),
      new EverCryptAEADEncrypt<Spec_AEAD_CHACHA20_POLY1305, 256, 16>(ds),
      // new EverCryptAEADEncrypt<Spec_AEAD_AES128_CCM, 128, 16>(ds), // unsupported?
      // new EverCryptAEADEncrypt<Spec_AEAD_AES256_CCM, 256, 16>(ds), // unsupported?
      // new EverCryptAEADEncrypt<Spec_AEAD_AES128_CCM8, 128, 8>(ds), // unsupported?
      // new EverCryptAEADEncrypt<Spec_AEAD_AES256_CCM8, 256, 8>(ds), // unsupported?

      // #ifdef HAVE_VALE
      // new OldValeEncrypt<128, 16>(ds),
      // new OldValeEncrypt<256, 16>(ds),
      // #endif

      #ifdef HAVE_OPENSSL
      new OpenSSLEncrypt<0, 128, 16>(ds),
      new OpenSSLEncrypt<0, 256, 16>(ds),
      new OpenSSLEncrypt<1, 256, 16>(ds),
      #endif
      };

      Benchmark::run_batch(s, AEADBenchmark::column_headers(), data_filename.str(), todo);

      std::string evercrypt_only = "< grep -e \"^\\\"EverCrypt\" -e \"^\\\"Provider\" " + data_filename.str();
      std::string openssl_only = "< grep -e \"^\\\"OpenSSL\" -e \"^\\\"Provider\" " + data_filename.str();

      Benchmark::plot_spec_t plot_specs_ds_cycles = {
        std::make_pair(evercrypt_only, "using 'Avg':xticlabels(strcol('Algorithm')) title 'EverCrypt'"),
        std::make_pair("", "using 0:'Avg':xticlabels(strcol('Algorithm')):(sprintf(\"%0.0f\", column('Avg'))) with labels font \"Courier,8\" offset char -2,.5 center notitle"),
        std::make_pair(openssl_only, "using 'Avg' title 'OpenSSL'"),
        std::make_pair("", "using 0:'Avg':xticlabels(strcol('Algorithm')):(sprintf(\"%0.0f\", column('Avg'))) with labels font \"Courier,8\" offset char +2,.5 center notitle"),
       };

      std::stringstream extras;
      extras << "set boxwidth 0.8\n";
      extras << "set key top left inside\n";
      extras << "set style histogram clustered gap 3 title\n";
      extras << "set style data histograms\n";
      extras << "set bmargin 5\n";
      extras << "set xrange [-0.5:2.5]\n";

      Benchmark::make_plot(s,
                      "svg",
                      "AEAD Encryption performance (message length " + dsstr.str() + " bytes)",
                      "",
                      "Avg. performance [CPU cycles/encryption]",
                      plot_specs_ds_cycles,
                      "bench_aead_all_encrypt_" + dsstr.str() + "_cycles.svg",
                      extras.str());

      Benchmark::plot_spec_t plot_specs_ds_bytes = {
        std::make_pair(evercrypt_only, "using 'Avg Cycles/Byte':xticlabels(strcol('Algorithm')) title 'EverCrypt'"),
        std::make_pair("", "using 0:'Avg Cycles/Byte':xticlabels(strcol('Algorithm')):(sprintf(\"%0.2f\", column('Avg Cycles/Byte'))) with labels font \"Courier,8\" offset char -2,.5 center notitle"),
        std::make_pair(openssl_only, "using 'Avg Cycles/Byte' title 'OpenSSL'"),
        std::make_pair("", "using 0:'Avg Cycles/Byte':xticlabels(strcol('Algorithm')):(sprintf(\"%0.2f\", column('Avg Cycles/Byte'))) with labels font \"Courier,8\" offset char +2,.5 center notitle"),
      };

      Benchmark::make_plot(s,
                      "svg",
                      "AEAD Encryption performance (message length " + dsstr.str() + " bytes)",
                      "",
                      "Avg. performance [CPU cycles/byte]",
                      plot_specs_ds_bytes,
                      "bench_aead_all_encrypt_" + dsstr.str() + "_bytes.svg",
                      extras.str());

      Benchmark::plot_spec_t plot_specs_ds_candlesticks = {
        std::make_pair(evercrypt_only, "using 0:'Q25':'Min':'Max':'Q75':xticlabels(strcol('Algorithm')) title 'EverCrypt' with candlesticks whiskerbars .25"),
        std::make_pair(openssl_only, "using 0:'Q25':'Min':'Max':'Q75':xticlabels(strcol('Algorithm')) title 'OpenSSL' with candlesticks whiskerbars .25")
      };

      extras << "set boxwidth .25\n";
      extras << "set style fill empty\n";

      Benchmark::make_plot(s,
                      "svg",
                      "AEAD Encryption performance (message length " + dsstr.str() + " bytes)",
                      "",
                      "Avg. performance [CPU cycles/encryption]",
                      plot_specs_ds_candlesticks,
                      "bench_aead_all_encrypt_" + dsstr.str() + "_candlesticks.svg",
                      extras.str());
  }

  std::stringstream extras;
  extras << "set boxwidth 0.8\n";
  extras << "set key top left inside\n";
  extras << "set style histogram clustered gap 3 title\n";
  extras << "set style data histograms\n";
  extras << "set bmargin 5\n";

  Benchmark::make_plot(s,
                       "svg",
                       "AEAD Encryption Performance",
                       "",
                       "Avg. performance [CPU cycles/encryption]",
                       plot_specs_cycles,
                       "bench_aead_all_encrypt_cycles.svg",
                       extras.str());

  Benchmark::make_plot(s,
                       "svg",
                       "AEAD Encryption Performance",
                       "",
                       "Avg. performance [CPU cycles/byte]",
                       plot_specs_bytes,
                       "bench_aead_all_encrypt_bytes.svg",
                       extras.str());
}

void bench_aead_decrypt(const BenchmarkSettings & s)
{
  size_t data_sizes[] = { 1024, 2048, 4096, 8192, 16384, 32768, 65536 };

  Benchmark::plot_spec_t plot_specs_cycles;
  Benchmark::plot_spec_t plot_specs_bytes;

  for (size_t ds: data_sizes)
  {
    std::stringstream dsstr;
    dsstr << ds;

    std::stringstream data_filename;
    data_filename << "bench_aead_" << ds << ".csv";

    if (plot_specs_cycles.empty())
    {
      plot_specs_cycles.push_back(std::make_pair(data_filename.str(), "using 'Avg':xticlabels(strcol('Algorithm')) title '" + dsstr.str() + " b'"));
      plot_specs_bytes.push_back(std::make_pair(data_filename.str(), "using 'Avg Cycles/Byte':xticlabels(strcol('Algorithm')) title '" + dsstr.str() + " b'"));
    }
    else
    {
      plot_specs_cycles.push_back(std::make_pair(data_filename.str(), "using 'Avg' title '" + dsstr.str() + " b'"));
      plot_specs_bytes.push_back(std::make_pair(data_filename.str(), "using 'Avg Cycles/Byte' title '" + dsstr.str() + " b'"));
    }

    std::list<Benchmark*> todo = {
      new EverCryptAEADDecrypt<Spec_AEAD_AES128_GCM, 128, 16>(ds),
      new EverCryptAEADDecrypt<Spec_AEAD_AES256_GCM, 256, 16>(ds),
      new EverCryptAEADDecrypt<Spec_AEAD_CHACHA20_POLY1305, 256, 16>(ds),
      // new EverCryptAEADDecrypt<Spec_AEAD_AES128_CCM, 128, 16>(ds), // unsupported?
      // new EverCryptAEADDecrypt<Spec_AEAD_AES256_CCM, 256, 16>(ds), // unsupported?
      // new EverCryptAEADDecrypt<Spec_AEAD_AES128_CCM8, 128, 8>(ds), // unsupported?
      // new EverCryptAEADDecrypt<Spec_AEAD_AES256_CCM8, 256, 8>(ds), // unsupported?

      // #ifdef HAVE_VALE
      // new OldValeDecrypt<128, 16>(ds),
      // new OldValeDecrypt<256, 16>(ds),
      // #endif

      #ifdef HAVE_OPENSSL
      new OpenSSLDecrypt<0, 128, 16>(ds),
      new OpenSSLDecrypt<0, 256, 16>(ds),
      new OpenSSLDecrypt<1, 256, 16>(ds),
      #endif
      };

      Benchmark::run_batch(s, AEADBenchmark::column_headers(), data_filename.str(), todo);

      std::string evercrypt_only = "< grep -e \"^\\\"EverCrypt\" -e \"^\\\"Provider\" " + data_filename.str();
      std::string openssl_only = "< grep -e \"^\\\"OpenSSL\" -e \"^\\\"Provider\" " + data_filename.str();

      Benchmark::plot_spec_t plot_specs_ds_cycles = {
        std::make_pair(evercrypt_only, "using 'Avg':xticlabels(strcol('Algorithm')) title 'EverCrypt'"),
        std::make_pair("", "using 0:'Avg':xticlabels(strcol('Algorithm')):(sprintf(\"%0.0f\", column('Avg'))) with labels font \"Courier,8\" offset char -2,.5 center notitle"),
        std::make_pair(openssl_only, "using 'Avg' title 'OpenSSL'"),
        std::make_pair("", "using 0:'Avg':xticlabels(strcol('Algorithm')):(sprintf(\"%0.0f\", column('Avg'))) with labels font \"Courier,8\" offset char +2,.5 center notitle"),
       };

      std::stringstream extras;
      extras << "set boxwidth 0.8\n";
      extras << "set key top left inside\n";
      extras << "set style histogram clustered gap 3 title\n";
      extras << "set style data histograms\n";
      extras << "set bmargin 5\n";
      extras << "set xrange [-0.5:2.5]\n";

      Benchmark::make_plot(s,
                      "svg",
                      "AEAD Decryption performance (message length " + dsstr.str() + " bytes)",
                      "",
                      "Avg. performance [CPU cycles/decryption]",
                      plot_specs_ds_cycles,
                      "bench_aead_all_decrypt_" + dsstr.str() + "_cycles.svg",
                      extras.str());

      Benchmark::plot_spec_t plot_specs_ds_bytes = {
        std::make_pair(evercrypt_only, "using 'Avg Cycles/Byte':xticlabels(strcol('Algorithm')) title 'EverCrypt'"),
        std::make_pair("", "using 0:'Avg Cycles/Byte':xticlabels(strcol('Algorithm')):(sprintf(\"%0.2f\", column('Avg Cycles/Byte'))) with labels font \"Courier,8\" offset char -2,.5 center notitle"),
        std::make_pair(openssl_only, "using 'Avg Cycles/Byte' title 'OpenSSL'"),
        std::make_pair("", "using 0:'Avg Cycles/Byte':xticlabels(strcol('Algorithm')):(sprintf(\"%0.2f\", column('Avg Cycles/Byte'))) with labels font \"Courier,8\" offset char +2,.5 center notitle"),
      };

      Benchmark::make_plot(s,
                      "svg",
                      "AEAD Decryption performance (message length " + dsstr.str() + " bytes)",
                      "",
                      "Avg. performance [CPU cycles/byte]",
                      plot_specs_ds_bytes,
                      "bench_aead_all_decrypt_" + dsstr.str() + "_bytes.svg",
                      extras.str());

      Benchmark::plot_spec_t plot_specs_ds_candlesticks = {
        std::make_pair(evercrypt_only, "using 0:'Q25':'Min':'Max':'Q75':xticlabels(strcol('Algorithm')) title 'EverCrypt' with candlesticks whiskerbars .25"),
        std::make_pair(openssl_only, "using 0:'Q25':'Min':'Max':'Q75':xticlabels(strcol('Algorithm')) title 'OpenSSL' with candlesticks whiskerbars .25")
      };

      extras << "set boxwidth .25\n";
      extras << "set style fill empty\n";

      Benchmark::make_plot(s,
                      "svg",
                      "AEAD Decryption performance (message length " + dsstr.str() + " bytes)",
                      "",
                      "Avg. performance [CPU cycles/decryption]",
                      plot_specs_ds_candlesticks,
                      "bench_aead_all_decrypt_" + dsstr.str() + "_candlesticks.svg",
                      extras.str());
  }

  std::stringstream extras;
  extras << "set boxwidth 0.8\n";
  extras << "set key top left inside\n";
  extras << "set style histogram clustered gap 3 title\n";
  extras << "set style data histograms\n";
  extras << "set bmargin 5\n";

  Benchmark::make_plot(s,
                       "svg",
                       "AEAD Decryption Performance",
                       "",
                       "Avg. performance [CPU cycles/decryption]",
                       plot_specs_cycles,
                       "bench_aead_all_decrypt_cycles.svg",
                       extras.str());

  Benchmark::make_plot(s,
                       "svg",
                       "AEAD Decryption Performance",
                       "",
                       "Avg. performance [CPU cycles/byte]",
                       plot_specs_bytes,
                       "bench_aead_all_decrypt_bytes.svg",
                       extras.str());
}

void bench_aead(const BenchmarkSettings & s)
{
  bench_aead_encrypt(s);
  bench_aead_decrypt(s);
}