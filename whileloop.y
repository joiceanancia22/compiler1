
%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

int yylex(void);
void yyerror(const char *s);
char *dupstr(const char *s);

typedef struct {
    char d[80];
    char a[80];
    char b[80];
    char op;
} Ins;

Ins q[200], orig[200];

int n = 0, cut = 0, tmp = 0;
int hoist[200] = {0};

char *lhs, *rhs, *rel;

/* Check whether a string is a number */
int isnum(const char *s)
{
    if (!*s)
        return 0;

    for (; *s; s++) {
        if (!isdigit((unsigned char)*s))
            return 0;
    }

    return 1;
}

/* Generate three-address instruction */
void emit(char *d, char *a, char op, char *b)
{
    if (n == 200) {
        fprintf(stderr, "Too many instructions\n");
        exit(1);
    }

    snprintf(q[n].d, 80, "%s", d);
    snprintf(q[n].a, 80, "%s", a);
    snprintf(q[n].b, 80, "%s", b);

    q[n].op = op;
    n++;
}

/* Create temporary variable */
char *calc(char *a, char op, char *b)
{
    char t[40];

    sprintf(t, "__tmp%d", ++tmp);
    emit(t, a, op, b);

    return dupstr(t);
}

/* Display three-address instruction */
void show(Ins p)
{
    if (p.op == '=') {
        printf("%s = %s\n", p.d, p.a);
    } else {
        printf("%s = %s %c %s\n",
               p.d, p.a, p.op, p.b);
    }
}

/* Generate target code */
void machine(Ins p)
{
    printf("MOV R0, %s\n", p.a);

    if (p.op != '=') {
        const char *operation;

        if (p.op == '+')
            operation = "ADD";
        else if (p.op == '-')
            operation = "SUB";
        else if (p.op == '*')
            operation = "MUL";
        else
            operation = "DIV";

        printf("%s R0, %s\n", operation, p.b);
    }

    printf("STORE %s, R0\n", p.d);
}

/* Check if a variable changes inside the loop */
int assigned(char *v)
{
    for (int i = cut; i < n; i++) {
        if (!strcmp(v, q[i].d))
            return 1;
    }

    return 0;
}

/* Check whether an operand is loop-invariant */
int safe(char *v)
{
    if (isnum(v))
        return 1;

    for (int i = 0; i < n; i++) {
        if (!strcmp(v, q[i].d))
            return hoist[i];
    }

    return !assigned(v);
}

/* Get inverse jump instruction */
const char *inverse(void)
{
    if (!strcmp(rel, "<"))
        return "JGE";

    if (!strcmp(rel, ">"))
        return "JLE";

    if (!strcmp(rel, "<="))
        return "JG";

    if (!strcmp(rel, ">="))
        return "JL";

    if (!strcmp(rel, "=="))
        return "JNE";

    return "JE";
}

/* Generate all compiler outputs */
void generate(void)
{
    printf("\nSyntax Correct\n");

    /* Part C: Three-address code */
    printf("\n--- THREE ADDRESS CODE ---\n");
    printf("L1:\n");

    for (int i = 0; i < cut; i++)
        show(q[i]);

    printf("ifFalse %s %s %s goto L2\n",
           lhs, rel, rhs);

    for (int i = cut; i < n; i++)
        show(q[i]);

    printf("goto L1\nL2:\n");

    /* Part D: Constant folding */
    for (int i = 0; i < n; i++) {
        if (q[i].op == '=' ||
            !isnum(q[i].a) ||
            !isnum(q[i].b))
            continue;

        long a = atol(q[i].a);
        long b = atol(q[i].b);
        long v;

        if (q[i].op == '+')
            v = a + b;
        else if (q[i].op == '-')
            v = a - b;
        else if (q[i].op == '*')
            v = a * b;
        else if (q[i].op == '/' && b != 0)
            v = a / b;
        else
            continue;

        snprintf(q[i].a, 80, "%ld", v);
        q[i].op = '=';
        q[i].b[0] = '\0';
    }

    /* Loop-invariant code motion */
    for (int i = 0; i < n; i++) {
        if (!strncmp(q[i].d, "__tmp", 5) &&
            q[i].op != '/') {

            hoist[i] = safe(q[i].a) &&
                (q[i].op == '=' || safe(q[i].b));
        }
    }

    /* Display optimized TAC */
    printf("\n--- OPTIMIZED TAC ---\n");

    for (int i = 0; i < n; i++) {
        if (hoist[i])
            show(q[i]);
    }

    printf("L1:\n");

    for (int i = 0; i < cut; i++) {
        if (!hoist[i])
            show(q[i]);
    }

    printf("ifFalse %s %s %s goto L2\n",
           lhs, rel, rhs);

    for (int i = cut; i < n; i++) {
        if (!hoist[i])
            show(q[i]);
    }

    printf("goto L1\nL2:\n");

    /* Part E: Target code */
    printf("\n--- TARGET CODE ---\n");

    for (int i = 0; i < n; i++) {
        if (hoist[i])
            machine(q[i]);
    }

    printf("L1:\n");

    for (int i = 0; i < cut; i++) {
        if (!hoist[i])
            machine(q[i]);
    }

    printf("MOV R0, %s\n", lhs);
    printf("CMP R0, %s\n", rhs);
    printf("%s L2\n", inverse());

    for (int i = cut; i < n; i++) {
        if (!hoist[i])
            machine(q[i]);
    }

    printf("JMP L1\nL2:\n");
}
%}

%union {
    char *s;
}

%token WHILE
%token <s> ID NUM REL
%type <s> expr term atom

%%

program:
    WHILE '(' expr REL expr ')'
    {
        lhs = $3;
        rel = $4;
        rhs = $5;
        cut = n;
    }
    '{' stmts '}'
    {
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
      ID               { $$ = $1; }
    | NUM              { $$ = $1; }
    | '(' expr ')'     { $$ = $2; }
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
