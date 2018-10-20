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
    exec_op(0xffffffff, 0);
    return 0;
}
