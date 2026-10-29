%{
#include "y.tab.h"
%}
%option noyywrap yylineno

id      [a-zA-Z_][a-zA-Z0-9_]*
num     [0-9]+(\.[0-9]+)?

%%
"//".*                                  ;
"int"|"float"|"char"|"double"           { return TYPE; }
"if"                                    { return IF; }
"else"                                  { return ELSE; }
"while"                                 { return WHILE; }
"for"                                   { return FOR; }
"return"                                { return RETURN; }
{id}                                    { return ID; }
{num}                                   { return NUM; }
"<="|">="|"=="|"!="|"<"|">"             { return RELOP; }
"&&"                                    { return AND; }
"||"                                    { return OR; }
"!"                                     { return NOT; }
"++"                                    { return INC; }
"--"                                    { return DEC; }
[ \t\r\n]+                              ;
.                                       { return yytext[0]; }
%%
