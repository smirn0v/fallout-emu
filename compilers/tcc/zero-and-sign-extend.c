#include <stdio.h>
#include <sys/types.h>


int main() {
    for(int16_t i = -20; i <= 20; i++) {
        uint32_t resultS = (int16_t)i;
	uint32_t resultZ = (uint16_t)i;
	printf("sign %02x\n",resultS);
        printf("zero %02x\n",resultZ);
    }
}
