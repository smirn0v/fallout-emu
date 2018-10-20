/*
 *  x86 CPU test
 *
 *  Copyright (c) 2003 Fabrice Bellard
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, see <http://www.gnu.org/licenses/>.
 */
#define _GNU_SOURCE
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <inttypes.h>
#include <math.h>
#include <signal.h>
#include <setjmp.h>
#include <errno.h>

#ifdef __SSE__
#define TEST_SSE
#define TEST_CMOV  1
#define TEST_FCOMI 1
#else
#undef TEST_SSE
#define TEST_CMOV  1
#define TEST_FCOMI 1
#endif

#define FMT64X "%016" PRIx64
#define FMTLX "%08lx"
#define X86_64_ONLY(x)

#define xglue(x, y) x ## y
#define glue(x, y) xglue(x, y)
#define stringify(s)	tostring(s)
#define tostring(s)	#s

#define CC_C   	0x0001
#define CC_P 	0x0004
#define CC_A	0x0010
#define CC_Z	0x0040
#define CC_S    0x0080
#define CC_O    0x0800

#define CC_MASK (CC_C | CC_P | CC_Z | CC_S | CC_O | CC_A)

static inline long i2l(long v)
{
    return v;
}

#define OP mul
#include "test-i386-muldiv.h"

#define OP imul
#include "test-i386-muldiv.h"

void test_imulw2(long op0, long op1)
{
    long res, s1, s0, flags;
    s0 = op0;
    s1 = op1;
    res = s0;
    flags = 0;
    asm volatile ("pushl %4\n\t"
         "popf\n\t"
         "imulw %2, %0\n\t"
         "pushf\n\t"
         "popl %1\n\t"
         : "=&q" (res), "=&g" (flags)
         : "q" (s1), "0" (res), "1" (flags));
    printf("%-10s A=" FMTLX " B=" FMTLX " R=" FMTLX " CC=%04lx\n",
           "imulw", s0, s1, res, flags & CC_MASK);
}

void test_imull2(long op0, long op1)
{
    long res, s1, s0, flags;
    s0 = op0;
    s1 = op1;
    res = s0;
    flags = 0;
    asm volatile ("pushl %4\n\t"
         "popf\n\t"
         "imull %2, %0\n\t"
         "pushf\n\t"
         "popl %1\n\t"
         : "=&q" (res), "=&g" (flags)
         : "q" (s1), "0" (res), "1" (flags));
    printf("%-10s A=" FMTLX " B=" FMTLX " R=" FMTLX " CC=%04lx\n",
           "imull", s0, s1, res, flags & CC_MASK);
}

#define TEST_IMUL_IM(size, rsize, op0, op1)\
{\
    long res, flags, s1;\
    flags = 0;\
    res = 0;\
    s1 = op1;\
    asm volatile ("pushl %3\n\t"\
         "popf\n\t"\
         "imul" size " $" #op0 ", %2, %0\n\t" \
         "pushf\n\t"\
         "popl %1\n\t"\
         : "=&r" (res), "=&g" (flags)\
         : "r" (s1), "1" (flags), "0" (res));\
    printf("%-10s A=" FMTLX " B=" FMTLX " R=" FMTLX " CC=%04lx\n",\
           "imul" size " im", (long)op0, (long)op1, res, flags & CC_MASK);\
}


#undef CC_MASK
#define CC_MASK (0)

#define OP div
#include "test-i386-muldiv.h"

#define OP idiv
#include "test-i386-muldiv.h"

void test_mul(void)
{
    test_imulb(0x1234561d, 4);
    test_imulb(3, -4);
    test_imulb(0x80, 0x80);
    test_imulb(0x10, 0x10);

    test_imulw(0, 0x1234001d, 45);
    test_imulw(0, 23, -45);
    test_imulw(0, 0x8000, 0x8000);
    test_imulw(0, 0x100, 0x100);

    test_imull(0, 0x1234001d, 45);
    test_imull(0, 23, -45);
    test_imull(0, 0x80000000, 0x80000000);
    test_imull(0, 0x10000, 0x10000);

    test_mulb(0x1234561d, 4);
    test_mulb(3, -4);
    test_mulb(0x80, 0x80);
    test_mulb(0x10, 0x10);

    test_mulw(0, 0x1234001d, 45);
    test_mulw(0, 23, -45);
    test_mulw(0, 0x8000, 0x8000);
    test_mulw(0, 0x100, 0x100);

    test_mull(0, 0x1234001d, 45);
    test_mull(0, 23, -45);
    test_mull(0, 0x80000000, 0x80000000);
    test_mull(0, 0x10000, 0x10000);

    test_imulw2(0x1234001d, 45);
    test_imulw2(23, -45);
    test_imulw2(0x8000, 0x8000);
    test_imulw2(0x100, 0x100);

    test_imull2(0x1234001d, 45);
    test_imull2(23, -45);
    test_imull2(0x80000000, 0x80000000);
    test_imull2(0x10000, 0x10000);

    TEST_IMUL_IM("w", "w", 45, 0x1234);
    TEST_IMUL_IM("w", "w", -45, 23);
    TEST_IMUL_IM("w", "w", 0x8000, 0x80000000);
    TEST_IMUL_IM("w", "w", 0x7fff, 0x1000);

    TEST_IMUL_IM("l", "", 45, 0x1234);
    TEST_IMUL_IM("l", "", -45, 23);
    TEST_IMUL_IM("l", "", 0x8000, 0x80000000);
    TEST_IMUL_IM("l", "", 0x7fff, 0x1000);

    test_idivb(0x12341678, 0x127e);
    test_idivb(0x43210123, -5);
    test_idivb(0x12340004, -1);

    test_idivw(0, 0x12345678, 12347);
    test_idivw(0, -23223, -45);
    test_idivw(0, 0x12348000, -1);
    test_idivw(0x12343, 0x12345678, 0x81238567);

    test_idivl(0, 0x12345678, 12347);
    test_idivl(0, -233223, -45);
    test_idivl(0, 0x80000000, -1);
    test_idivl(0x12343, 0x12345678, 0x81234567);

    test_divb(0x12341678, 0x127e);
    test_divb(0x43210123, -5);
    test_divb(0x12340004, -1);

    test_divw(0, 0x12345678, 12347);
    test_divw(0, -23223, -45);
    test_divw(0, 0x12348000, -1);
    test_divw(0x12343, 0x12345678, 0x81238567);

    test_divl(0, 0x12345678, 12347);
    test_divl(0, -233223, -45);
    test_divl(0, 0x80000000, -1);
    test_divl(0x12343, 0x12345678, 0x81234567);

}

int main(int argc, char **argv)
{
    test_mul();
    return 0;
}
