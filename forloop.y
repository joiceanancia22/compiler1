
%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

int yylex(void);
void yyerror(const char *s);
char *dupstr(const char *s);

typedef struct {
    char d[80], a[80], b[80], op;
} Ins;

Ins q[200];
int n = 0, tmp = 0;
int initEnd, condEnd, stepEnd;
int hoist[200] = {0};
char *lhs, *rhs, *rel;

/* Check for a number */
int isnum(const char *s)
{
    if (!*s) return 0;

    for (; *s; s++)
        if (!isdigit((unsigned char)*s))
            return 0;

    return 1;
}

/* Add a TAC instruction */
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

/* Generate a temporary variable */
char *calc(char *a, char op, char *b)
{
    char t[40];

    sprintf(t, "__tmp%d", ++tmp);
    emit(t, a, op, b);

    return dupstr(t);
}

/* Print TAC */
void show(Ins p)
{
    if (p.op == '=')
        printf("%s = %s\n", p.d, p.a);
    else
        printf("%s = %s %c %s\n",
               p.d, p.a, p.op, p.b);
}

/* Generate target instructions */
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

/* Check whether variable changes in the loop */
int changed(const char *v)
{
    for (int i = condEnd; i < n; i++)
        if (!strcmp(v, q[i].d))
            return 1;

    return 0;
}

/* Check if an operand is loop-invariant */
int safe(const char *v)
{
    if (isnum(v)) return 1;

    for (int i = 0; i < n; i++) {
        if (!strcmp(v, q[i].d) &&
            !strncmp(v, "__tmp", 5)) {

            if (i < initEnd) return 1;
            if (i >= stepEnd) return hoist[i];
            return 0;
        }
    }

    return !changed(v);
}

/* Inverse branch instruction */
const char *inverse(void)
{
    if (!strcmp(rel, "<"))  return "JGE";
    if (!strcmp(rel, ">"))  return "JLE";
    if (!strcmp(rel, "<=")) return "JG";
    if (!strcmp(rel, ">=")) return "JL";
    if (!strcmp(rel, "==")) return "JNE";
    return "JE";
}

/* Display selected TAC instructions */
void printRange(int a, int b, int moved)
{
    for (int i = a; i < b; i++)
        if (hoist[i] == moved)
            show(q[i]);
}

/* Display target instructions */
void targetRange(int a, int b, int moved)
{
    for (int i = a; i < b; i++)
        if (hoist[i] == moved)
            machine(q[i]);
}

/* Constant folding */
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

        if (p->op == '+') v = a + b;
        else if (p->op == '-') v = a - b;
        else if (p->op == '*') v = a * b;
        else if (p->op == '/' && b) v = a / b;
        else continue;

        snprintf(p->a, 80, "%ld", v);
        p->op = '=';
        p->b[0] = '\0';
    }
}

/* Generate TAC, optimized TAC and target code */
void generate(void)
{
    printf("\n--- PART (b): SYNTAX ---\n");
    printf("Syntax Correct\n");

    printf("\n--- PART (c): THREE ADDRESS CODE ---\n");

    for (int i = 0; i < initEnd; i++)
        show(q[i]);

    printf("L1:\n");

    for (int i = initEnd; i < condEnd; i++)
        show(q[i]);

    printf("ifFalse %s %s %s goto L2\n",
           lhs, rel, rhs);

    for (int i = stepEnd; i < n; i++)
        show(q[i]);

    for (int i = condEnd; i < stepEnd; i++)
        show(q[i]);

    printf("goto L1\nL2:\n");

    /* Perform constant folding */
    fold();

    /* Move invariant body calculations */
    for (int i = stepEnd; i < n; i++) {
        Ins *p = &q[i];

        if (!strncmp(p->d, "__tmp", 5) &&
            p->op != '/') {

            hoist[i] = safe(p->a) &&
                (p->op == '=' || safe(p->b));
        }
    }

    printf("\n--- PART (d): OPTIMIZED TAC ---\n");

    printRange(0, initEnd, 0);
    printRange(stepEnd, n, 1);

    printf("L1:\n");
    printRange(initEnd, condEnd, 0);

    printf("ifFalse %s %s %s goto L2\n",
           lhs, rel, rhs);

    printRange(stepEnd, n, 0);
    printRange(condEnd, stepEnd, 0);

    printf("goto L1\nL2:\n");

    printf("\n--- PART (e): TARGET CODE ---\n");

    targetRange(0, initEnd, 0);
    targetRange(stepEnd, n, 1);

    printf("L1:\n");
    targetRange(initEnd, condEnd, 0);

    printf("MOV R0, %s\n", lhs);
    printf("CMP R0, %s\n", rhs);
    printf("%s L2\n", inverse());

    targetRange(stepEnd, n, 0);
    targetRange(condEnd, stepEnd, 0);

    printf("JMP L1\nL2:\n");
    printf("\n--- PART (f): INTEGRATION SUCCESSFUL ---\n");
}
%}

%union {
    char *s;
}

%token FOR INC DEC
%token <s> ID NUM REL
%type <s> expr term atom

%%

program:
    FOR '(' init ';'
    {
        initEnd = n;
    }
    expr REL expr ';'
    {
        lhs = $6;
        rel = $7;
        rhs = $8;
        condEnd = n;
    }
    step ')'
    {
        stepEnd = n;
    }
    '{' stmts '}'
    {
        generate();
    }
    ;

init:
    ID '=' expr
    {
        emit($1, $3, '=', "");
    }
    ;

step:
      ID '=' expr
      {
          emit($1, $3, '=', "");
      }
    | ID INC
      {
          emit($1, $1, '+', "1");
      }
    | ID DEC
      {
          emit($1, $1, '-', "1");
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
