/*
 * haval-256 kernel implementation.
 *
 * ==========================(LICENSE BEGIN)============================
 *
 * Copyright (c) 2014 djm34
 *               2016 tpruvot
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 * IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
 * CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
 * TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 * SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 *
 * ===========================(LICENSE END)=============================
 */

#define TPB 512

#include "cuda_helper.h"
#include "cuda_vectors.h"

#define F1(x6, x5, x4, x3, x2, x1, x0) \
	(((x1) & ((x0) ^ (x4))) ^ ((x2) & (x5)) ^ ((x3) & (x6)) ^ (x0))

#define F2(x6, x5, x4, x3, x2, x1, x0) \
	(((x2) & (((x1) & ~(x3)) ^ ((x4) & (x5)) ^ (x6) ^ (x0))) ^ ((x4) & ((x1) ^ (x5))) ^ ((x3 & (x5)) ^ (x0)))

#define F3(x6, x5, x4, x3, x2, x1, x0) \
	(((x3) & (((x1) & (x2)) ^ (x6) ^ (x0))) ^ ((x1) & (x4)) ^ ((x2) & (x5)) ^ (x0))

#define F4(x6, x5, x4, x3, x2, x1, x0) \
	(((x3) & (((x1) & (x2)) ^ ((x4) | (x6)) ^ (x5))) ^ ((x4) & ((~(x2) & (x5)) ^ (x1) ^ (x6) ^ (x0))) ^ ((x2) & (x6)) ^ (x0))

#define F5(x6, x5, x4, x3, x2, x1, x0) \
	(((x0) & ~(((x1) & (x2) & (x3)) ^ (x5))) ^ ((x1) & (x4)) ^ ((x2) & (x5)) ^ ((x3) & (x6)))

#define FP5_1(x6, x5, x4, x3, x2, x1, x0) \
	F1(x3, x4, x1, x0, x5, x2, x6)
#define FP5_2(x6, x5, x4, x3, x2, x1, x0) \
	F2(x6, x2, x1, x0, x3, x4, x5)
#define FP5_3(x6, x5, x4, x3, x2, x1, x0) \
	F3(x2, x6, x0, x4, x3, x1, x5)
#define FP5_4(x6, x5, x4, x3, x2, x1, x0) \
	F4(x1, x5, x3, x2, x0, x4, x6)
#define FP5_5(x6, x5, x4, x3, x2, x1, x0) \
	F5(x2, x5, x0, x6, x4, x3, x1)

#define STEP(n, p, x7, x6, x5, x4, x3, x2, x1, x0, w, c) { \
	uint32_t t = FP ## n ## _ ## p(x6, x5, x4, x3, x2, x1, x0); \
	(x7) = (uint32_t)(ROTR32(t, 7) + ROTR32((x7), 11) + (w) + (c)); \
}

#define PASS1(n, in) { \
	STEP(n, 1, s7, s6, s5, s4, s3, s2, s1, s0, in[ 0], 0U); \
	STEP(n, 1, s6, s5, s4, s3, s2, s1, s0, s7, in[ 1], 0U); \
	STEP(n, 1, s5, s4, s3, s2, s1, s0, s7, s6, in[ 2], 0U); \
	STEP(n, 1, s4, s3, s2, s1, s0, s7, s6, s5, in[ 3], 0U); \
	STEP(n, 1, s3, s2, s1, s0, s7, s6, s5, s4, in[ 4], 0U); \
	STEP(n, 1, s2, s1, s0, s7, s6, s5, s4, s3, in[ 5], 0U); \
	STEP(n, 1, s1, s0, s7, s6, s5, s4, s3, s2, in[ 6], 0U); \
	STEP(n, 1, s0, s7, s6, s5, s4, s3, s2, s1, in[ 7], 0U); \
 \
	STEP(n, 1, s7, s6, s5, s4, s3, s2, s1, s0, in[ 8], 0U); \
	STEP(n, 1, s6, s5, s4, s3, s2, s1, s0, s7, in[ 9], 0U); \
	STEP(n, 1, s5, s4, s3, s2, s1, s0, s7, s6, in[10], 0U); \
	STEP(n, 1, s4, s3, s2, s1, s0, s7, s6, s5, in[11], 0U); \
	STEP(n, 1, s3, s2, s1, s0, s7, s6, s5, s4, in[12], 0U); \
	STEP(n, 1, s2, s1, s0, s7, s6, s5, s4, s3, in[13], 0U); \
	STEP(n, 1, s1, s0, s7, s6, s5, s4, s3, s2, in[14], 0U); \
	STEP(n, 1, s0, s7, s6, s5, s4, s3, s2, s1, in[15], 0U); \
 \
	STEP(n, 1, s7, s6, s5, s4, s3, s2, s1, s0, in[16], 0U); \
	STEP(n, 1, s6, s5, s4, s3, s2, s1, s0, s7, in[17], 0U); \
	STEP(n, 1, s5, s4, s3, s2, s1, s0, s7, s6, in[18], 0U); \
	STEP(n, 1, s4, s3, s2, s1, s0, s7, s6, s5, in[19], 0U); \
	STEP(n, 1, s3, s2, s1, s0, s7, s6, s5, s4, in[20], 0U); \
	STEP(n, 1, s2, s1, s0, s7, s6, s5, s4, s3, in[21], 0U); \
	STEP(n, 1, s1, s0, s7, s6, s5, s4, s3, s2, in[22], 0U); \
	STEP(n, 1, s0, s7, s6, s5, s4, s3, s2, s1, in[23], 0U); \
 \
	STEP(n, 1, s7, s6, s5, s4, s3, s2, s1, s0, in[24], 0U); \
	STEP(n, 1, s6, s5, s4, s3, s2, s1, s0, s7, in[25], 0U); \
	STEP(n, 1, s5, s4, s3, s2, s1, s0, s7, s6, in[26], 0U); \
	STEP(n, 1, s4, s3, s2, s1, s0, s7, s6, s5, in[27], 0U); \
	STEP(n, 1, s3, s2, s1, s0, s7, s6, s5, s4, in[28], 0U); \
	STEP(n, 1, s2, s1, s0, s7, s6, s5, s4, s3, in[29], 0U); \
	STEP(n, 1, s1, s0, s7, s6, s5, s4, s3, s2, in[30], 0U); \
	STEP(n, 1, s0, s7, s6, s5, s4, s3, s2, s1, in[31], 0U); \
}

