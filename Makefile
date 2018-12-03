x0: x0lex.l x0yacc.y   
	lex x0lex.l
	yacc -d -v x0yacc.y
	cc  -o $@ y.tab.c lex.yy.c  -std=c89
clean:
	rm *.c *.h *.output