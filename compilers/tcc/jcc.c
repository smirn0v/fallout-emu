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

#define TEST_SEGS
//#define LINUX_VM86_IOPL_FIX
//#define TEST_P4_FLAGS
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

#ifdef TEST_VM86
#include <asm/vm86.h>
#endif

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

#define __init_call	__attribute__ ((unused,__section__ ("initcall")))

#define CC_MASK (CC_C | CC_P | CC_Z | CC_S | CC_O | CC_A)

static inline long i2l(long v)
{
    return v;
}

#define TEST_JCC(JCC, v1, v2)\
{\
    int res;\
    asm("movl $1, %0\n\t"\
        "cmpl %2, %1\n\t"\
        "j" JCC " 1f\n\t"\
        "movl $0, %0\n\t"\
        "1:\n\t"\
        : "=&r" (res)\
        : "r" (v1), "r" (v2));\
    printf("%-10s %d\n", "j" JCC, res);\
\
    asm("movl $0, %0\n\t"\
        "cmpl %2, %1\n\t"\
        "set" JCC " %b0\n\t"\
        : "=&r" (res)\
        : "r" (v1), "r" (v2));\
    printf("%-10s %d\n", "set" JCC, res);\
 if (TEST_CMOV) {\
    long val = i2l(1);\
    long res = i2l(0x12345678);\
    asm("cmpl %2, %1\n\t"\
        "cmov" JCC " %3, %0\n\t"\
        : "=&r" (res)\
        : "r" (v1), "r" (v2), "m" (val), "0" (res));\
        printf("%-10s R=" FMTLX "\n", "cmov" JCC "l", res);\
 } \
}

/* various jump tests */
void test_jcc(void)
{
    TEST_JCC("ne", 1, 1);
    TEST_JCC("ne", 1, 0);

    TEST_JCC("e", 1, 1);
    TEST_JCC("e", 1, 0);

    TEST_JCC("l", 1, 1);
    TEST_JCC("l", 1, 0);
    TEST_JCC("l", 1, -1);

    TEST_JCC("le", 1, 1);
    TEST_JCC("le", 1, 0);
    TEST_JCC("le", 1, -1);

    TEST_JCC("ge", 1, 1);
    TEST_JCC("ge", 1, 0);
    TEST_JCC("ge", -1, 1);

    TEST_JCC("g", 1, 1);
    TEST_JCC("g", 1, 0);
    TEST_JCC("g", 1, -1);

    TEST_JCC("b", 1, 1);
    TEST_JCC("b", 1, 0);
    TEST_JCC("b", 1, -1);

    TEST_JCC("be", 1, 1);
    TEST_JCC("be", 1, 0);
    TEST_JCC("be", 1, -1);

    TEST_JCC("ae", 1, 1);
    TEST_JCC("ae", 1, 0);
    TEST_JCC("ae", 1, -1);

    TEST_JCC("a", 1, 1);
    TEST_JCC("a", 1, 0);
    TEST_JCC("a", 1, -1);


    TEST_JCC("p", 1, 1);
    TEST_JCC("p", 1, 0);

    TEST_JCC("np", 1, 1);
    TEST_JCC("np", 1, 0);

    TEST_JCC("o", 0x7fffffff, 0);
    TEST_JCC("o", 0x7fffffff, -1);

    TEST_JCC("no", 0x7fffffff, 0);
    TEST_JCC("no", 0x7fffffff, -1);

    TEST_JCC("s", 0, 1);
    TEST_JCC("s", 0, -1);
    TEST_JCC("s", 0, 0);

    TEST_JCC("ns", 0, 1);
    TEST_JCC("ns", 0, -1);
    TEST_JCC("ns", 0, 0);
}

int main(int argc, char **argv)
{
    test_jcc();
    return 0;
}
