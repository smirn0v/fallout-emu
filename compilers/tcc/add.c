#include <stdio.h>
#include <sys/types.h>

void exec_op(long arg1, long arg2) {
    short flagsVector = 0;
    asm(\
            "mov %3,%%edx\n"\
            "mov %2,%%eax\n"\
            "addl %%edx,%%eax\n"\
            "pushf\n"\
            "mov %%eax,%1\n"\
            "popw %%ax\n"\
            "mov %%ax,%0\n"\
            :"=r"(flagsVector),"=r"(arg1)\
            :"1"(arg1), "g"(arg2)\
            : "eax","edx");
    printf("%x ",arg1);
    printf("%x\n",flagsVector&0x8d5);
}

int main() {
    exec_op(0x12345678, 0x812FADA);
    exec_op(0x12341, 0x12341);
    exec_op(0x12341, -0x12341);
    exec_op(0xffffffff, 0);
    exec_op(0xffffffff, -1);
    exec_op(0xffffffff, 1);
    exec_op(0xffffffff, 2);
    exec_op(0x7fffffff, 0);
    exec_op(0x7fffffff, 1);
    exec_op(0x7fffffff, -1);
    exec_op(0x80000000, -1);
    exec_op(0x80000000, 1);
    exec_op(0x80000000, -2);
    exec_op(0x12347fff, 0);
    exec_op(0x12347fff, 1);
    exec_op(0x12347fff, -1);
    exec_op(0x12348000, -1);
    exec_op(0x12348000, 1);
    exec_op(0x12348000, -2);
    exec_op(0x12347f7f, 0);
    exec_op(0x12347f7f, 1);
    exec_op(0x12347f7f, -1);
    exec_op(0x12348080, -1);
    exec_op(0x12348080, 1);
    exec_op(0x12348080, -2);
    return 0;
}
