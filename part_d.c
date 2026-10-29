#include <stdio.h>
#include <string.h>
#include <ctype.h>

typedef struct {
    char op[15], arg1[20], arg2[20], res[20], raw[100];
    int hoisted;
} Quad;

Quad q[300];
int n = 0;

void parse_line(char *line) {
    char a[20], b[20], c[20], d[20], e[20];
    int cnt = sscanf(line, "%s %s %s %s %s", a, b, c, d, e);
    if (cnt <= 0 || line[0] == '-') return;

    strcpy(q[n].raw, line);
    q[n].hoisted = 0;
    q[n].op[0] = q[n].arg1[0] = q[n].arg2[0] = q[n].res[0] = '\0';

    if (a[strlen(a)-1] == ':') {
        strcpy(q[n].op, "label"); a[strlen(a)-1] = '\0'; strcpy(q[n].res, a);
    } else if (strcmp(a, "goto") == 0) {
        strcpy(q[n].op, "goto"); strcpy(q[n].res, b);
    } else if (strcmp(a, "ifFalse") == 0) {
        strcpy(q[n].op, "ifFalse"); strcpy(q[n].arg1, b); strcpy(q[n].res, d);
    } else if (strcmp(a, "return") == 0) {
        strcpy(q[n].op, "return"); strcpy(q[n].arg1, b);
    } else if (cnt == 3 && strcmp(b, "=") == 0) {
        strcpy(q[n].op, "="); strcpy(q[n].res, a); strcpy(q[n].arg1, c);
    } else if (cnt == 4 && strcmp(b, "=") == 0) {
        strcpy(q[n].op, c); strcpy(q[n].res, a); strcpy(q[n].arg1, d);
    } else if (cnt == 5 && strcmp(b, "=") == 0) {
        strcpy(q[n].op, d); strcpy(q[n].res, a); strcpy(q[n].arg1, c); strcpy(q[n].arg2, e);
    }
    n++;
}

int is_cond_var(char *v, int s, int e) {
    for (int i = s; i <= e; i++)
        if (strcmp(q[i].op, "ifFalse") == 0 && strcmp(q[i].arg1, v) == 0) return 1;
    return 0;
}

int is_mod(char *v, int s, int e, int self) {
    if (v[0] == '\0' || isdigit(v[0])) return 0;
    for (int i = s; i <= e; i++) {
        /* Treat the primary loop condition variable (e.g., 'm' in t2 = m < t1) as loop-varying */
        if (is_cond_var(q[i].res, s, e) && strcmp(q[i].arg1, v) == 0) return 1;
        if (i != self && !q[i].hoisted && strcmp(q[i].op, "label") != 0 &&
            strcmp(q[i].op, "goto") != 0 && strcmp(q[i].op, "ifFalse") != 0 &&
            strcmp(q[i].res, v) == 0) return 1;
    }
    return 0;
}

int main() {
    char line[100];
    while (fgets(line, sizeof(line), stdin)) {
        line[strcspn(line, "\r\n")] = 0;
        parse_line(line);
    }

    printf("--- PART D: OPTIMIZED TAC (CODE MOTION) ---\n");
    for (int i = 0; i < n; i++) {
        int end = -1;
        if (strcmp(q[i].op, "label") == 0) {
            for (int j = n - 1; j > i; j--)
                if (strcmp(q[j].op, "goto") == 0 && strcmp(q[j].res, q[i].res) == 0) { end = j; break; }
        }
        if (end != -1) {
            int chg = 1;
            while (chg) {
                chg = 0;
                for (int k = i + 1; k < end; k++) {
                    if (q[k].hoisted || q[k].res[0] == '\0') continue;
                    if (strcmp(q[k].op, "label") == 0 || strcmp(q[k].op, "goto") == 0 ||
                        strcmp(q[k].op, "ifFalse") == 0 || strcmp(q[k].op, "return") == 0) continue;
                    if (is_cond_var(q[k].res, i, end)) continue;

                    if (!is_mod(q[k].arg1, i, end, k) && !is_mod(q[k].arg2, i, end, k) && !is_mod(q[k].res, i, end, k)) {
                        q[k].hoisted = 1;
                        printf("%s\n", q[k].raw);
                        chg = 1;
                    }
                }
            }
        }
        if (!q[i].hoisted) printf("%s\n", q[i].raw);
    }
    return 0;
}