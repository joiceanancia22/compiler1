
%option noyywrap

%{
#include "y.tab.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
%}

%%

[0-9]+ {
    printf("Number: %s\n", yytext);
    yylval.str = strdup(yytext);
    return NUM;
}

[a-zA-Z][a-zA-Z0-9]* {
    printf("Identifier: %s\n", yytext);
    yylval.str = strdup(yytext);
    return ID;
}

[+*/=-] {
    printf("Operator: %s\n", yytext);
    return yytext[0];
}

[();] {
    printf("Symbol: %s\n", yytext);
    return yytext[0];
}

[ \t\n\r]+ ;

. {
    printf("Invalid: %s\n", yytext);
    return yytext[0];
}

%%
