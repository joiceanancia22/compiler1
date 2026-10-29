
%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <limits.h>

int yylex(void);
void yyerror(const char *s);
char *dupstr(const char *s);

typedef struct {
    char d[80], a[80], b[80];
    char op;
} Ins;

Ins q[200];
int n = 0, tmp = 0, cut = 0;
int hoist[200] = {0};
char *lhs, *rhs, *rel;

int isnum(const char *s)
{
    if (!*s) return 0;

    for (; *s; s++)
        if (!isdigit((unsigned char)*s))
            return 0;

    return 1;
}

void emit(char *d, char *a, char op, char *b)
{
    if (n >= 200) {
        fprintf(stderr, "Too many instructions\n");
        exit(1);
    }

    snprintf(q[n].d, 80, "%s", d);
    snprintf(q[n].a, 80, "%s", a);
    snprintf(q[n].b, 80, "%s", b);
    q[n].op = op;
    n++;
}

char *calc(char *a, char op, char *b)
{
    char t[40];

    sprintf(t, "__tmp%d", ++tmp);
    emit(t, a, op, b);

    return dupstr(t);
}

void show(Ins p)
{
    if (p.op == '=')
        printf("%s = %s\n", p.d, p.a);
    else
        printf("%s = %s %c %s\n",
               p.d, p.a, p.op, p.b);
}

void machine(Ins p)
{
    printf("MOV R0, %s\n", p.a);

    if (p.op != '=') {
        const char *op =
            p.op == '+' ? "ADD" :
            p.op == '-' ? "SUB" :
            p.op == '*' ? "MUL" : "DIV";

        printf("%s R0, %s\n", op, p.b);
    }

    printf("STORE %s, R0\n", p.d);
}

int assigned(const char *v)
{
    for (int i = 0; i < n; i++) {
        if (!strcmp(v, q[i].d) &&
            strncmp(q[i].d, "__tmp", 5))
            return 1;
    }

    return 0;
}

int safe(const char *v)
{
    if (isnum(v)) return 1;

    for (int i = 0; i < n; i++) {
        if (!strcmp(v, q[i].d))
            return hoist[i];
    }

    return !assigned(v);
}

void fold(void)
{
    for (int i = 0; i < n; i++) {
        Ins *p = &q[i];

        if (p->op == '=' ||
            !isnum(p->a) || !isnum(p->b))
            continue;

        long a = atol(p->a);
        long b = atol(p->b);
        long v;

        if (p->op == '+') {
            if (__builtin_add_overflow(a, b, &v)) continue;
        }
        else if (p->op == '-') {
            if (__builtin_sub_overflow(a, b, &v)) continue;
        }
        else if (p->op == '*') {
            if (__builtin_mul_overflow(a, b, &v)) continue;
        }
        else if (p->op == '/') {
            if (!b || (a == LONG_MIN && b == -1)) continue;
            v = a / b;
        }
        else {
            continue;
        }

        snprintf(p->a, 80, "%ld", v);
        p->op = '=';
        p->b[0] = '\0';
    }
}

const char *branch(void)
{
    if (!strcmp(rel, "<"))  return "JL";
    if (!strcmp(rel, ">"))  return "JG";
    if (!strcmp(rel, "<=")) return "JLE";
    if (!strcmp(rel, ">=")) return "JGE";
    if (!strcmp(rel, "==")) return "JE";
    return "JNE";
}

void generate(void)
{
    printf("\n--- PART (b): SYNTAX ---\n");
    printf("Syntax Correct\n");

    printf("\n--- PART (c): THREE ADDRESS CODE ---\n");
    printf("L1:\n");

    for (int i = 0; i < n; i++)
        show(q[i]);

    printf("if %s %s %s goto L1\n", lhs, rel, rhs);
    printf("L2:\n");

    fold();

    /* Move only loop-invariant temporary expressions */
    for (int i = 0; i < cut; i++) {
        if (!strncmp(q[i].d, "__tmp", 5) &&
            q[i].op != '/') {

            hoist[i] = safe(q[i].a) &&
                (q[i].op == '=' || safe(q[i].b));
        }
    }

    printf("\n--- PART (d): OPTIMIZED TAC ---\n");

    for (int i = 0; i < cut; i++)
        if (hoist[i]) show(q[i]);

    printf("L1:\n");

    for (int i = 0; i < cut; i++)
        if (!hoist[i]) show(q[i]);

    for (int i = cut; i < n; i++)
        show(q[i]);

    printf("if %s %s %s goto L1\n", lhs, rel, rhs);
    printf("L2:\n");

    printf("\n--- PART (e): TARGET CODE ---\n");

    for (int i = 0; i < cut; i++)
        if (hoist[i]) machine(q[i]);

    printf("L1:\n");

    for (int i = 0; i < cut; i++)
        if (!hoist[i]) machine(q[i]);

    for (int i = cut; i < n; i++)
        machine(q[i]);

    printf("MOV R0, %s\n", lhs);
    printf("CMP R0, %s\n", rhs);
    printf("%s L1\n", branch());
    printf("L2:\n");

    printf("\n--- PART (f): INTEGRATION SUCCESSFUL ---\n");
}
%}

%union {
    char *s;
}

%token DO WHILE
%token <s> ID NUM REL
%type <s> expr term atom

%%

program:
    DO '{' stmts '}'
    {
        cut = n;
    }
    WHILE '(' expr REL expr ')' ';'
    {
        lhs = $8;
        rel = $9;
        rhs = $10;
        generate();
    }
    ;

stmts:
      /* empty */
    | stmts ID '=' expr ';'
    {
        emit($2, $4, '=', "");
    }
    ;

expr:
      expr '+' term { $$ = calc($1, '+', $3); }
    | expr '-' term { $$ = calc($1, '-', $3); }
    | term          { $$ = $1; }
    ;

term:
      term '*' atom { $$ = calc($1, '*', $3); }
    | term '/' atom { $$ = calc($1, '/', $3); }
    | atom          { $$ = $1; }
    ;

atom:
      ID             { $$ = $1; }
    | NUM            { $$ = $1; }
    | '(' expr ')'   { $$ = $2; }
    ;

%%

void yyerror(const char *s)
{
    fprintf(stderr, "Syntax Error: %s\n", s);
}

int main(void)
{
    printf("--- PART (a): TOKENS ---\n");
    return yyparse();
}
