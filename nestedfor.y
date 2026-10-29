
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
    char start[20], end[20];
    int first, last, stepStart, count;
    Ins step[100];
} Loop;

Ins q[500];
Loop loops[50];

int n = 0, tmp = 0, labels = 0;
int depth = 0, stack[50], total = 0;
int moved[500] = {0};

int current(void)
{
    return depth ? stack[depth - 1] : -1;
}

void emit(char type, char *d, char *a,
          char op, char *b, char *rel)
{
    if (n >= 500) {
        fprintf(stderr, "Instruction limit reached\n");
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

char *calc(char *a, char op, char *b)
{
    char t[40];

    sprintf(t, "__temp%d", ++tmp);
    emit('A', t, a, op, b, "");
    return dupstr(t);
}

void beginLoop(void)
{
    if (depth >= 50 || total >= 50) exit(1);

    int id = total++;
    Loop *l = &loops[id];

    sprintf(l->start, "L%d", ++labels);
    sprintf(l->end, "L%d", ++labels);

    l->first = n;
    l->count = 0;

    stack[depth++] = id;
    emit('L', l->start, "", 0, "", "");
}

void condition(char *a, char *r, char *b)
{
    Loop *l = &loops[current()];
    emit('C', l->end, a, 0, b, r);
    l->stepStart = n;
}

void saveStep(void)
{
    Loop *l = &loops[current()];
    l->count = n - l->stepStart;

    if (l->count > 100) exit(1);

    for (int i = 0; i < l->count; i++)
        l->step[i] = q[l->stepStart + i];

    n = l->stepStart;
}

void endLoop(void)
{
    Loop *l = &loops[current()];

    for (int i = 0; i < l->count; i++)
        q[n++] = l->step[i];

    emit('J', l->start, "", 0, "", "");
    emit('L', l->end, "", 0, "", "");

    l->last = n;
    depth--;
}

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

const char *inverse(char *r)
{
    if (!strcmp(r, "<")) return "JGE";
    if (!strcmp(r, ">")) return "JLE";
    if (!strcmp(r, "<=")) return "JG";
    if (!strcmp(r, ">=")) return "JL";
    if (!strcmp(r, "==")) return "JNE";
    return "JE";
}

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
        printf("MOV R0, %s\nCMP R0, %s\n",
               p.a, p.b);
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

int isnum(const char *s)
{
    if (!*s) return 0;

    for (; *s; s++)
        if (!isdigit((unsigned char)*s))
            return 0;

    return 1;
}

void fold(void)
{
    for (int i = 0; i < n; i++) {
        Ins *p = &q[i];

        if (p->type != 'A' ||
            p->op == '=' ||
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

        sprintf(p->a, "%ld", v);
        p->op = '=';
        p->b[0] = '\0';
    }
}

/* Check whether an operand changes inside a loop */
int stable(const char *v, int id)
{
    if (isnum(v)) return 1;

    Loop *l = &loops[id];

    for (int j = l->first; j < l->last; j++) {
        if (q[j].type == 'A' &&
            !strcmp(q[j].d, v) &&
            !moved[j])
            return 0;
    }

    return 1;
}

void optimize(void)
{
    fold();

    for (int i = 0; i < n; i++) {
        Ins *p = &q[i];
        int id = p->owner;

        if (id < 0 || p->type != 'A')
            continue;

        if (strncmp(p->d, "__temp", 6))
            continue;

        if (p->op == '/')
            continue;

        moved[i] = stable(p->a, id) &&
            (p->op == '=' || stable(p->b, id));
    }
}

void generate(void)
{
    printf("\n--- PART (b): SYNTAX ---\n");
    printf("Syntax Correct\n");

    printf("\n--- PART (c): THREE ADDRESS CODE ---\n");

    for (int i = 0; i < n; i++)
        show(q[i]);

    optimize();

    printf("\n--- PART (d): OPTIMIZED TAC ---\n");

    for (int i = 0; i < n; i++) {
        for (int k = 0; k < total; k++)
            if (loops[k].first == i)
                for (int j = 0; j < n; j++)
                    if (moved[j] && q[j].owner == k)
                        show(q[j]);

        if (!moved[i])
            show(q[i]);
    }

    printf("\n--- PART (e): TARGET CODE ---\n");

    for (int i = 0; i < n; i++) {
        for (int k = 0; k < total; k++)
            if (loops[k].first == i)
                for (int j = 0; j < n; j++)
                    if (moved[j] && q[j].owner == k)
                        machine(q[j]);

        if (!moved[i])
            machine(q[i]);
    }

    printf("\n--- PART (f): INTEGRATION SUCCESSFUL ---\n");
}
%}

%union {
    char *s;
    struct {
        char *a, *r, *b;
    } cond;
}

%token FOR INC DEC
%token <s> ID NUM REL
%type <s> expr term atom
%type <cond> test

%%

program:
    statements { generate(); }
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
    FOR '(' assignment ';'
    {
        beginLoop();
    }
    test ';'
    {
        condition($6.a, $6.r, $6.b);
    }
    update ')'
    {
        saveStep();
    }
    '{' statements '}'
    {
        endLoop();
    }
    ;

assignment:
    ID '=' expr
    {
        emit('A', $1, $3, '=', "", "");
    }
    ;

update:
      assignment
    | ID INC
      {
          emit('A', $1, $1, '+', "1", "");
      }
    | ID DEC
      {
          emit('A', $1, $1, '-', "1", "");
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
      ID            { $$ = $1; }
    | NUM           { $$ = $1; }
    | '(' expr ')'  { $$ = $2; }
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
