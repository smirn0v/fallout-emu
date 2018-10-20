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
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <inttypes.h>
#include <math.h>
#include <signal.h>
#include <setjmp.h>
#include <errno.h>

#define TEST_SEGS

#undef TEST_SSE
#define TEST_CMOV  1
#define TEST_FCOMI 1

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

#define __init_call	__attribute__ ((unused,__section__ ("initcall")))


#define TEST(N) \
    asm("fld" #N : "=t" (a)); \
    printf("fld" #N "= %f\n", a);

void test_fconst(void)
{
    double a;
    TEST(1);
    TEST(l2t);
    TEST(l2e);
    TEST(pi);
    TEST(lg2);
    TEST(ln2);
    TEST(z);
}



void test_floats(void)
{
    test_fconst();
}

int main(int argc, char **argv)
{
    test_floats();
    return 0;
}
