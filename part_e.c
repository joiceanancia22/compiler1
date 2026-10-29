#include <stdio.h>
#include <string.h>

int main() {
    char line[100], a[20], b[20], c[20], d[20], e[20];
    int reg = 0;

    printf("--- PART E: TARGET ASSEMBLY CODE ---\n");
    while (fgets(line, sizeof(line), stdin)) {
        line[strcspn(line, "\r\n")] = 0;
        if (line[0] == '-' || strlen(line) == 0) continue;
        int cnt = sscanf(line, "%s %s %s %s %s", a, b, c, d, e);
        if (cnt <= 0) continue;

        if (a[strlen(a)-1] == ':') {
            printf("%s\n", a);
        } else if (strcmp(a, "goto") == 0) {
            printf("\tJMP %s\n", b);
        } else if (strcmp(a, "ifFalse") == 0) {
            printf("\tCMP %s, 0\n\tJE %s\n", b, d);
        } else if (strcmp(a, "return") == 0) {
            printf("\tMOV R0, %s\n\tRET\n", b);
        } else if (cnt == 3 && strcmp(b, "=") == 0) {
            printf("\tMOV R%d, %s\n\tMOV %s, R%d\n", reg, c, a, reg);
            reg = (reg + 1) % 4;
        } else if (cnt == 4 && strcmp(b, "=") == 0) {
            printf("\tMOV R%d, %s\n", reg, d);
            printf("\t%s R%d\n", strcmp(c, "-") == 0 ? "NEG" : "NOT", reg);
            printf("\tMOV %s, R%d\n", a, reg);
            reg = (reg + 1) % 4;
        } else if (cnt == 5 && strcmp(b, "=") == 0) {
            printf("\tMOV R%d, %s\n", reg, c);
            if      (strcmp(d, "+") == 0) printf("\tADD R%d, %s\n", reg, e);
            else if (strcmp(d, "-") == 0) printf("\tSUB R%d, %s\n", reg, e);
            else if (strcmp(d, "*") == 0) printf("\tMUL R%d, %s\n", reg, e);
            else if (strcmp(d, "/") == 0) printf("\tDIV R%d, %s\n", reg, e);
            else                          printf("\tCMP R%d, %s\n", reg, e);
            printf("\tMOV %s, R%d\n", a, reg);
            reg = (reg + 1) % 4;
        }
    }
    return 0;
}
