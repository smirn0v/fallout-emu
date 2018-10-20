#include <stdio.h>

#define ROTATE_LEFT(x, n) (((x) << (n)) | ((x) >> (32 - (n))))
#define F(x, y, z) (((x) & (y)) | (~(x) & (z)))

int main() {
    for(int i = -20; i < 20; i++) {
        printf("%02x\n", ROTATE_LEFT(i,2));
        printf("%02x\n", ROTATE_LEFT(i,3));
        printf("%02x\n", ROTATE_LEFT(i,4));
        printf("%02x\n", ROTATE_LEFT(i,5));

        printf("%02x\n", F(i,1,2));
        printf("%02x\n", F(i,2,3));
        printf("%02x\n", F(i,3,4));
        printf("%02x\n", F(i,4,5));
        printf("%02x\n", F(i,5,6));
    }
}
