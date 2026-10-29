
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
    int owner;
} Ins;

typedef struct {
    int start, condEnd, end;
    char first[20], last[20];
} Loop;

Ins q[500];
Loop loops[50];

int n = 0, tmp = 0, labels = 0;
int total = 0, depth = 0;
int stack[50], moved[500] = {0};

/* Current loop */
int current(void)
{
    return depth ? stack[depth - 1] : -1;
}

/* Generate instruction */
void emit(char type, char *d, char *a,
          char op, char *b, char *rel)
{
    if (n >= 500) {
        fprintf(stderr, "Too many instructions\n");
        exit(1);
    }

    Ins *p = &q[n++];

    p->type = type;
    p->op = op;
    p->owner = current();

    snprintf(p->d, 80, "%s", d ? d : "");
    snprintf(p->a, 80, "%s", a ? a : "");
    snprintf(p->b, 80, "%s", b ? b : "");
    snprintf(p->rel, 4, "%s", rel ? rel : "");
}

/* Generate temporary variable */
char *calc(char *a, char op, char *b)
{
    char t[30];

    sprintf(t, "__tmp%d", ++tmp);
    emit('A', t, a, op, b, "");

    return dupstr(t);
}

/* Begin while loop */
void beginLoop(void)
{
    if (depth >= 50 || total >= 50)
        exit(1);

    int id = total++;
    Loop *l = &loops[id];

    sprintf(l->first, "L%d", ++labels);
    sprintf(l->last, "L%d", ++labels);

    l->start = n;

    stack[depth++] = id;

    emit('L', l->first, "", 0, "", "");
}

/* Generate condition */
void condition(char *a, char *r, char *b)
{
    Loop *l = &loops[current()];

    emit('C', l->last, a, 0, b, r);
    l->condEnd = n;
}

/* End while loop */
void endLoop(void)
{
    Loop *l = &loops[current()];

    emit('J', l->first, "", 0, "", "");
    emit('L', l->last, "", 0, "", "");

    l->end = n;
    depth--;
}

/* Print TAC instruction */
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

/* Inverse conditional jump */
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
void fold(void)
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
        else if (p->op == '/' && b) v = a / b;
        else continue;

        snprintf(p->a, 80, "%ld", v);
        p->op = '=';
        p->b[0] = '\0';
    }
}

/* Check invariant operand */
int stable(const char *v, int id)
{
    if (isnum(v))
        return 1;

    Loop *l = &loops[id];

    /* Handle temporary variables */
    for (int i = 0; i < n; i++) {
        if (q[i].type == 'A' &&
            !strcmp(v, q[i].d) &&
            !strncmp(v, "__tmp", 5)) {

            if (i < l->start)
                return 1;

            return q[i].owner == id && moved[i];
        }
    }

    /* Ordinary variable must not change in loop */
    for (int i = l->start; i < l->end; i++) {
        if (q[i].type == 'A' &&
            !strcmp(v, q[i].d))
            return 0;
    }

    return 1;
}

/* Loop-invariant code motion */
void optimize(void)
{
    fold();

    for (int i = 0; i < n; i++) {
        Ins *p = &q[i];
        int id = p->owner;

        if (id < 0 || p->type != 'A')
            continue;

        if (strncmp(p->d, "__tmp", 5))
            continue;

        /* Only computations inside the loop body */
        if (i < loops[id].condEnd)
            continue;

        /* Division is conservatively not moved */
        if (p->op == '/')
            continue;

        moved[i] = stable(p->a, id) &&
            (p->op == '=' || stable(p->b, id));
    }
}

/* Print optimized TAC or target code */
void printOptimized(int target)
{
    for (int i = 0; i < n; i++) {

        /* Insert invariant calculations before loop */
        for (int k = 0; k < total; k++) {
            if (loops[k].start == i) {

                for (int j = 0; j < n; j++) {
                    if (moved[j] && q[j].owner == k) {
                        if (target)
                            machine(q[j]);
                        else
                            show(q[j]);
                    }
                }
            }
        }

        if (!moved[i]) {
            if (target)
                machine(q[i]);
            else
                show(q[i]);
        }
    }
}

/* Generate all compiler outputs */
void generate(void)
{
    printf("\n--- PART (b): SYNTAX ---\n");
    printf("Syntax Correct\n");

    printf("\n--- PART (c): THREE ADDRESS CODE ---\n");

    for (int i = 0; i < n; i++)
        show(q[i]);

    optimize();

    printf("\n--- PART (d): OPTIMIZED TAC ---\n");
    printOptimized(0);

    printf("\n--- PART (e): TARGET CODE ---\n");
    printOptimized(1);

    printf("\n--- PART (f): INTEGRATION SUCCESSFUL ---\n");
}
%}

%union {
    char *s;

    struct {
        char *a, *r, *b;
    } cond;
}

%token WHILE
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
    | loop
    ;

loop:
    WHILE '('
    {
        beginLoop();
    }
    test ')'
    {
        condition($4.a, $4.r, $4.b);
    }
    '{' statements '}'
    {
        endLoop();
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
