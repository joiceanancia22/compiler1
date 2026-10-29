
%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

int yylex(void);
void yyerror(const char *s);
char *dupstr(const char *s);

typedef struct {
    char type, op;
    char d[80], a[80], b[80], rel[4];
} Ins;

Ins q[300];
int n = 0, tmp = 0, label = 0;

/* Add instruction */
void emit(char type, char *d, char *a,
          char op, char *b, char *rel)
{
    if (n >= 300) exit(1);

    Ins *p = &q[n++];
    p->type = type;
    p->op = op;

    snprintf(p->d, 80, "%s", d ? d : "");
    snprintf(p->a, 80, "%s", a ? a : "");
    snprintf(p->b, 80, "%s", b ? b : "");
    snprintf(p->rel, 4, "%s", rel ? rel : "");
}

/* Create temporary variable */
char *calc(char *a, char op, char *b)
{
    char t[30];

    sprintf(t, "__tmp%d", ++tmp);
    emit('A', t, a, op, b, "");

    return dupstr(t);
}

/* Create label name */
char *newlabel(int id)
{
    char s[30];
    sprintf(s, "L%d", id);
    return dupstr(s);
}

/* Generate conditional jump */
void condition(char *a, char *r, char *b, int id)
{
    emit('C', newlabel(id), a, 0, b, r);
}

/* Generate unconditional jump */
void jump(int id)
{
    emit('J', newlabel(id), "", 0, "", "");
}

/* Generate label */
void mark(int id)
{
    emit('L', newlabel(id), "", 0, "", "");
}

/* Print three-address code */
void show(Ins p)
{
    if (p.type == 'L')
        printf("%s:\n", p.d);

    else if (p.type == 'J')
        printf("goto %s\n", p.d);

    else if (p.type == 'C')
        printf("ifFalse %s %s %s goto %s\n",
               p.a, p.rel, p.b, p.d);

    else if (p.op == '=')
        printf("%s = %s\n", p.d, p.a);

    else
        printf("%s = %s %c %s\n",
               p.d, p.a, p.op, p.b);
}

/* Check numeric constants */
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
        Ins *p = &q[i];

        if (p->type != 'A' || p->op == '=' ||
            !isnum(p->a) || !isnum(p->b))
            continue;

        long a = atol(p->a);
        long b = atol(p->b);
        long v;

        if (p->op == '+') v = a + b;
        else if (p->op == '-') v = a - b;
        else if (p->op == '*') v = a * b;
        else if (p->op == '/' && b != 0) v = a / b;
        else continue;

        sprintf(p->a, "%ld", v);
        p->op = '=';
        p->b[0] = '\0';
    }
}

/* Inverse relational jump */
const char *inverse(char *r)
{
    if (!strcmp(r, "<"))  return "JGE";
    if (!strcmp(r, ">"))  return "JLE";
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

    if (p.type == 'J') {
        printf("JMP %s\n", p.d);
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

/* Generate all outputs */
void generate(void)
{
    printf("\n--- PART (b): SYNTAX ---\n");
    printf("Syntax Correct\n");

    printf("\n--- PART (c): THREE ADDRESS CODE ---\n");

    for (int i = 0; i < n; i++)
        show(q[i]);

    optimize();

    printf("\n--- PART (d): OPTIMIZED TAC ---\n");

    for (int i = 0; i < n; i++)
        show(q[i]);

    printf("\n--- PART (e): TARGET CODE ---\n");

    for (int i = 0; i < n; i++)
        machine(q[i]);

    printf("\n--- PART (f): INTEGRATION SUCCESSFUL ---\n");
}
%}

%union {
    char *s;

    struct {
        char *a, *r, *b;
    } cond;

    struct {
        int f, e;
    } labels;
}

%token IF ELSE
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
        $<labels>$.f = ++label;
        $<labels>$.e = ++label;

        condition($3.a, $3.r, $3.b, $<labels>$.f);
    }
    '{' statements '}'
    {
        jump($<labels>5.e);
        mark($<labels>5.f);
        $<labels>$ = $<labels>5;
    }
    ELSE '{' statements '}'
    {
        mark($<labels>9.e);
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
