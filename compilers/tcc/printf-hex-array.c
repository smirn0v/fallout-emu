#include <stdio.h>
#include <sys/types.h>
int main() {
 char array[] = {0xaa, 0xbb, 0xcc, 0xdd, 0xee};
 int i = 0;
 for(i = 0; i < 5; i++) {
     printf("%02x",(uint8_t)array[i]);
 }
 printf("\n");
 return 0;
}