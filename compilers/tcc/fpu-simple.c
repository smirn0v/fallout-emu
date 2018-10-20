#include <stdio.h>

int main() {

    float a = 4.5f;
    float b = 1.5f;
    float c = 0.3f;

    double ad = 4.5f;
    double bd = 1.5f;
    double cd = 0.3f;

    printf("a = ");printf("%f\n", a);
    printf("a + b = ");printf("%f\n", a+b);
    printf("b - c = ");printf("%f\n", b-c);
    printf("a * b = ");printf("%f\n", a*b);
    printf("a / c = ");printf("%f\n", a/c);

    printf("a = ");printf("%f\n", ad);
    printf("a + b = ");printf("%f\n", ad+bd);
    printf("b - c = ");printf("%f\n", bd-cd);
    printf("a * b = ");printf("%f\n", ad*bd);
    printf("a / c = ");printf("%f\n", ad/cd);
    
    return 0;
}
