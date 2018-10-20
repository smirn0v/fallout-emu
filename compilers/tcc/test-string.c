#include <stdio.h>
#include <inttypes.h>

uint8_t str_buffer[4096];
#define FMTLX "%08lx"
static inline long i2l(long v)
{
        return v;
}

#define TEST_STRING1(OP, size, DF, REP)\
{\
    long esi, edi, eax, ecx, eflags;\
    \
    esi = (long)(str_buffer + sizeof(str_buffer) / 2);\
    edi = (long)(str_buffer + sizeof(str_buffer) / 2) + 16;\
    eax = i2l(0x12345678);\
    ecx = 17;\
    \
    asm volatile ("push $0\n\t"\
            "popf\n\t"\
            DF "\n\t"\
            REP #OP size "\n\t"\
            "cld\n\t"\
            "pushf\n\t"\
            "popl %4\n\t"\
            : "=S" (esi), "=D" (edi), "=a" (eax), "=c" (ecx), "=g" (eflags)\
            : "0" (esi), "1" (edi), "2" (eax), "3" (ecx));\
    printf(REP #OP size " ");\
    printf("ESI=" FMTLX " ",esi);\
    printf("EDI=" FMTLX " ",edi);\
    printf("EAX=" FMTLX " ",eax);\
    printf("ECX=" FMTLX " ",ecx);\
    printf("EFL=%04x\n", (int)(eflags & (0x8d5)));\
    for(int c=0;c<sizeof(str_buffer);c++)\
        printf("%x.",str_buffer[c]);\
    printf("\n");\
}

#define TEST_STRING(OP, REP)\
    TEST_STRING1(OP, "b", "", REP);\
TEST_STRING1(OP, "w", "", REP);\
TEST_STRING1(OP, "l", "", REP);\
TEST_STRING1(OP, "b", "std", REP);\
TEST_STRING1(OP, "w", "std", REP);\
TEST_STRING1(OP, "l", "std", REP);

void test_string(void)
{
    int i;
    for(i = 0;i < sizeof(str_buffer); i++)
        str_buffer[i] = i + 0x56;
//    
//    long esi, edi, eax, ecx, eflags; 
//    esi = (long)(str_buffer + sizeof(str_buffer) / 2); 
//    edi = (long)(str_buffer + sizeof(str_buffer) / 2) + 16; 
//    eax = i2l(0x12345678); 
//    ecx = 17; 
//    asm volatile ("push $0\n"
//    "popf\n" 
//    "stosb\n" 
//    "cld\n" 
//    "pushf\n" 
//    "popl %4\n" 
//    : "=&S" (esi), "=&D" (edi), "=&a" (eax), "=&c" (ecx), "=&g" (eflags) 
//    : "0" (esi), "1" (edi), "2" (eax), "3" (ecx)); 
//    
//    printf("%-10s ESI=" FMTLX " EDI=" FMTLX " EAX=" FMTLX " ECX=" FMTLX " EFL=%04x\n", "" "stos" "b", esi, edi, eax, ecx, (int)(eflags &0x8d5));

    TEST_STRING(stos, "");
    TEST_STRING(stos, "rep ");
    TEST_STRING(lods, ""); /* to verify stos */
    TEST_STRING(lods, "rep ");
    TEST_STRING(movs, "");
    TEST_STRING(movs, "rep ");
    TEST_STRING(lods, ""); /* to verify stos */

    /* XXX: better tests */
    TEST_STRING(scas, "");
    TEST_STRING(scas, "repz ");
    TEST_STRING(scas, "repnz ");
    TEST_STRING(cmps, "");
    TEST_STRING(cmps, "repz ");
    TEST_STRING(cmps, "repnz ");
}


int main() {
    test_string();
    return 0;
}
