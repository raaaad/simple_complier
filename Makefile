x0: x0lex.l x0yacc.y   
    flex x0lex.l
    yacc -d -v x0yacc.y
    cc -o $@ x0yacc.tab.c lex.yy.c -lfl 