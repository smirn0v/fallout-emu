#include <stdio.h>

int fib(n)
{
	if (n <= 2)
		return 1;
	else
		return fib(n-1) + fib(n-2);
}

int main(int argc, char **argv) 
{
	printf("fib(15) = %d\n", fib(15));
	return 0;
}