#define PASS2(n, in) { \
	STEP(n, 2, s7, s6, s5, s4, s3, s2, s1, s0, in[ 5], 0x452821E6); \
	STEP(n, 2, s6, s5, s4, s3, s2, s1, s0, s7, in[14], 0x38D01377); \
	STEP(n, 2, s5, s4, s3, s2, s1, s0, s7, s6, in[26], 0xBE5466CF); \
	STEP(n, 2, s4, s3, s2, s1, s0, s7, s6, s5, in[18], 0x34E90C6C); \
	STEP(n, 2, s3, s2, s1, s0, s7, s6, s5, s4, in[11], 0xC0AC29B7); \
	STEP(n, 2, s2, s1, s0, s7, s6, s5, s4, s3, in[28], 0xC97C50DD); \
	STEP(n, 2, s1, s0, s7, s6, s5, s4, s3, s2, in[ 7], 0x3F84D5B5); \
	STEP(n, 2, s0, s7, s6, s5, s4, s3, s2, s1, in[16], 0xB5470917); \
 \
	STEP(n, 2, s7, s6, s5, s4, s3, s2, s1, s0, in[ 0], 0x9216D5D9); \
	STEP(n, 2, s6, s5, s4, s3, s2, s1, s0, s7, in[23], 0x8979FB1B); \
	STEP(n, 2, s5, s4, s3, s2, s1, s0, s7, s6, in[20], 0xD1310BA6); \
	STEP(n, 2, s4, s3, s2, s1, s0, s7, s6, s5, in[22], 0x98DFB5AC); \
	STEP(n, 2, s3, s2, s1, s0, s7, s6, s5, s4, in[ 1], 0x2FFD72DB); \
	STEP(n, 2, s2, s1, s0, s7, s6, s5, s4, s3, in[10], 0xD01ADFB7); \
	STEP(n, 2, s1, s0, s7, s6, s5, s4, s3, s2, in[ 4], 0xB8E1AFED); \
	STEP(n, 2, s0, s7, s6, s5, s4, s3, s2, s1, in[ 8], 0x6A267E96); \
 \
	STEP(n, 2, s7, s6, s5, s4, s3, s2, s1, s0, in[30], 0xBA7C9045); \
	STEP(n, 2, s6, s5, s4, s3, s2, s1, s0, s7, in[ 3], 0xF12C7F99); \
	STEP(n, 2, s5, s4, s3, s2, s1, s0, s7, s6, in[21], 0x24A19947); \
	STEP(n, 2, s4, s3, s2, s1, s0, s7, s6, s5, in[ 9], 0xB3916CF7); \
	STEP(n, 2, s3, s2, s1, s0, s7, s6, s5, s4, in[17], 0x0801F2E2); \
	STEP(n, 2, s2, s1, s0, s7, s6, s5, s4, s3, in[24], 0x858EFC16); \
	STEP(n, 2, s1, s0, s7, s6, s5, s4, s3, s2, in[29], 0x636920D8); \
	STEP(n, 2, s0, s7, s6, s5, s4, s3, s2, s1, in[ 6], 0x71574E69); \
 \
	STEP(n, 2, s7, s6, s5, s4, s3, s2, s1, s0, in[19], 0xA458FEA3); \
	STEP(n, 2, s6, s5, s4, s3, s2, s1, s0, s7, in[12], 0xF4933D7E); \
	STEP(n, 2, s5, s4, s3, s2, s1, s0, s7, s6, in[15], 0x0D95748F); \
	STEP(n, 2, s4, s3, s2, s1, s0, s7, s6, s5, in[13], 0x728EB658); \
	STEP(n, 2, s3, s2, s1, s0, s7, s6, s5, s4, in[ 2], 0x718BCD58); \
	STEP(n, 2, s2, s1, s0, s7, s6, s5, s4, s3, in[25], 0x82154AEE); \
	STEP(n, 2, s1, s0, s7, s6, s5, s4, s3, s2, in[31], 0x7B54A41D); \
	STEP(n, 2, s0, s7, s6, s5, s4, s3, s2, s1, in[27], 0xC25A59B5); \
}

#define PASS3(n, in) { \
	STEP(n, 3, s7, s6, s5, s4, s3, s2, s1, s0, in[19], 0x9C30D539); \
	STEP(n, 3, s6, s5, s4, s3, s2, s1, s0, s7, in[ 9], 0x2AF26013); \
	STEP(n, 3, s5, s4, s3, s2, s1, s0, s7, s6, in[ 4], 0xC5D1B023); \
	STEP(n, 3, s4, s3, s2, s1, s0, s7, s6, s5, in[20], 0x286085F0); \
	STEP(n, 3, s3, s2, s1, s0, s7, s6, s5, s4, in[28], 0xCA417918); \
	STEP(n, 3, s2, s1, s0, s7, s6, s5, s4, s3, in[17], 0xB8DB38EF); \
	STEP(n, 3, s1, s0, s7, s6, s5, s4, s3, s2, in[ 8], 0x8E79DCB0); \
	STEP(n, 3, s0, s7, s6, s5, s4, s3, s2, s1, in[22], 0x603A180E); \
 \
	STEP(n, 3, s7, s6, s5, s4, s3, s2, s1, s0, in[29], 0x6C9E0E8B); \
	STEP(n, 3, s6, s5, s4, s3, s2, s1, s0, s7, in[14], 0xB01E8A3E); \
	STEP(n, 3, s5, s4, s3, s2, s1, s0, s7, s6, in[25], 0xD71577C1); \
	STEP(n, 3, s4, s3, s2, s1, s0, s7, s6, s5, in[12], 0xBD314B27); \
	STEP(n, 3, s3, s2, s1, s0, s7, s6, s5, s4, in[24], 0x78AF2FDA); \
	STEP(n, 3, s2, s1, s0, s7, s6, s5, s4, s3, in[30], 0x55605C60); \
	STEP(n, 3, s1, s0, s7, s6, s5, s4, s3, s2, in[16], 0xE65525F3); \
	STEP(n, 3, s0, s7, s6, s5, s4, s3, s2, s1, in[26], 0xAA55AB94); \
 \
	STEP(n, 3, s7, s6, s5, s4, s3, s2, s1, s0, in[31], 0x57489862); \
	STEP(n, 3, s6, s5, s4, s3, s2, s1, s0, s7, in[15], 0x63E81440); \
	STEP(n, 3, s5, s4, s3, s2, s1, s0, s7, s6, in[ 7], 0x55CA396A); \
	STEP(n, 3, s4, s3, s2, s1, s0, s7, s6, s5, in[ 3], 0x2AAB10B6); \
	STEP(n, 3, s3, s2, s1, s0, s7, s6, s5, s4, in[ 1], 0xB4CC5C34); \
	STEP(n, 3, s2, s1, s0, s7, s6, s5, s4, s3, in[ 0], 0x1141E8CE); \
	STEP(n, 3, s1, s0, s7, s6, s5, s4, s3, s2, in[18], 0xA15486AF); \
	STEP(n, 3, s0, s7, s6, s5, s4, s3, s2, s1, in[27], 0x7C72E993); \
 \
	STEP(n, 3, s7, s6, s5, s4, s3, s2, s1, s0, in[13], 0xB3EE1411); \
	STEP(n, 3, s6, s5, s4, s3, s2, s1, s0, s7, in[ 6], 0x636FBC2A); \
	STEP(n, 3, s5, s4, s3, s2, s1, s0, s7, s6, in[21], 0x2BA9C55D); \
	STEP(n, 3, s4, s3, s2, s1, s0, s7, s6, s5, in[10], 0x741831F6); \
	STEP(n, 3, s3, s2, s1, s0, s7, s6, s5, s4, in[23], 0xCE5C3E16); \
	STEP(n, 3, s2, s1, s0, s7, s6, s5, s4, s3, in[11], 0x9B87931E); \
	STEP(n, 3, s1, s0, s7, s6, s5, s4, s3, s2, in[ 5], 0xAFD6BA33); \
	STEP(n, 3, s0, s7, s6, s5, s4, s3, s2, s1, in[ 2], 0x6C24CF5C); \
}

