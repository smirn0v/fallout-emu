#include <stdio.h>

int function4(char i, short j, int k) {
    printf("%d\n",i);
    printf("%d\n",j);
    printf("%d\n",k);
    return 12;
}

short function3(int i, short j, int k) {
    printf("%d\n",function4(i,j,k));
    return 11;
}

char function2(int i, char j) {
    printf("%d\n",i);
    printf("%d\n",function3(6,7,8));
    printf("%d\n",j);
    return 10;
}

int function1(int i) {
    printf("%d\n",function2(1,2));
    printf("%d\n",function3(3,4,13));
    return 9;
}

int main() {
    printf("%d\n",function1(5));
    return 0;
}
