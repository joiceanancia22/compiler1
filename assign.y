
%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int yylex(void);
void yyerror(const char *s);

int temp = 0;

typedef struct {
    char result[50], a[50], b[50], op;
} TAC;

TAC code[100];
int n = 0;

char *generate(char *a, char op, char *b)
{
    char t[20];
    sprintf(t, "t%d", ++temp);

    strcpy(code[n].result, t);
    strcpy(code[n].a, a);
    strcpy(code[n].b, b);
    code[n++].op = op;

    return strdup(t);
}

void emit(char *a, char *b)
{
    strcpy(code[n].result, a);
    strcpy(code[n].a, b);
    code[n].b[0] = '\0';
    code[n++].op = '=';
}

void output(void)
{
    printf("\n--- THREE ADDRESS CODE ---\n");

    for (int i = 0; i < n; i++) {
        if (code[i].op == '=')
            printf("%s = %s\n", code[i].result, code[i].a);
        else
            printf("%s = %s %c %s\n",
                   code[i].result, code[i].a,
                   code[i].op, code[i].b);
    }

    printf("\n--- OPTIMIZED TAC ---\n");

    for (int i = 0; i < n; i++) {
        TAC p = code[i];

        if (p.op != '=' &&
            strspn(p.a, "0123456789") == strlen(p.a) &&
            strspn(p.b, "0123456789") == strlen(p.b)) {

            int a = atoi(p.a), b = atoi(p.b), v;

            if (p.op == '+') v = a + b;
            else if (p.op == '-') v = a - b;
            else if (p.op == '*') v = a * b;
            else if (p.op == '/' && b != 0) v = a / b;
            else continue;

            sprintf(code[i].a, "%d", v);
            code[i].op = '=';
            code[i].b[0] = '\0';
        }

        if (code[i].op == '=')
            printf("%s = %s\n", code[i].result, code[i].a);
        else
            printf("%s = %s %c %s\n",
                   code[i].result, code[i].a,
                   code[i].op, code[i].b);
    }

    printf("\n--- TARGET CODE ---\n");

    for (int i = 0; i < n; i++) {
        printf("MOV R0, %s\n", code[i].a);

        if (code[i].op != '=') {
            char *op = code[i].op == '+' ? "ADD" :
                       code[i].op == '-' ? "SUB" :
                       code[i].op == '*' ? "MUL" : "DIV";

            printf("%s R0, %s\n", op, code[i].b);
        }

        printf("STORE %s, R0\n", code[i].result);
    }
}
%}

%union {
    char *str;
}

%token <str> ID NUM
%type <str> expr term factor

%%

program:
    statements
    {
        printf("\nSyntax Correct\n");
        output();
    }
    ;

statements:
      statement
    | statements statement
    ;

statement:
    ID '=' expr ';'
    {
        emit($1, $3);
    }
    ;

expr:
      expr '+' term { $$ = generate($1, '+', $3); }
    | expr '-' term { $$ = generate($1, '-', $3); }
    | term          { $$ = $1; }
    ;

term:
      term '*' factor { $$ = generate($1, '*', $3); }
    | term '/' factor { $$ = generate($1, '/', $3); }
    | factor          { $$ = $1; }
    ;

factor:
      ID             { $$ = $1; }
    | NUM            { $$ = $1; }
    | '(' expr ')'   { $$ = $2; }
    ;

%%

void yyerror(const char *s)
{
    printf("Syntax Error: %s\n", s);
}

int main(void)
{
    printf("--- TOKENS ---\n");
    return yyparse();
}