#define PASS4(n, in) { \
	STEP(n, 4, s7, s6, s5, s4, s3, s2, s1, s0, in[24], 0x7A325381); \
	STEP(n, 4, s6, s5, s4, s3, s2, s1, s0, s7, in[ 4], 0x28958677); \
	STEP(n, 4, s5, s4, s3, s2, s1, s0, s7, s6, in[ 0], 0x3B8F4898); \
	STEP(n, 4, s4, s3, s2, s1, s0, s7, s6, s5, in[14], 0x6B4BB9AF); \
	STEP(n, 4, s3, s2, s1, s0, s7, s6, s5, s4, in[ 2], 0xC4BFE81B); \
	STEP(n, 4, s2, s1, s0, s7, s6, s5, s4, s3, in[ 7], 0x66282193); \
	STEP(n, 4, s1, s0, s7, s6, s5, s4, s3, s2, in[28], 0x61D809CC); \
	STEP(n, 4, s0, s7, s6, s5, s4, s3, s2, s1, in[23], 0xFB21A991); \
 \
	STEP(n, 4, s7, s6, s5, s4, s3, s2, s1, s0, in[26], 0x487CAC60); \
	STEP(n, 4, s6, s5, s4, s3, s2, s1, s0, s7, in[ 6], 0x5DEC8032); \
	STEP(n, 4, s5, s4, s3, s2, s1, s0, s7, s6, in[30], 0xEF845D5D); \
	STEP(n, 4, s4, s3, s2, s1, s0, s7, s6, s5, in[20], 0xE98575B1); \
	STEP(n, 4, s3, s2, s1, s0, s7, s6, s5, s4, in[18], 0xDC262302); \
	STEP(n, 4, s2, s1, s0, s7, s6, s5, s4, s3, in[25], 0xEB651B88); \
	STEP(n, 4, s1, s0, s7, s6, s5, s4, s3, s2, in[19], 0x23893E81); \
	STEP(n, 4, s0, s7, s6, s5, s4, s3, s2, s1, in[ 3], 0xD396ACC5); \
 \
	STEP(n, 4, s7, s6, s5, s4, s3, s2, s1, s0, in[22], 0x0F6D6FF3); \
	STEP(n, 4, s6, s5, s4, s3, s2, s1, s0, s7, in[11], 0x83F44239); \
	STEP(n, 4, s5, s4, s3, s2, s1, s0, s7, s6, in[31], 0x2E0B4482); \
	STEP(n, 4, s4, s3, s2, s1, s0, s7, s6, s5, in[21], 0xA4842004); \
	STEP(n, 4, s3, s2, s1, s0, s7, s6, s5, s4, in[ 8], 0x69C8F04A); \
	STEP(n, 4, s2, s1, s0, s7, s6, s5, s4, s3, in[27], 0x9E1F9B5E); \
	STEP(n, 4, s1, s0, s7, s6, s5, s4, s3, s2, in[12], 0x21C66842); \
	STEP(n, 4, s0, s7, s6, s5, s4, s3, s2, s1, in[ 9], 0xF6E96C9A); \
 \
	STEP(n, 4, s7, s6, s5, s4, s3, s2, s1, s0, in[ 1], 0x670C9C61); \
	STEP(n, 4, s6, s5, s4, s3, s2, s1, s0, s7, in[29], 0xABD388F0); \
	STEP(n, 4, s5, s4, s3, s2, s1, s0, s7, s6, in[ 5], 0x6A51A0D2); \
	STEP(n, 4, s4, s3, s2, s1, s0, s7, s6, s5, in[15], 0xD8542F68); \
	STEP(n, 4, s3, s2, s1, s0, s7, s6, s5, s4, in[17], 0x960FA728); \
	STEP(n, 4, s2, s1, s0, s7, s6, s5, s4, s3, in[10], 0xAB5133A3); \
	STEP(n, 4, s1, s0, s7, s6, s5, s4, s3, s2, in[16], 0x6EEF0B6C); \
	STEP(n, 4, s0, s7, s6, s5, s4, s3, s2, s1, in[13], 0x137A3BE4); \
}

#define PASS5(n, in) { \
	STEP(n, 5, s7, s6, s5, s4, s3, s2, s1, s0, in[27], 0xBA3BF050); \
	STEP(n, 5, s6, s5, s4, s3, s2, s1, s0, s7, in[ 3], 0x7EFB2A98); \
	STEP(n, 5, s5, s4, s3, s2, s1, s0, s7, s6, in[21], 0xA1F1651D); \
	STEP(n, 5, s4, s3, s2, s1, s0, s7, s6, s5, in[26], 0x39AF0176); \
	STEP(n, 5, s3, s2, s1, s0, s7, s6, s5, s4, in[17], 0x66CA593E); \
	STEP(n, 5, s2, s1, s0, s7, s6, s5, s4, s3, in[11], 0x82430E88); \
	STEP(n, 5, s1, s0, s7, s6, s5, s4, s3, s2, in[20], 0x8CEE8619); \
	STEP(n, 5, s0, s7, s6, s5, s4, s3, s2, s1, in[29], 0x456F9FB4); \
 \
	STEP(n, 5, s7, s6, s5, s4, s3, s2, s1, s0, in[19], 0x7D84A5C3); \
	STEP(n, 5, s6, s5, s4, s3, s2, s1, s0, s7, in[ 0], 0x3B8B5EBE); \
	STEP(n, 5, s5, s4, s3, s2, s1, s0, s7, s6, in[12], 0xE06F75D8); \
	STEP(n, 5, s4, s3, s2, s1, s0, s7, s6, s5, in[ 7], 0x85C12073); \
	STEP(n, 5, s3, s2, s1, s0, s7, s6, s5, s4, in[13], 0x401A449F); \
	STEP(n, 5, s2, s1, s0, s7, s6, s5, s4, s3, in[ 8], 0x56C16AA6); \
	STEP(n, 5, s1, s0, s7, s6, s5, s4, s3, s2, in[31], 0x4ED3AA62); \
	STEP(n, 5, s0, s7, s6, s5, s4, s3, s2, s1, in[10], 0x363F7706); \
 \
	STEP(n, 5, s7, s6, s5, s4, s3, s2, s1, s0, in[ 5], 0x1BFEDF72); \
	STEP(n, 5, s6, s5, s4, s3, s2, s1, s0, s7, in[ 9], 0x429B023D); \
	STEP(n, 5, s5, s4, s3, s2, s1, s0, s7, s6, in[14], 0x37D0D724); \
	STEP(n, 5, s4, s3, s2, s1, s0, s7, s6, s5, in[30], 0xD00A1248); \
	STEP(n, 5, s3, s2, s1, s0, s7, s6, s5, s4, in[18], 0xDB0FEAD3); \
	STEP(n, 5, s2, s1, s0, s7, s6, s5, s4, s3, in[ 6], 0x49F1C09B); \
	STEP(n, 5, s1, s0, s7, s6, s5, s4, s3, s2, in[28], 0x075372C9); \
	STEP(n, 5, s0, s7, s6, s5, s4, s3, s2, s1, in[24], 0x80991B7B); \
 \
	STEP(n, 5, s7, s6, s5, s4, s3, s2, s1, s0, in[ 2], 0x25D479D8); \
	STEP(n, 5, s6, s5, s4, s3, s2, s1, s0, s7, in[23], 0xF6E8DEF7); \
	STEP(n, 5, s5, s4, s3, s2, s1, s0, s7, s6, in[16], 0xE3FE501A); \
	STEP(n, 5, s4, s3, s2, s1, s0, s7, s6, s5, in[22], 0xB6794C3B); \
	STEP(n, 5, s3, s2, s1, s0, s7, s6, s5, s4, in[ 4], 0x976CE0BD); \
	STEP(n, 5, s2, s1, s0, s7, s6, s5, s4, s3, in[ 1], 0x04C006BA); \
	STEP(n, 5, s1, s0, s7, s6, s5, s4, s3, s2, in[25], 0xC1A94FB6); \
	STEP(n, 5, s0, s7, s6, s5, s4, s3, s2, s1, in[15], 0x409F60C4); \
}

