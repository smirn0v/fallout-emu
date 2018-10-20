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


static inline long i2l(long v)
{
    return v;
}


/**********************************************/

#define TEST_BCD(op, op0, cc_in, cc_mask)\
{\
    int res, flags;\
    res = op0;\
    flags = cc_in;\
    asm ("pushl %3\n\t"\
         "popf\n\t"\
         #op "\n\t"\
         "pushf\n\t"\
         "popl %1\n\t"\
        : "=&a" (res), "=&g" (flags)\
        : "0" (res), "1" (flags));\
    printf("%-10s A=%08x R=%08x CCIN=%04x CC=%04x\n",\
           #op, op0, res, cc_in & cc_mask, flags & cc_mask);\
}

void test_bcd(void)
{
    TEST_BCD(daa, 0x12340503, CC_A, (CC_C | CC_P | CC_Z | CC_S | CC_A));
    TEST_BCD(daa, 0x12340506, CC_A, (CC_C | CC_P | CC_Z | CC_S | CC_A));
    TEST_BCD(daa, 0x12340507, CC_A, (CC_C | CC_P | CC_Z | CC_S | CC_A));
    TEST_BCD(daa, 0x12340559, CC_A, (CC_C | CC_P | CC_Z | CC_S | CC_A));
    TEST_BCD(daa, 0x12340560, CC_A, (CC_C | CC_P | CC_Z | CC_S | CC_A));
    TEST_BCD(daa, 0x1234059f, CC_A, (CC_C | CC_P | CC_Z | CC_S | CC_A));
    TEST_BCD(daa, 0x123405a0, CC_A, (CC_C | CC_P | CC_Z | CC_S | CC_A));
    TEST_BCD(daa, 0x12340503, 0, (CC_C | CC_P | CC_Z | CC_S | CC_A));
    TEST_BCD(daa, 0x12340506, 0, (CC_C | CC_P | CC_Z | CC_S | CC_A));
    TEST_BCD(daa, 0x12340503, CC_C, (CC_C | CC_P | CC_Z | CC_S | CC_A));
    TEST_BCD(daa, 0x12340506, CC_C, (CC_C | CC_P | CC_Z | CC_S | CC_A));
    TEST_BCD(daa, 0x12340503, CC_C | CC_A, (CC_C | CC_P | CC_Z | CC_S | CC_A));
    TEST_BCD(daa, 0x12340506, CC_C | CC_A, (CC_C | CC_P | CC_Z | CC_S | CC_A));

    TEST_BCD(das, 0x12340503, CC_A, (CC_C | CC_P | CC_Z | CC_S | CC_A));
    TEST_BCD(das, 0x12340506, CC_A, (CC_C | CC_P | CC_Z | CC_S | CC_A));
    TEST_BCD(das, 0x12340507, CC_A, (CC_C | CC_P | CC_Z | CC_S | CC_A));
    TEST_BCD(das, 0x12340559, CC_A, (CC_C | CC_P | CC_Z | CC_S | CC_A));
    TEST_BCD(das, 0x12340560, CC_A, (CC_C | CC_P | CC_Z | CC_S | CC_A));
    TEST_BCD(das, 0x1234059f, CC_A, (CC_C | CC_P | CC_Z | CC_S | CC_A));
    TEST_BCD(das, 0x123405a0, CC_A, (CC_C | CC_P | CC_Z | CC_S | CC_A));
    TEST_BCD(das, 0x12340503, 0, (CC_C | CC_P | CC_Z | CC_S | CC_A));
    TEST_BCD(das, 0x12340506, 0, (CC_C | CC_P | CC_Z | CC_S | CC_A));
    TEST_BCD(das, 0x12340503, CC_C, (CC_C | CC_P | CC_Z | CC_S | CC_A));
    TEST_BCD(das, 0x12340506, CC_C, (CC_C | CC_P | CC_Z | CC_S | CC_A));
    TEST_BCD(das, 0x12340503, CC_C | CC_A, (CC_C | CC_P | CC_Z | CC_S | CC_A));
    TEST_BCD(das, 0x12340506, CC_C | CC_A, (CC_C | CC_P | CC_Z | CC_S | CC_A));

    TEST_BCD(aaa, 0x12340205, CC_A, (CC_C | CC_A));
    TEST_BCD(aaa, 0x12340306, CC_A, (CC_C | CC_A));
    TEST_BCD(aaa, 0x1234040a, CC_A, (CC_C | CC_A));
    TEST_BCD(aaa, 0x123405fa, CC_A, (CC_C | CC_A));
    TEST_BCD(aaa, 0x12340205, 0, (CC_C | CC_A));
    TEST_BCD(aaa, 0x12340306, 0, (CC_C | CC_A));
    TEST_BCD(aaa, 0x1234040a, 0, (CC_C | CC_A));
    TEST_BCD(aaa, 0x123405fa, 0, (CC_C | CC_A));

    TEST_BCD(aas, 0x12340205, CC_A, (CC_C | CC_A));
    TEST_BCD(aas, 0x12340306, CC_A, (CC_C | CC_A));
    TEST_BCD(aas, 0x1234040a, CC_A, (CC_C | CC_A));
    TEST_BCD(aas, 0x123405fa, CC_A, (CC_C | CC_A));
    TEST_BCD(aas, 0x12340205, 0, (CC_C | CC_A));
    TEST_BCD(aas, 0x12340306, 0, (CC_C | CC_A));
    TEST_BCD(aas, 0x1234040a, 0, (CC_C | CC_A));
    TEST_BCD(aas, 0x123405fa, 0, (CC_C | CC_A));

    TEST_BCD(aam, 0x12340547, CC_A, ( CC_P | CC_Z | CC_S ));
    TEST_BCD(aad, 0x12340407, CC_A, ( CC_P | CC_Z | CC_S));
}

int main(int argc, char **argv)
{
    test_bcd();
    return 0;
}
