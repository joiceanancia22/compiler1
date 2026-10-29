
%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

int yylex(void);
void yyerror(const char *s);
char *dupstr(const char *s);

typedef struct {
    char d[80], a[80], b[80], rel[4];
    char type, op;
} Ins;

Ins code[200];
int n = 0, temp = 0, label = 0;

/* Generate instruction */
void emit(char type, char *d, char *a,
          char op, char *b, char *rel)
{
    if (n >= 200) exit(1);

    Ins *p = &code[n++];
    p->type = type;
    p->op = op;

    snprintf(p->d, 80, "%s", d ? d : "");
    snprintf(p->a, 80, "%s", a ? a : "");
    snprintf(p->b, 80, "%s", b ? b : "");
    snprintf(p->rel, 4, "%s", rel ? rel : "");
}

/* Generate temporary */
char *calc(char *a, char op, char *b)
{
    char t[30];

    sprintf(t, "t%d", ++temp);
    emit('A', t, a, op, b, "");

    return dupstr(t);
}

/* Generate conditional jump */
void condition(char *a, char *rel, char *b)
{
    emit('C', "L1", a, 0, b, rel);
}

/* Display TAC */
void show(Ins p)
{
    if (p.type == 'L')
        printf("%s:\n", p.d);

    else if (p.type == 'C')
        printf("ifFalse %s %s %s goto %s\n",
               p.a, p.rel, p.b, p.d);

    else if (p.op == '=')
        printf("%s = %s\n", p.d, p.a);

    else
        printf("%s = %s %c %s\n",
               p.d, p.a, p.op, p.b);
}

/* Check numeric constant */
int isnum(const char *s)
{
    if (!*s) return 0;

    for (; *s; s++)
        if (!isdigit((unsigned char)*s))
            return 0;

    return 1;
}

/* Constant folding */
void optimize(void)
{
    for (int i = 0; i < n; i++) {
        Ins *p = &code[i];

        if (p->type != 'A' || p->op == '=' ||
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

/* Inverse jump */
const char *inverse(char *r)
{
    if (!strcmp(r, "<")) return "JGE";
    if (!strcmp(r, ">")) return "JLE";
    if (!strcmp(r, "<=")) return "JG";
    if (!strcmp(r, ">=")) return "JL";
    if (!strcmp(r, "==")) return "JNE";
    return "JE";
}

/* Generate target code */
void machine(Ins p)
{
    if (p.type == 'L') {
        printf("%s:\n", p.d);
        return;
    }

    if (p.type == 'C') {
        printf("MOV R0, %s\n", p.a);
        printf("CMP R0, %s\n", p.b);
        printf("%s %s\n", inverse(p.rel), p.d);
        return;
    }

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

/* Print all outputs */
void generate(void)
{
    printf("\n--- PART (b): SYNTAX ---\n");
    printf("Syntax Correct\n");

    printf("\n--- PART (c): THREE ADDRESS CODE ---\n");

    for (int i = 0; i < n; i++)
        show(code[i]);

    optimize();

    printf("\n--- PART (d): OPTIMIZED TAC ---\n");

    for (int i = 0; i < n; i++)
        show(code[i]);

    printf("\n--- PART (e): TARGET CODE ---\n");

    for (int i = 0; i < n; i++)
        machine(code[i]);

    printf("\n--- PART (f): INTEGRATION SUCCESSFUL ---\n");
}
%}

%union {
    char *s;
    struct {
        char *a, *r, *b;
    } cond;
}

%token IF
%token <s> ID NUM REL
%type <s> expr term atom
%type <cond> test

%%

program:
    statements
    {
        generate();
    }
    ;

statements:
      /* empty */
    | statements statement
    ;

statement:
      ID '=' expr ';'
      {
          emit('A', $1, $3, '=', "", "");
      }
    | ifstmt
    ;

ifstmt:
    IF '(' test ')'
    {
        condition($3.a, $3.r, $3.b);
    }
    '{' statements '}'
    {
        emit('L', "L1", "", 0, "", "");
    }
    ;

test:
    expr REL expr
    {
        $$.a = $1;
        $$.r = $2;
        $$.b = $3;
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
      ID              { $$ = $1; }
    | NUM             { $$ = $1; }
    | '(' expr ')'    { $$ = $2; }
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