#define PASS5_final(n, in) { \
	STEP(n, 5, s7, s6, s5, s4, s3, s2, s1, s0, in[27], 0xBA3BF050); \
	STEP(n, 5, s6, s5, s4, s3, s2, s1, s0, s7, in[ 3], 0x7EFB2A98); \
	STEP(n, 5, s5, s4, s3, s2, s1, s0, s7, s6, in[21], 0xA1F1651D); \
	STEP(n, 5, s4, s3, s2, s1, s0, s7, s6, s5, in[26], 0x39AF0176); \
	STEP(n, 5, s3, s2, s1, s0, s7, s6, s5, s4, in[17], 0x66CA593E); \
	STEP(n, 5, s2, s1, s0, s7, s6, s5, s4, s3, in[11], 0x82430E88); \
	STEP(n, 5, s1, s0, s7, s6, s5, s4, s3, s2, in[20], 0x8CEE8619); \
	STEP(n, 5, s0, s7, s6, s5, s4, s3, s2, s1, in[29], 0x456F9FB4); \
 \
	STEP(n, 5, s7, s6, s5, s4, s3, s2, s1, s0, in[19], 0x7D84A5C3); \
	STEP(n, 5, s6, s5, s4, s3, s2, s1, s0, s7, in[ 0], 0x3B8B5EBE); \
	STEP(n, 5, s5, s4, s3, s2, s1, s0, s7, s6, in[12], 0xE06F75D8); \
	STEP(n, 5, s4, s3, s2, s1, s0, s7, s6, s5, in[ 7], 0x85C12073); \
	STEP(n, 5, s3, s2, s1, s0, s7, s6, s5, s4, in[13], 0x401A449F); \
	STEP(n, 5, s2, s1, s0, s7, s6, s5, s4, s3, in[ 8], 0x56C16AA6); \
	STEP(n, 5, s1, s0, s7, s6, s5, s4, s3, s2, in[31], 0x4ED3AA62); \
	STEP(n, 5, s0, s7, s6, s5, s4, s3, s2, s1, in[10], 0x363F7706); \
 \
	STEP(n, 5, s7, s6, s5, s4, s3, s2, s1, s0, in[ 5], 0x1BFEDF72); \
	STEP(n, 5, s6, s5, s4, s3, s2, s1, s0, s7, in[ 9], 0x429B023D); \
	STEP(n, 5, s5, s4, s3, s2, s1, s0, s7, s6, in[14], 0x37D0D724); \
	STEP(n, 5, s4, s3, s2, s1, s0, s7, s6, s5, in[30], 0xD00A1248); \
	STEP(n, 5, s3, s2, s1, s0, s7, s6, s5, s4, in[18], 0xDB0FEAD3); \
	STEP(n, 5, s2, s1, s0, s7, s6, s5, s4, s3, in[ 6], 0x49F1C09B); \
	STEP(n, 5, s1, s0, s7, s6, s5, s4, s3, s2, in[28], 0x075372C9); \
	STEP(n, 5, s0, s7, s6, s5, s4, s3, s2, s1, in[24], 0x80991B7B); \
 \
	STEP(n, 5, s7, s6, s5, s4, s3, s2, s1, s0, in[ 2], 0x25D479D8); \
	STEP(n, 5, s6, s5, s4, s3, s2, s1, s0, s7, in[23], 0xF6E8DEF7); \
}

__global__ __launch_bounds__(TPB, 4)
void x17_haval256_gpu_hash_64_final(const uint32_t threads,const uint64_t* __restrict__ g_hash,uint32_t* resNonce,const uint64_t target)
{
	uint32_t thread = (blockDim.x * blockIdx.x + threadIdx.x);

	uint32_t s0, s1, s2, s3, s4, s5, s6, s7;
	const uint32_t u0 = s0 = 0x243F6A88;
	const uint32_t u1 = s1 = 0x85A308D3;
	const uint32_t u2 = s2 = 0x13198A2E;
	const uint32_t u3 = s3 = 0x03707344;
	const uint32_t u4 = s4 = 0xA4093822;
	const uint32_t u5 = s5 = 0x299F31D0;
	const uint32_t u6 = s6 = 0x082EFA98;
	const uint32_t u7 = s7 = 0xEC4E6C89;

	uint32_t buf[32];
	if (thread < threads)
	{
		const uint64_t *pHash = &g_hash[thread<<3];

		#pragma unroll 8
		for(int i=0;i<8;i++){
			*(uint2*)&buf[i<<1] = __ldg((uint2*)&pHash[i]);
		}

		buf[16] = 0x00000001;

		#pragma unroll
		for (int i=17; i<29; i++)
			buf[i] = 0;

		buf[29] = 0x40290000;
		buf[30] = 0x00000200;
		buf[31] = 0;

		PASS1(5, buf);
		PASS2(5, buf);
		PASS3(5, buf);
		PASS4(5, buf);
		PASS5_final(5, buf);

		buf[6] = s6 + u6;
		buf[7] = s7 + u7;

		if(*(uint64_t*)&buf[ 6] <= target){
			uint32_t tmp = atomicExch(&resNonce[0], thread);
			if (tmp != UINT32_MAX)
				resNonce[1] = tmp;		
		}
	}
}

__host__
void x17_haval256_cpu_hash_64_final(int thr_id, uint32_t threads, uint32_t *d_hash, uint32_t *resNonce, uint64_t target)
{
	dim3 grid((threads + TPB-1)/TPB);
	dim3 block(TPB);

	x17_haval256_gpu_hash_64_final <<<grid, block>>> (threads, (uint64_t*)d_hash,resNonce,target);
}

#define sph_u32 uint32_t

#define H_SAVE_STATE \
	sph_u32 u0, u1, u2, u3, u4, u5, u6, u7; \
	do { \
		u0 = s0; \
		u1 = s1; \
		u2 = s2; \
		u3 = s3; \
		u4 = s4; \
		u5 = s5; \
		u6 = s6; \
		u7 = s7; \
	} while (0)

#define H_UPDATE_STATE   do { \
		s0 = SPH_T32(s0 + u0); \
		s1 = SPH_T32(s1 + u1); \
		s2 = SPH_T32(s2 + u2); \
		s3 = SPH_T32(s3 + u3); \
		s4 = SPH_T32(s4 + u4); \
		s5 = SPH_T32(s5 + u5); \
		s6 = SPH_T32(s6 + u6); \
		s7 = SPH_T32(s7 + u7); \
	} while (0)

#define CORE5(in)  do { \
		H_SAVE_STATE; \
		PASS1(5, in); \
		PASS2(5, in); \
		PASS3(5, in); \
		PASS4(5, in); \
		PASS5(5, in); \
		H_UPDATE_STATE; \
	} while (0)


#define CORE5_F(in)  do { \
                H_SAVE_STATE; \
                PASS1(5, in); \
                PASS2(5, in); \
                PASS3(5, in); \
                PASS4(5, in); \
                PASS5_final(5, in); \
                H_UPDATE_STATE; \
        } while (0)

