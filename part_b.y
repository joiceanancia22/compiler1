%{
#include <stdio.h>
#include <stdlib.h>
int yylex();
void yyerror(const char *s);
extern int yylineno;
%}

%token TYPE IF ELSE WHILE FOR RETURN ID NUM RELOP AND OR NOT INC DEC
%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE
%left OR
%left AND
%left RELOP
%left '+' '-'
%left '*' '/' '%'
%right NOT UMINUS
%right '^'

%%
prog: stmts { printf("--- PART B: SYNTAX ANALYSIS ---\nSyntax is VALID!\n"); }
    ;

stmts: stmts stmt | /* empty */ ;

stmt: decl ';'
    | assign ';'
    | IF '(' expr ')' stmt %prec LOWER_THAN_ELSE
    | IF '(' expr ')' stmt ELSE stmt
    | WHILE '(' expr ')' stmt
    | FOR '(' forinit ';' expr ';' forstep ')' stmt
    | TYPE ID '(' ')' stmt
    | RETURN expr ';'
    | '{' stmts '}'
    ;

forinit: decl | assign | /* empty */ ;
forstep: assign | /* empty */ ;

decl: TYPE varlist ;
varlist: varlist ',' var | var ;
var: ID | ID '=' expr ;

assign: ID '=' expr | ID INC | ID DEC ;

expr: expr '+' expr | expr '-' expr | expr '*' expr | expr '/' expr
    | expr '%' expr | expr '^' expr | expr RELOP expr
    | expr AND expr | expr OR expr | NOT expr
    | '-' expr %prec UMINUS | '(' expr ')' | ID | NUM
    ;
%%

void yyerror(const char *s) {
    printf("Syntax Error at line %d: %s\n", yylineno, s);
    exit(1);
}
int main() { return yyparse(); }
