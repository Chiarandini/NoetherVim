#include <stdio.h>

int add(int a, int b) {
    int sum = a + b;
    return sum;
}

int main(void) {
    printf("%d\n", add(40, 2));
    return 0;
}