__global__ __launch_bounds__(TPB, 2)
void xevan_haval512_gpu_hash_64(const uint32_t threads,const uint64_t*  g_hash)
{
        uint32_t thread = (blockDim.x * blockIdx.x + threadIdx.x);

        if (thread < threads)
        {
                 uint32_t *pHash = (uint32_t *)&g_hash[thread<<3];
// haval
  sph_u32 s0 = SPH_C32(0x243F6A88);
  sph_u32 s1 = SPH_C32(0x85A308D3);
  sph_u32 s2 = SPH_C32(0x13198A2E);
  sph_u32 s3 = SPH_C32(0x03707344);
  sph_u32 s4 = SPH_C32(0xA4093822);
  sph_u32 s5 = SPH_C32(0x299F31D0);
  sph_u32 s6 = SPH_C32(0x082EFA98);
  sph_u32 s7 = SPH_C32(0xEC4E6C89);

  sph_u32 X_var[32];
//#pragma unroll 16
/*
  for (int i = 0; i < 16; i++)
    X_var[i] = pHash[i];
*/

                uint2x4* phash = (uint2x4*)pHash;
                uint2x4* outpt = (uint2x4*)X_var;
                outpt[0] = __ldg4(&phash[0]);
                outpt[1] = __ldg4(&phash[1]);

#pragma unroll 16
  for (int i = 16; i < 32; i++)
    X_var[i] = 0;

//#define A(x) X_var[x]
  CORE5(X_var);
//#undef A

  X_var[0] = 0x00000001U;
/*
  X_var[1] = 0x00000000U;
  X_var[2] = 0x00000000U;
  X_var[3] = 0x00000000U;
  X_var[4] = 0x00000000U;
  X_var[5] = 0x00000000U;
  X_var[6] = 0x00000000U;
  X_var[7] = 0x00000000U;
  X_var[8] = 0x00000000U;
  X_var[9] = 0x00000000U;
  X_var[10] = 0x00000000U;
  X_var[11] = 0x00000000U;
  X_var[12] = 0x00000000U;
  X_var[13] = 0x00000000U;
  X_var[14] = 0x00000000U;
  X_var[15] = 0x00000000U;
  X_var[16] = 0x00000000U;
  X_var[17] = 0x00000000U;
  X_var[18] = 0x00000000U;
  X_var[19] = 0x00000000U;
  X_var[20] = 0x00000000U;
  X_var[21] = 0x00000000U;
  X_var[22] = 0x00000000U;
  X_var[23] = 0x00000000U;
  X_var[24] = 0x00000000U;
  X_var[25] = 0x00000000U;
  X_var[26] = 0x00000000U;
  X_var[27] = 0x00000000U;
  X_var[28] = 0x00000000U;*/

#pragma unroll 28
  for (int i = 1; i < 29; i++)
    X_var[i] = 0;

  X_var[29] = 0x40290000U;
  X_var[30] = 0x00000400U;
  X_var[31] = 0x00000000U;

//#define A(x) X_var[x]
  CORE5(X_var);
//#undef A

/*
uint32_t __align__(16) res[8];
uint32_t __align__(16) res1[8] = {0,0,0,0,0,0,0,0};


res[0]=s0;
res[1]=s1;
res[2]=s2;
res[3]=s3;
res[4]=s4;
res[5]=s5;
res[6]=s6;
res[7]=s7;

		*(uint2x4*)&pHash[0] = *(uint2x4*)&res[0];			
		*(uint2x4*)&pHash[8] = *(uint2x4*)&res1[0];
*/
/*
uint64_t *o=(uint64_t *)pHash;
o[0]=MAKE_ULONGLONG(s0,s1);
o[1]=MAKE_ULONGLONG(s2,s3);
o[2]=MAKE_ULONGLONG(s4,s5);
o[3]=MAKE_ULONGLONG(s6,s7);

#pragma unroll 4
for(int i=4;i<8;i++)o[i]=0UL;
*/


  pHash[0] = s0;
  pHash[1] = s1;
  pHash[2] = s2;
  pHash[3] = s3;
  pHash[4] = s4;
  pHash[5] = s5;
  pHash[6] = s6;
  pHash[7] = s7;
  
  pHash[8] = 0;
  pHash[9] = 0;
  pHash[10] = 0;
  pHash[11] = 0;
  pHash[12] = 0;
  pHash[13] = 0;
  pHash[14] = 0;
  pHash[15] = 0;



/*hash->h8[4] = 0;
  hash->h8[5] = 0;
  hash->h8[6] = 0;
  hash->h8[7] = 0;

*/
	}
}


__host__
void xevan_haval512_cpu_hash_64(int thr_id, uint32_t threads, uint32_t *d_hash)
{
        dim3 grid((threads + TPB-1)/TPB);
        dim3 block(TPB);

        xevan_haval512_gpu_hash_64 <<<grid, block>>> (threads, (uint64_t*)d_hash);
}



#define TPB_F 512

__global__ __launch_bounds__(TPB_F, 4)
void xevan_haval512_gpu_hash_64_final(const uint32_t threads,const uint64_t* __restrict__ g_hash,uint32_t* resNonce,const uint64_t target)
{
        uint32_t thread = (blockDim.x * blockIdx.x + threadIdx.x);

        if (thread < threads)
        {
                 uint32_t *pHash = (uint32_t *)&g_hash[thread<<3];
// haval
  sph_u32 s0 = SPH_C32(0x243F6A88);
  sph_u32 s1 = SPH_C32(0x85A308D3);
  sph_u32 s2 = SPH_C32(0x13198A2E);
  sph_u32 s3 = SPH_C32(0x03707344);
  sph_u32 s4 = SPH_C32(0xA4093822);
  sph_u32 s5 = SPH_C32(0x299F31D0);
  sph_u32 s6 = SPH_C32(0x082EFA98);
  sph_u32 s7 = SPH_C32(0xEC4E6C89);

  sph_u32 X_var[32];

/*
#pragma unroll 16
  for (int i = 0; i < 16; i++)
    X_var[i] = pHash[i];
*/
		uint2x4* phash = (uint2x4*)pHash;
		uint2x4* outpt = (uint2x4*)X_var;
		outpt[0] = __ldg4(&phash[0]);
		outpt[1] = __ldg4(&phash[1]);

//#pragma unroll 16
  for (int i = 16; i < 32; i++)
    X_var[i] = 0;

//#define A(x) X_var[x]
  CORE5(X_var);
//#undef A

  X_var[0] = 0x00000001U;
 /* X_var[1] = 0x00000000U;
  X_var[2] = 0x00000000U;
  X_var[3] = 0x00000000U;
  X_var[4] = 0x00000000U;
  X_var[5] = 0x00000000U;
  X_var[6] = 0x00000000U;
  X_var[7] = 0x00000000U;
  X_var[8] = 0x00000000U;
  X_var[9] = 0x00000000U;
  X_var[10] = 0x00000000U;
  X_var[11] = 0x00000000U;
  X_var[12] = 0x00000000U;
  X_var[13] = 0x00000000U;
  X_var[14] = 0x00000000U;
  X_var[15] = 0x00000000U;
  X_var[16] = 0x00000000U;
  X_var[17] = 0x00000000U;
  X_var[18] = 0x00000000U;
  X_var[19] = 0x00000000U;
  X_var[20] = 0x00000000U;
  X_var[21] = 0x00000000U;
  X_var[22] = 0x00000000U;
  X_var[23] = 0x00000000U;
  X_var[24] = 0x00000000U;
  X_var[25] = 0x00000000U;
  X_var[26] = 0x00000000U;
  X_var[27] = 0x00000000U;
  X_var[28] = 0x00000000U;*/

#pragma unroll 28
  for (int i = 1; i < 29; i++)
    X_var[i] = 0;
  X_var[29] = 0x40290000U;
  X_var[30] = 0x00000400U;
  X_var[31] = 0x00000000U;

//#define A(x) X_var[x]
  CORE5_F(X_var);
//#undef A
  X_var[0] = s6;
  X_var[1] = s7;

		if(*(uint64_t *)&X_var[0] <= (target)){
		uint32_t tmp = atomicExch(&resNonce[0], thread);
			if (tmp != UINT32_MAX)
				resNonce[1] = tmp;		
		}
	}
}


__host__
void xevan_haval512_cpu_hash_64_final(int thr_id, uint32_t threads, uint32_t *d_hash, uint32_t *resNonce, uint64_t target)
{
        dim3 grid((threads + TPB_F-1)/TPB_F);
        dim3 block(TPB_F);

        xevan_haval512_gpu_hash_64_final <<<grid, block>>> (threads, (uint64_t*)d_hash,resNonce,target);
}




#define sph_u64 uint64_t


#define Z00   0
#define Z01   1
#define Z02   2
#define Z03   3
#define Z04   4
#define Z05   5
#define Z06   6
#define Z07   7
#define Z08   8
#define Z09   9
#define Z0A   A
#define Z0B   B
#define Z0C   C
#define Z0D   D
#define Z0E   E
#define Z0F   F

