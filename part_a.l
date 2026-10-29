%{
#include <stdio.h>
%}
%option noyywrap yylineno

id      [a-zA-Z_][a-zA-Z0-9_]*
num     [0-9]+(\.[0-9]+)?

%%
"//".*                                  { printf("COMMENT\t\t: %s\n", yytext); }
"int"|"float"|"char"|"double"           { printf("KEYWORD\t\t: %s\n", yytext); }
"if"|"else"|"while"|"for"|"return"      { printf("KEYWORD\t\t: %s\n", yytext); }
{id}                                    { printf("IDENTIFIER\t: %s\n", yytext); }
{num}                                   { printf("CONSTANT\t: %s\n", yytext); }
"<="|">="|"=="|"!="|"<"|">"             { printf("REL_OP\t\t: %s\n", yytext); }
"&&"|"||"|"!"                           { printf("LOGICAL_OP\t: %s\n", yytext); }
"++"|"--"                               { printf("UNARY_OP\t: %s\n", yytext); }
"+"|"-"|"*"|"/"|"%"|"^"                 { printf("ARITH_OP\t: %s\n", yytext); }
"="                                     { printf("ASSIGN_OP\t: %s\n", yytext); }
";"|","|"("|")"|"{"|"}"                 { printf("DELIMITER\t: %s\n", yytext); }
[ \t\r\n]+                              ;
.                                       { printf("UNKNOWN\t\t: %s\n", yytext); }
%%

int main() {
    printf("--- PART A: LEXICAL ANALYSIS ---\n");
    yylex();
    return 0;
}
