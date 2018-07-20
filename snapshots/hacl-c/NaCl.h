/* MIT License
 *
 * Copyright (c) 2016-2018 INRIA and Microsoft Corporation
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */



#ifndef __NaCl_H
#define __NaCl_H


#include "kremlib.h"

extern FStar_UInt128_uint128 FStar_Int_Cast_Full_uint64_to_uint128(uint64_t x0);

uint32_t
NaCl_crypto_secretbox_detached(
  uint8_t *c,
  uint8_t *mac,
  uint8_t *m,
  uint64_t mlen,
  uint8_t *n1,
  uint8_t *k1
);

uint32_t
NaCl_crypto_secretbox_open_detached(
  uint8_t *m,
  uint8_t *c,
  uint8_t *mac,
  uint64_t clen,
  uint8_t *n1,
  uint8_t *k1
);

uint32_t
NaCl_crypto_secretbox_easy(uint8_t *c, uint8_t *m, uint64_t mlen, uint8_t *n1, uint8_t *k1);

uint32_t
NaCl_crypto_secretbox_open_easy(
  uint8_t *m,
  uint8_t *c,
  uint64_t clen,
  uint8_t *n1,
  uint8_t *k1
);

uint32_t NaCl_crypto_box_beforenm(uint8_t *k1, uint8_t *pk, uint8_t *sk);

uint32_t
NaCl_crypto_box_detached_afternm(
  uint8_t *c,
  uint8_t *mac,
  uint8_t *m,
  uint64_t mlen,
  uint8_t *n1,
  uint8_t *k1
);

uint32_t
NaCl_crypto_box_detached(
  uint8_t *c,
  uint8_t *mac,
  uint8_t *m,
  uint64_t mlen,
  uint8_t *n1,
  uint8_t *pk,
  uint8_t *sk
);

uint32_t
NaCl_crypto_box_open_detached(
  uint8_t *m,
  uint8_t *c,
  uint8_t *mac,
  uint64_t mlen,
  uint8_t *n1,
  uint8_t *pk,
  uint8_t *sk
);

uint32_t
NaCl_crypto_box_easy_afternm(uint8_t *c, uint8_t *m, uint64_t mlen, uint8_t *n1, uint8_t *k1);

uint32_t
NaCl_crypto_box_easy(
  uint8_t *c,
  uint8_t *m,
  uint64_t mlen,
  uint8_t *n1,
  uint8_t *pk,
  uint8_t *sk
);

uint32_t
NaCl_crypto_box_open_easy(
  uint8_t *m,
  uint8_t *c,
  uint64_t mlen,
  uint8_t *n1,
  uint8_t *pk,
  uint8_t *sk
);

uint32_t
NaCl_crypto_box_open_detached_afternm(
  uint8_t *m,
  uint8_t *c,
  uint8_t *mac,
  uint64_t mlen,
  uint8_t *n1,
  uint8_t *k1
);

uint32_t
NaCl_crypto_box_open_easy_afternm(
  uint8_t *m,
  uint8_t *c,
  uint64_t mlen,
  uint8_t *n1,
  uint8_t *k1
);

#define __NaCl_H_DEFINED
#endif