#define Z10   E
#define Z11   A
#define Z12   4
#define Z13   8
#define Z14   9
#define Z15   F
#define Z16   D
#define Z17   6
#define Z18   1
#define Z19   C
#define Z1A   0
#define Z1B   2
#define Z1C   B
#define Z1D   7
#define Z1E   5
#define Z1F   3

#define Z20   B
#define Z21   8
#define Z22   C
#define Z23   0
#define Z24   5
#define Z25   2
#define Z26   F
#define Z27   D
#define Z28   A
#define Z29   E
#define Z2A   3
#define Z2B   6
#define Z2C   7
#define Z2D   1
#define Z2E   9
#define Z2F   4

#define Z30   7
#define Z31   9
#define Z32   3
#define Z33   1
#define Z34   D
#define Z35   C
#define Z36   B
#define Z37   E
#define Z38   2
#define Z39   6
#define Z3A   5
#define Z3B   A
#define Z3C   4
#define Z3D   0
#define Z3E   F
#define Z3F   8

#define Z40   9
#define Z41   0
#define Z42   5
#define Z43   7
#define Z44   2
#define Z45   4
#define Z46   A
#define Z47   F
#define Z48   E
#define Z49   1
#define Z4A   B
#define Z4B   C
#define Z4C   6
#define Z4D   8
#define Z4E   3
#define Z4F   D

#define Z50   2
#define Z51   C
#define Z52   6
#define Z53   A
#define Z54   0
#define Z55   B
#define Z56   8
#define Z57   3
#define Z58   4
#define Z59   D
#define Z5A   7
#define Z5B   5
#define Z5C   F
#define Z5D   E
#define Z5E   1
#define Z5F   9

#define Z60   C
#define Z61   5
#define Z62   1
#define Z63   F
#define Z64   E
#define Z65   D
#define Z66   4
#define Z67   A
#define Z68   0
#define Z69   7
#define Z6A   6
#define Z6B   3
#define Z6C   9
#define Z6D   2
#define Z6E   8
#define Z6F   B

#define Z70   D
#define Z71   B
#define Z72   7
#define Z73   E
#define Z74   C
#define Z75   1
#define Z76   3
#define Z77   9
#define Z78   5
#define Z79   0
#define Z7A   F
#define Z7B   4
#define Z7C   8
#define Z7D   6
#define Z7E   2
#define Z7F   A

#define Z80   6
#define Z81   F
#define Z82   E
#define Z83   9
#define Z84   B
#define Z85   3
#define Z86   0
#define Z87   8
#define Z88   C
#define Z89   2
#define Z8A   D
#define Z8B   7
#define Z8C   1
#define Z8D   4
#define Z8E   A
#define Z8F   5

#define Z90   A
#define Z91   2
#define Z92   8
#define Z93   4
#define Z94   7
#define Z95   6
#define Z96   1
#define Z97   5
#define Z98   F
#define Z99   B
#define Z9A   9
#define Z9B   E
#define Z9C   3
#define Z9D   C
#define Z9E   D
#define Z9F   0

#define Mx(r, i)    Mx_(Z ## r ## i)
#define Mx_(n)      Mx__(n)
#define Mx__(n)     M ## n

#define CSx(r, i)   CSx_(Z ## r ## i)
#define CSx_(n)     CSx__(n)
#define CSx__(n)    CS ## n

#define CS0   SPH_C32(0x243F6A88)
#define CS1   SPH_C32(0x85A308D3)
#define CS2   SPH_C32(0x13198A2E)
#define CS3   SPH_C32(0x03707344)
#define CS4   SPH_C32(0xA4093822)
#define CS5   SPH_C32(0x299F31D0)
#define CS6   SPH_C32(0x082EFA98)
#define CS7   SPH_C32(0xEC4E6C89)
#define CS8   SPH_C32(0x452821E6)
#define CS9   SPH_C32(0x38D01377)
#define CSA   SPH_C32(0xBE5466CF)
#define CSB   SPH_C32(0x34E90C6C)
#define CSC   SPH_C32(0xC0AC29B7)
#define CSD   SPH_C32(0xC97C50DD)
#define CSE   SPH_C32(0x3F84D5B5)
#define CSF   SPH_C32(0xB5470917)


#define CBx(r, i)   CBx_(Z ## r ## i)
#define CBx_(n)     CBx__(n)
#define CBx__(n)    CB ## n

#define CB0   SPH_C64(0x243F6A8885A308D3)
#define CB1   SPH_C64(0x13198A2E03707344)
#define CB2   SPH_C64(0xA4093822299F31D0)
#define CB3   SPH_C64(0x082EFA98EC4E6C89)
#define CB4   SPH_C64(0x452821E638D01377)
#define CB5   SPH_C64(0xBE5466CF34E90C6C)
#define CB6   SPH_C64(0xC0AC29B7C97C50DD)
#define CB7   SPH_C64(0x3F84D5B5B5470917)
#define CB8   SPH_C64(0x9216D5D98979FB1B)
#define CB9   SPH_C64(0xD1310BA698DFB5AC)
#define CBA   SPH_C64(0x2FFD72DBD01ADFB7)
#define CBB   SPH_C64(0xB8E1AFED6A267E96)
#define CBC   SPH_C64(0xBA7C9045F12C7F99)
#define CBD   SPH_C64(0x24A19947B3916CF7)
#define CBE   SPH_C64(0x0801F2E2858EFC16)
#define CBF   SPH_C64(0x636920D871574E69)


#define GB(m0, m1, c0, c1, a, b, c, d)   do { \
    a = SPH_T64(a + b + (m0 ^ c1)); \
    d = SPH_ROTR64(d ^ a, 32); \
    c = SPH_T64(c + d); \
    b = SPH_ROTR64(b ^ c, 25); \
    a = SPH_T64(a + b + (m1 ^ c0)); \
    d = SPH_ROTR64(d ^ a, 16); \
    c = SPH_T64(c + d); \
    b = SPH_ROTR64(b ^ c, 11); \
  } while (0)

#define ROUND_B(r)   do { \
    GB(Mx(r, 0), Mx(r, 1), CBx(r, 0), CBx(r, 1), V0, V4, V8, VC); \
    GB(Mx(r, 2), Mx(r, 3), CBx(r, 2), CBx(r, 3), V1, V5, V9, VD); \
    GB(Mx(r, 4), Mx(r, 5), CBx(r, 4), CBx(r, 5), V2, V6, VA, VE); \
    GB(Mx(r, 6), Mx(r, 7), CBx(r, 6), CBx(r, 7), V3, V7, VB, VF); \
    GB(Mx(r, 8), Mx(r, 9), CBx(r, 8), CBx(r, 9), V0, V5, VA, VF); \
    GB(Mx(r, A), Mx(r, B), CBx(r, A), CBx(r, B), V1, V6, VB, VC); \
    GB(Mx(r, C), Mx(r, D), CBx(r, C), CBx(r, D), V2, V7, V8, VD); \
    GB(Mx(r, E), Mx(r, F), CBx(r, E), CBx(r, F), V3, V4, V9, VE); \
  } while (0)



#define BLAKE_DECL_STATE64 \
  sph_u64 H0, H1, H2, H3, H4, H5, H6, H7; \
  sph_u64 S0, S1, S2, S3, T0, T1;

