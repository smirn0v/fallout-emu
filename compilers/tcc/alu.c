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

#if !defined(__x86_64__)
//#define TEST_VM86
#define TEST_SEGS
#endif
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

#if defined(__x86_64__)
#define FMT64X "%016lx"
#define FMTLX "%016lx"
#define X86_64_ONLY(x) x
#else
#define FMT64X "%016" PRIx64
#define FMTLX "%08lx"
#define X86_64_ONLY(x)
#endif

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

#define OP add
#include "alu-i386.h"

#define OP sub
#include "alu-i386.h"

#define OP xor
#include "alu-i386.h"

#define OP and
#include "alu-i386.h"

#define OP or
#include "alu-i386.h"

#define OP cmp
#include "alu-i386.h"

#define OP adc
#define OP_CC
#include "alu-i386.h"

#define OP sbb
#define OP_CC
#include "alu-i386.h"

#define OP inc
#define OP_CC
#define OP1
#include "alu-i386.h"

#define OP dec
#define OP_CC
#define OP1
#include "alu-i386.h"

#define OP neg
#define OP_CC
#define OP1
#include "alu-i386.h"

#define OP not
#define OP_CC
#define OP1
#include "alu-i386.h"

#undef CC_MASK
#define CC_MASK (CC_C | CC_P | CC_Z | CC_S | CC_O)
extern void *__start_initcall;
extern void *__stop_initcall;

int main(int argc, char **argv)
{
    void **ptr;
    void (*func)(void);

    ptr = &__start_initcall;
    while (ptr != &__stop_initcall) {
        func = *ptr++;
        func();
    }
    return 0;
}
