%{
#include "stdio.h"
#include "string.h"
#include "stdlib.h"
#include "x0yacc.tab.h"

int line=1;
void yyerror(char *);
int yywrap(void);
%}

%%
[ \t]	{;}
[\n]	{line++;}
"main"	{return MAINSYM;}
"int"	{return INTSYM;}
"char"	{return CHARSYM;}
"if"	{return IFSYM;}
"else"	{return ELSESYM;}
"while"	{return WHILESYM;}
"write"	{return WRITESYM;}
"read"	{return READSYM;}
[A-Za-z]([A-Za-z]|[0-9])*	{yylval.ident=(char *)malloc(strlen(yytext)+1);
                                 strcpy(yylval.ident,yytext);
                                 return ID;
}
[0-9]+	{yylval.number=atoi(yytext); return NUM;}
"="		{return ASSIGN;}
"%"		{return MOD;}
"<"		{return LSS;}
">"		{return GTR;}
"<="	{return LEQ;}
">="	{return GEQ;}
"=="	{return	EQL;}
"!="	{return NEQ;}
"+"		{return ADD;}
"-"		{return SUB;}
"*"		{return MUL;}
"/"		{return	DIV;}
"("		{return	LPAREN;}
")"		{return	RPAREN;}
"["		{return LSQBRK;}
"]"		{return RSQBRK;}
"{"		{return LBRACE;}
"}"		{return RBRACE;}
";"		{return	SEMICOLON;}
","		{return COMMA;}
.		{yyerror("Unknown character!");}

%%
int main()
{
   yylex();
   return 0;
}

void redirectInput(FILE *input)
{
	yyin = input;
}

int yygetchar(void)
{
	int ret;
	ret = getc(yyin);
	printf("%c",ret);
	return ret;
}

int yywrap(void)
{
	return 1;
}
