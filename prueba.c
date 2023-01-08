#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void prueba(int *a) {
    for (int i = 0; i < 4; i++)
        a[i] = 8;

}

int main() {
    int n = 6, m = 4;
    int *matrix = (int*) malloc(sizeof(int) * n * m);
    int count = 0;

    memset(matrix, 0, m * n);

    matrix[1 * m + 0] = 4;
    matrix[1 * m + 1] = 2;
    matrix[1 * m + 2] = 1;
    matrix[1 * m + 3] = 3;

    for (int i = 0; i<n; i++) {
        for (int j = 0; j<m; j++)
            printf("%d ", matrix[i*m+j]);
        printf("\n");
    }
    
    printf("\n");
    printf("\n");
    
    for (int i = 0; i<n; i++) {
        for (int j = 0; j<m; j++)
            printf("%p ", matrix+i*m+j);
        printf("\n");
    }
    
    printf("\n");
    printf("\n");
    
    for (int i = 0; i<n; i++) {
        for (int j = 0; j<m; j++)
            printf("%p ", &matrix[i*m+j]);
        printf("\n");
    }
    
    printf("\n");
    printf("\n");
    return 0;
}