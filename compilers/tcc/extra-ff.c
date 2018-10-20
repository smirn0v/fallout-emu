#include <stdio.h>

int main() {
    asm("pushw $0x84");
    printf("%x");
    
    return 0;
}
