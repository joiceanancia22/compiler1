
%option noyywrap

%{
#include "y.tab.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

char *dupstr(const char *s)
{
    char *p = malloc(strlen(s) + 1);
    if (!p) exit(1);
    return strcpy(p, s);
}
%}

%%

"if" {
    printf("Keyword: %s\n", yytext);
    return IF;
}

"<="|">="|"=="|"!="|"<"|">" {
    printf("Relational Operator: %s\n", yytext);
    yylval.s = dupstr(yytext);
    return REL;
}

[0-9]+ {
    printf("Number: %s\n", yytext);
    yylval.s = dupstr(yytext);
    return NUM;
}

[a-zA-Z_][a-zA-Z0-9_]* {
    printf("Identifier: %s\n", yytext);
    yylval.s = dupstr(yytext);
    return ID;
}

[ \t\r\n]+ ;

[+*/=-] {
    printf("Operator: %s\n", yytext);
    return yytext[0];
}

[(){};] {
    printf("Symbol: %s\n", yytext);
    return yytext[0];
}

. {
    printf("Invalid Token: %s\n", yytext);
    return yytext[0];
}

%%
