%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int yylex();
void yyerror(const char *s);
extern int yylineno;

int tc = 1, lc = 1;
char* new_temp() { char *t = malloc(10); sprintf(t, "t%d", tc++); return t; }
int new_lbl()    { return lc++; }
%}

%union { char *str; int lbl; }

%token TYPE IF ELSE WHILE FOR RETURN AND OR NOT INC DEC
%token <str> ID NUM RELOP
%type <str> expr
%type <lbl> ifhead

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
prog: { printf("--- PART C: THREE-ADDRESS CODE ---\n"); } stmts ;

stmts: stmts stmt | /* empty */ ;

stmt: decl ';'
    | assign ';'
    | ifhead stmt %prec LOWER_THAN_ELSE { printf("L%d:\n", $1); }
    | ifhead stmt ELSE {
          int l_end = new_lbl();
          printf("goto L%d\nL%d:\n", l_end, $1);
          $<lbl>$ = l_end;
      } stmt { printf("L%d:\n", $<lbl>4); }
    | WHILE {
          int l_start = new_lbl();
          printf("L%d:\n", l_start);
          $<lbl>$ = l_start;
      } '(' expr ')' {
          int l_end = new_lbl();
          printf("ifFalse %s goto L%d\n", $4, l_end);
          $<lbl>$ = l_end;
      } stmt { printf("goto L%d\nL%d:\n", $<lbl>2, $<lbl>6); }
    | FOR '(' forinit ';' {
          int l_cond = new_lbl();
          printf("L%d:\n", l_cond);
          $<lbl>$ = l_cond;
      } expr ';' {
          int l_end  = new_lbl();
          int l_body = new_lbl();
          int l_step = new_lbl();
          printf("ifFalse %s goto L%d\ngoto L%d\nL%d:\n", $6, l_end, l_body, l_step);
          $<lbl>$ = l_end;
      } forstep ')' {
          printf("goto L%d\nL%d:\n", $<lbl>5, $<lbl>8 + 1);
      } stmt {
          printf("goto L%d\nL%d:\n", $<lbl>8 + 2, $<lbl>8);
      }
    | TYPE ID '(' ')' stmt
    | RETURN expr ';' { printf("return %s\n", $2); }
    | '{' stmts '}'
    ;

ifhead: IF '(' expr ')' {
            int l_false = new_lbl();
            printf("ifFalse %s goto L%d\n", $3, l_false);
            $$ = l_false;
        }
      ;

forinit: decl | assign | /* empty */ ;
forstep: assign | /* empty */ ;

decl: TYPE varlist ;
varlist: varlist ',' var | var ;
var: ID | ID '=' expr { printf("%s = %s\n", $1, $3); } ;

assign: ID '=' expr { printf("%s = %s\n", $1, $3); }
      | ID INC      { printf("%s = %s + 1\n", $1, $1); }
      | ID DEC      { printf("%s = %s - 1\n", $1, $1); }
      ;

expr: expr '+' expr         { $$ = new_temp(); printf("%s = %s + %s\n", $$, $1, $3); }
    | expr '-' expr         { $$ = new_temp(); printf("%s = %s - %s\n", $$, $1, $3); }
    | expr '*' expr         { $$ = new_temp(); printf("%s = %s * %s\n", $$, $1, $3); }
    | expr '/' expr         { $$ = new_temp(); printf("%s = %s / %s\n", $$, $1, $3); }
    | expr '%' expr         { $$ = new_temp(); printf("%s = %s %% %s\n", $$, $1, $3); }
    | expr '^' expr         { $$ = new_temp(); printf("%s = %s ^ %s\n", $$, $1, $3); }
    | expr RELOP expr       { $$ = new_temp(); printf("%s = %s %s %s\n", $$, $1, $2, $3); }
    | expr AND expr         { $$ = new_temp(); printf("%s = %s && %s\n", $$, $1, $3); }
    | expr OR expr          { $$ = new_temp(); printf("%s = %s || %s\n", $$, $1, $3); }
    | NOT expr              { $$ = new_temp(); printf("%s = ! %s\n", $$, $2); }
    | '-' expr %prec UMINUS { $$ = new_temp(); printf("%s = - %s\n", $$, $2); }
    | '(' expr ')'          { $$ = $2; }
    | ID                    { $$ = $1; }
    | NUM                   { $$ = $1; }
    ;
%%

void yyerror(const char *s) {
    printf("Error at line %d: %s\n", yylineno, s);
    exit(1);
}
int main() { return yyparse(); }