#define BLAKE_READ_STATE64(state)   do { \
    H0 = (state)->H[0]; \
    H1 = (state)->H[1]; \
    H2 = (state)->H[2]; \
    H3 = (state)->H[3]; \
    H4 = (state)->H[4]; \
    H5 = (state)->H[5]; \
    H6 = (state)->H[6]; \
    H7 = (state)->H[7]; \
    S0 = (state)->S[0]; \
    S1 = (state)->S[1]; \
    S2 = (state)->S[2]; \
    S3 = (state)->S[3]; \
    T0 = (state)->T0; \
    T1 = (state)->T1; \
  } while (0)

#define BLAKE_WRITE_STATE64(state)   do { \
    (state)->H[0] = H0; \
    (state)->H[1] = H1; \
    (state)->H[2] = H2; \
    (state)->H[3] = H3; \
    (state)->H[4] = H4; \
    (state)->H[5] = H5; \
    (state)->H[6] = H6; \
    (state)->H[7] = H7; \
    (state)->S[0] = S0; \
    (state)->S[1] = S1; \
    (state)->S[2] = S2; \
    (state)->S[3] = S3; \
    (state)->T0 = T0; \
    (state)->T1 = T1; \
  } while (0)

#define COMPRESS64   do { \
    V0 = H0; \
    V1 = H1; \
    V2 = H2; \
    V3 = H3; \
    V4 = H4; \
    V5 = H5; \
    V6 = H6; \
    V7 = H7; \
    V8 = S0 ^ CB0; \
    V9 = S1 ^ CB1; \
    VA = S2 ^ CB2; \
    VB = S3 ^ CB3; \
    VC = T0 ^ CB4; \
    VD = T0 ^ CB5; \
    VE = T1 ^ CB6; \
    VF = T1 ^ CB7; \
    ROUND_B(0); \
    ROUND_B(1); \
    ROUND_B(2); \
    ROUND_B(3); \
    ROUND_B(4); \
    ROUND_B(5); \
    ROUND_B(6); \
    ROUND_B(7); \
    ROUND_B(8); \
    ROUND_B(9); \
    ROUND_B(0); \
    ROUND_B(1); \
    ROUND_B(2); \
    ROUND_B(3); \
    ROUND_B(4); \
    ROUND_B(5); \
    H0 ^= S0 ^ V0 ^ V8; \
    H1 ^= S1 ^ V1 ^ V9; \
    H2 ^= S2 ^ V2 ^ VA; \
    H3 ^= S3 ^ V3 ^ VB; \
    H4 ^= S0 ^ V4 ^ VC; \
    H5 ^= S1 ^ V5 ^ VD; \
    H6 ^= S2 ^ V6 ^ VE; \
    H7 ^= S3 ^ V7 ^ VF; \
  } while (0)

/*    ROUND_B(0); \
    ROUND_B(1); \
    ROUND_B(2); \
    ROUND_B(3); \
    ROUND_B(4); \
    ROUND_B(5); \
    ROUND_B(6); \
    ROUND_B(7); \
    ROUND_B(8); \
    ROUND_B(9); \*/


#define SPH_ROTR64 ROTR64
#define SWAP8 cuda_swab64

#define TPB_BLAKE 192

__global__ __launch_bounds__(TPB_BLAKE, 1)
void xevan_blake512_gpu_hash_64(const uint32_t threads, uint64_t*  g_hash)
{
        uint32_t thread = (blockDim.x * blockIdx.x + threadIdx.x);

        if (thread < threads)
        {
                 uint64_t *h8 = &g_hash[thread<<3];

		  sph_u64 H0 = SPH_C64(0x6A09E667F3BCC908), H1 = SPH_C64(0xBB67AE8584CAA73B);
  sph_u64 H2 = SPH_C64(0x3C6EF372FE94F82B), H3 = SPH_C64(0xA54FF53A5F1D36F1);
  sph_u64 H4 = SPH_C64(0x510E527FADE682D1), H5 = SPH_C64(0x9B05688C2B3E6C1F);
  sph_u64 H6 = SPH_C64(0x1F83D9ABFB41BD6B), H7 = SPH_C64(0x5BE0CD19137E2179);
  sph_u64 S0 = 0, S1 = 0, S2 = 0, S3 = 0;
  sph_u64 T0 = 1024, T1 = 0;

  sph_u64 M0, M1, M2, M3, M4, M5, M6, M7;
  sph_u64 M8, M9, MA, MB, MC, MD, ME, MF;
  sph_u64 V0, V1, V2, V3, V4, V5, V6, V7;
  sph_u64 V8, V9, VA, VB, VC, VD, VE, VF;

		uint64_t msg[8];

		uint2x4 *phash = (uint2x4*)h8;
		uint2x4 *outpt = (uint2x4*)msg;
		outpt[0] = __ldg4(&phash[0]);
		outpt[1] = __ldg4(&phash[1]);

  M0 = SWAP8(msg[0]);
  M1 = SWAP8(msg[1]);
  M2 = SWAP8(msg[2]);
  M3 = SWAP8(msg[3]);
  M4 = SWAP8(msg[4]);
  M5 = SWAP8(msg[5]);
  M6 = SWAP8(msg[6]);
  M7 = SWAP8(msg[7]);
  M8 = 0;
  M9 = 0;
  MA = 0;
  MB = 0;
  MC = 0;
  MD = 0;
  ME = 0;
  MF = 0;

  COMPRESS64;

/*
  h8[0] = SWAP8(H0);
  h8[1] = SWAP8(H1);
  h8[2] = SWAP8(H2);
  h8[3] = SWAP8(H3);
  h8[4] = SWAP8(H4);
  h8[5] = SWAP8(H5);
  h8[6] = SWAP8(H6);
  h8[7] = SWAP8(H7);

return;*/

  M0 = 0x8000000000000000;
  M1 = 0;
  M2 = 0;
  M3 = 0;
  M4 = 0;
  M5 = 0;
  M6 = 0;
  M7 = 0;
  M8 = 0;
  M9 = 0;
  MA = 0;
  MB = 0;
  MC = 0;
  MD = 1;
  ME = 0;
  MF = 0x400;

  T0 = 0;
  COMPRESS64;

  h8[0] = SWAP8(H0);
  h8[1] = SWAP8(H1);
  h8[2] = SWAP8(H2);
  h8[3] = SWAP8(H3);
  h8[4] = SWAP8(H4);
  h8[5] = SWAP8(H5);
  h8[6] = SWAP8(H6);
  h8[7] = SWAP8(H7);
	}
}



__host__
void xevan_blake512_cpu_hash_64(int thr_id, uint32_t threads, uint32_t *d_hash)
{
        dim3 grid((threads + TPB_BLAKE-1)/TPB_BLAKE);
        dim3 block(TPB_BLAKE);

        xevan_blake512_gpu_hash_64 <<<grid, block>>> (threads, (uint64_t*)d_hash);
}




// ---------------------------- BEGIN CUDA quark_blake512 functions ------------------------------------
#define ROTR(x,n) ROTR64(x,n)

__device__ __constant__
static const uint8_t c_sigma_big[16][16] = {
	{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 },
	{14, 10, 4, 8, 9, 15, 13, 6, 1, 12, 0, 2, 11, 7, 5, 3 },
	{11, 8, 12, 0, 5, 2, 15, 13, 10, 14, 3, 6, 7, 1, 9, 4 },
	{ 7, 9, 3, 1, 13, 12, 11, 14, 2, 6, 5, 10, 4, 0, 15, 8 },
	{ 9, 0, 5, 7, 2, 4, 10, 15, 14, 1, 11, 12, 6, 8, 3, 13 },
	{ 2, 12, 6, 10, 0, 11, 8, 3, 4, 13, 7, 5, 15, 14, 1, 9 },

	{12, 5, 1, 15, 14, 13, 4, 10, 0, 7, 6, 3, 9, 2, 8, 11 },
	{13, 11, 7, 14, 12, 1, 3, 9, 5, 0, 15, 4, 8, 6, 2, 10 },
	{ 6, 15, 14, 9, 11, 3, 0, 8, 12, 2, 13, 7, 1, 4, 10, 5 },
	{10, 2, 8, 4, 7, 6, 1, 5, 15, 11, 9, 14, 3, 12, 13 , 0 },

	{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 },
	{14, 10, 4, 8, 9, 15, 13, 6, 1, 12, 0, 2, 11, 7, 5, 3 },
	{11, 8, 12, 0, 5, 2, 15, 13, 10, 14, 3, 6, 7, 1, 9, 4 },
	{ 7, 9, 3, 1, 13, 12, 11, 14, 2, 6, 5, 10, 4, 0, 15, 8 },
	{ 9, 0, 5, 7, 2, 4, 10, 15, 14, 1, 11, 12, 6, 8, 3, 13 },
	{ 2, 12, 6, 10, 0, 11, 8, 3, 4, 13, 7, 5, 15, 14, 1, 9 }
};

__device__ __constant__
static const uint64_t c_u512[16] =
{
	0x243f6a8885a308d3ULL, 0x13198a2e03707344ULL,
	0xa4093822299f31d0ULL, 0x082efa98ec4e6c89ULL,
	0x452821e638d01377ULL, 0xbe5466cf34e90c6cULL,
	0xc0ac29b7c97c50ddULL, 0x3f84d5b5b5470917ULL,
	0x9216d5d98979fb1bULL, 0xd1310ba698dfb5acULL,
	0x2ffd72dbd01adfb7ULL, 0xb8e1afed6a267e96ULL,
	0xba7c9045f12c7f99ULL, 0x24a19947b3916cf7ULL,
	0x0801f2e2858efc16ULL, 0x636920d871574e69ULL
};


#define G(a,b,c,d,x) { \
	uint32_t idx1 = sigma[i][x]; \
	uint32_t idx2 = sigma[i][x+1]; \
	v[a] += (m[idx1] ^ u512[idx2]) + v[b]; \
	v[d] = SWAPDWORDS(v[d] ^ v[a]); \
	v[c] += v[d]; \
	v[b] = ROTR( (v[b] ^ v[c]), 25); \
	v[a] += (m[idx2] ^ u512[idx1]) + v[b]; \
	v[d] = ROTR( v[d] ^ v[a], 16); \
	v[c] += v[d]; \
	v[b] = ROTR( v[b] ^ v[c], 11); \
}


/*
#define G(a,b,c,d,x) { \
        uint32_t idx1 = sigma[i][x]; \
        uint32_t idx2 = sigma[i][x+1]; \
        v[a] += (m[idx1] ^ 0x32) + v[b]; \
        v[d] = SWAPDWORDS(v[d] ^ v[a]); \
        v[c] += v[d]; \
        v[b] = ROTR( (v[b] ^ v[c]), 25); \
        v[a] += (m[idx2] ^ 0x44) + v[b]; \
        v[d] = ROTR( v[d] ^ v[a], 16); \
        v[c] += v[d]; \
        v[b] = ROTR( v[b] ^ v[c], 11); \
}
*/

__device__ __forceinline__
void quark_blake512_compress(uint64_t *h, const uint64_t *block, const uint8_t ((*sigma)[16]), const uint64_t *u512, const int T0)
{
	uint64_t v[16];
	//uint64_t m[16];
/*
	#pragma unroll
	for(int i=0; i < 16; i++) {
		m[i] = cuda_swab64(block[i]);
	}
*/
/*
        for(int i=0; i < 16; i++) {
                m[i] = (block[i]);
        }
*/
	const uint64_t *m=block;
	//#pragma unroll 8
	for(int i=0; i < 8; i++)
		v[i] = h[i];

	v[ 8] = u512[0];
	v[ 9] = u512[1];
	v[10] = u512[2];
	v[11] = u512[3];
	v[12] = u512[4] ^ T0;
	v[13] = u512[5] ^ T0;
	v[14] = u512[6];
	v[15] = u512[7];


	#pragma unroll 16
	for(int i=0; i < 16; i++)
	{
		/* column step */
		G( 0, 4, 8, 12, 0 );
		G( 1, 5, 9, 13, 2 );
		G( 2, 6, 10, 14, 4 );
		G( 3, 7, 11, 15, 6 );
		/* diagonal step */
		G( 0, 5, 10, 15, 8 );
		G( 1, 6, 11, 12, 10 );
		G( 2, 7, 8, 13, 12 );
		G( 3, 4, 9, 14, 14 );
	}

	h[0] ^= v[0] ^ v[8];
	h[1] ^= v[1] ^ v[9];
	h[2] ^= v[2] ^ v[10];
	h[3] ^= v[3] ^ v[11];
	h[4] ^= v[4] ^ v[12];
	h[5] ^= v[5] ^ v[13];
	h[6] ^= v[6] ^ v[14];
	h[7] ^= v[7] ^ v[15];
}


#define TPB_128_B 128

__global__ __launch_bounds__(TPB_128_B, 3)
void quark_blake512_gpu_hash_128(uint32_t threads,  uint64_t *g_hash)
{
	uint32_t thread = (blockDim.x * blockIdx.x + threadIdx.x);

	if (thread < threads)
	{
		uint64_t *inpHash = &g_hash[thread<<3]; // hashPosition * 8

		// 128 Bytes
		uint64_t buf[16];

		// State
		uint64_t h[8] = {
			0x6a09e667f3bcc908ULL,
			0xbb67ae8584caa73bULL,
			0x3c6ef372fe94f82bULL,
			0xa54ff53a5f1d36f1ULL,
			0x510e527fade682d1ULL,
			0x9b05688c2b3e6c1fULL,
			0x1f83d9abfb41bd6bULL,
			0x5be0cd19137e2179ULL
		};


		uint2x4 *phash = (uint2x4*)&g_hash[thread<<3];
		uint2x4 *outpt = (uint2x4*)buf;
		outpt[0] = __ldg4(&phash[0]);
		outpt[1] = __ldg4(&phash[1]);

		// Message for first round
		#pragma unroll 8
		for (int i=0; i < 8; ++i){
			buf[i] = cuda_swab64(buf[i]);
			//buf[i+8]=0;
			}

		// Hash Pad
		buf[8]  = 0;
		buf[9]  = 0;
		buf[10] = 0;
		buf[11] = 0;
		buf[12] = 0;
		buf[13] = 0;
		buf[14] = 0;
		buf[15] = 0;
		// Ending round
		quark_blake512_compress(h, buf, c_sigma_big, c_u512, 1024);


  buf[0] = 0x8000000000000000;
  buf[1] = 0;
  buf[2] = 0;
  buf[3] = 0;
  buf[4] = 0;
  buf[5] = 0;
  buf[6] = 0;
  buf[7] = 0;
  buf[8] = 0;
  buf[9] = 0;
  buf[10] = 0;
  buf[11] = 0;
  buf[12] = 0;
  buf[13] = 1;
  buf[14] = 0;
  buf[15] = 0x400;

		quark_blake512_compress(h, buf, c_sigma_big, c_u512, 0);










		uint64_t *outHash = &g_hash[thread * 8U];
#pragma unroll 8
		for (int i=0; i < 8; i++) {
			outHash[i] = cuda_swab64(h[i]);
		}
	}
}


__host__
void quark_blake512_cpu_hash_128(int thr_id, uint32_t threads, uint32_t *d_outputHash)
{
		const uint32_t threadsperblock = TPB_128_B;
		dim3 grid((threads + threadsperblock-1)/threadsperblock);
		dim3 block(threadsperblock);
		quark_blake512_gpu_hash_128<<<grid, block>>>(threads,  (uint64_t*)d_outputHash);
}
