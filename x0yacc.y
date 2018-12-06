////////////////////////////////////////////////////////
//声明部分
%{
#include <stdio.h>
#include <stdlib.h>
#include <sys/malloc.h>
#include <string.h>

#define bool int
#define true 1
#define false 0

#define symtable_max 100	//符号表容量
#define id_max 10			//标识符的最大长度
#define addr_max 2048		//地址上界
#define code_max 200     	//最多的虚拟机代码数
#define stack_max 500 		//运行时数据栈元素最多为500个
 
#define YYDEBUG  1

#define DEBUG 1

// int yydebug = YYDEBUG;

// 符号表中的类型
enum object {
    var_int,
	var_char,
    var_int_array,
	var_char_array,

};

// 符号表结构
struct table_struct
{
   	char name[id_max];	//名字
   	enum object kind;   //int or char or int_array or char_array
   	int val;            //数值
	int addr;           //地址
	int level;
	int arr_size;       //数组大小
};

// 符号表声明
struct table_struct table[symtable_max];

// 虚拟机代码指令
enum fct {
    lit,     opr,     lod,
    sto,     cal,     ini,
    jmp,     jpc,
};

// 虚拟机代码结构
struct instruction
{
	enum fct f;   // 虚拟机代码指令
	int l;        // addr
	int a;        // num or 操作符代号
};

//data stack
struct stack
{
	enum object tp;
	int val;
};

// 存放虚拟机代码的数组
struct instruction code[code_max]; 

int p_table;	// 符号表当前指针,[0, symtable_max-1]
int p_code;		// 虚拟机代码指针,[0, code_max-1]

//全局变量，用于暂存
char id[id_max];
int num;
int lev;		// 层次记录
int size;		//如果是数组的话，存数组大小
int dec_type;	//暂存声明标识符类型 1:int 2:char

int err_num;	//记录出错数
extern int line;//声明在x0lex.l中

char input[id_max];	//测试文件名
FILE* fin;			//测试文件

void enter(enum object k);
int position(char *s);
void set_addr(int n);
void gen(enum fct x, int y, int z);

void init();							//initial virtual machine
int base(int l, struct stack* s, int b);//get base_address
void interpret();						

void print_code();								//output code
void print_table();								//output symbol table
void print_data_stack(int top, struct stack* s);//output data stack

%}

////////////////////////////////////////////////////////
//辅助定义部分
%union{
	char *ident;	//ID
	int number;		//NUM
	char single_char;//char

}

//终结符号
%token MAINSYM INTSYM CHARSYM IFSYM ELSESYM WHILESYM WRITESYM READSYM
%token ASSIGN LSS GTR LEQ GEQ EQL NEQ ADD SUB MUL DIV
%token LPAREN RPAREN LSQBRK RSQBRK LBRACE RBRACE SEMICOLON COMMA

%token <ident> ID
%token <number> NUM
%token <single_char> CHAR

//非终结符
%type <number> type var expression program
%type <number> declaration_list statement_list //in program
%type <number> id_list arr_id_list arr_id//in declaration list
%type <number> declaration_stat statement compound_stat if_stat while_stat write_stat read_stat expression_stat//statements
%type <number> simple_expr additive_expr term factor //in expression
%type <number> get_table_addr get_code_addr //作为动作

%start program
%left ADD SUB 
%left LSS GTR LEQ GEQ EQL NEQ
%left MUL DIV 

////////////////////////////////////////////////////////
//规则部分
%%
program: MAINSYM 
		{
			table[p_table].addr = p_code;	/* 记录当前层代码的开始位置*/
			$<number>$ = p_code;
			gen(jmp, 0 , 0);	/* 产生跳转指令，跳转位置未知暂时填0*/
		}
		get_table_addr 
		LBRACE declaration_list
		{
			code[$<number>2].a = p_code;	//把前面生成的跳转语句的跳转位置改成当前位置
			table[$<number>4].addr = p_code;		//记录当前过程代码地址
			table[$<number>4].arr_size = $<number>4 + 3;	//记录当前过程分配数据大小
			gen(ini, 0, $<number>5 + 3);	//生成代码
			//打印符号表
			print_table();
		}
		statement_list RBRACE
		{
			gen(opr, 0 , 0);
		}
		;

declaration_list: declaration_stat declaration_list 
				{
					$$ = $1 + $2;//total decl num
					set_addr($$);
				}
			| 	
				{
          			$$ = 0;
          		} 
		  	;

declaration_stat: type id_list SEMICOLON
				{
					$$ = $2;
				}
			|	type arr_id_list SEMICOLON
				{
					$$ = $2;
				}
          	;

id_list: ID
			{
				strcpy(id, $1); 
				if (dec_type == 1)//type is int
					enter(var_int);//join symbol table
				if (dec_type == 2)//type is char
					enter(var_char);
				$<number>$ = 1;
			}
		| id_list COMMA ID
			{
				strcpy(id, $3); 
				if (dec_type == 1)//type is int
					enter(var_int);//join symbol table
				if (dec_type == 2)//type is char
					enter(var_char);
				$<number>$ = 1 + $1;
			}
		;

arr_id_list: arr_id
				{
					$<number>$ = $1;
				}
			| arr_id_list COMMA arr_id
				{
					$<number>$ = $1 + $3;
				}
			;

arr_id: ID LSQBRK NUM RSQBRK
		{
			strcpy(id, $1);
			size = $3;
			if (dec_type == 1)
				enter(var_int_array);
			if (dec_type == 2)
				enter(var_char_array);
			$<number>$ = size;
		}
		;


statement: if_stat
          	|	while_stat
          	| 	read_stat
          	| 	write_stat
          	| 	compound_stat
          	| 	expression_stat
			;
		
/* 一条或多条语句 */
statement_list: statement_list statement
				{
					$$ = $1 + $2;
				}
			|	
				{
					$$ = 0;
				}
          	;

/* 复合语句 */
compound_stat: LBRACE statement_list RBRACE
			{
				$$ = $2;
			}
          	;

/* 条件语句 */
if_stat: IFSYM LBRACE expression RBRACE get_code_addr
		{
			gen(jpc, 0, 0);//跳转到else语句
		}
		statement get_code_addr
		{
			gen(jmp, 0, 0);//跳转到整个if语句末尾
			code[$5].a = p_code;//修改jpc跳转地址，用于执行else内语句
			
		}
		ELSESYM statement
		{
			code[$<number>7].a = p_code;//修改jmp跳转地址，执行完if下语句直接跳到此处
		}
		;

/* 循环语句 */
while_stat: WHILESYM LPAREN get_code_addr expression RPAREN get_code_addr
		{
			gen(jpc, 0 , 0);
		}
		statement
		{
			gen(jmp, 0, $3);//跳回判断语句
			code[$6].a = p_code;
		}
		;

/* 写语句 */
write_stat: WRITESYM expression SEMICOLON
			{
				gen(opr, 0, 14);
				gen(opr, 0, 15);
				$$ = $2;
			}
          	;

/* 读语句 */
read_stat: READSYM var SEMICOLON
			{
				gen(opr, 0, 16);
				gen(sto, lev - table[$2].level, table[$2].addr);
				$$ = $2;
			}
        	;


/* 表达式 */
expression: var ASSIGN expression
			{
				if ($1 == 0)//符号表地址为0
					yyerror("Symbol does not exist.");
				else
				{
					gen(sto, lev - table[$1].level, table[$1].addr);
				}
			}
		|	simple_expr
		;

/* 分号或加分号的表达式 */
expression_stat: expression SEMICOLON
			{
				$$ = $1;
			}
		|	SEMICOLON
			{
				$$ = 0;
			}
		;

/* 简单表达式 */
simple_expr: additive_expr
		|	additive_expr GTR additive_expr
			{
				gen(opr, 0, 12);
			}
		|	additive_expr LSS additive_expr
			{
				gen(opr, 0, 10);
			}
		|	additive_expr GEQ additive_expr
			{
				gen(opr, 0, 13);
			}
		|	additive_expr LEQ additive_expr
			{
				gen(opr, 0, 11);
			}
		|	additive_expr EQL additive_expr
			{
				gen(opr, 0, 8);
			}
		|	additive_expr NEQ additive_expr
			{
				gen(opr, 0, 9);
			}
		;

/* 加减表达式 */
additive_expr: additive_expr ADD term
			{
				gen(opr, 0, 2);
			}
		|	additive_expr SUB term
			{
				gen(opr, 0, 3);
			}
		|	term
			;
/* 项 */
term: term MUL factor
		{
			gen(opr, 0, 4);
		}
	| 	term DIV factor
		{
			gen(opr, 0, 5);
		}
	|	factor
          ;

/* 因子 */
factor: var
			{
				if ($1 == 0)
					yyerror("Symbol does not exist!");
				else
					gen(lod, lev - table[$1].level, table[$1].addr);
			}
        | 	NUM
			{
				gen(lit, 1, $1);
			}
		|	CHAR
			{
				gen(lit,2, $1);
			}
        |	LPAREN expression RPAREN
			{
				$$ = 0;
			}
		;

type: INTSYM
		{
			dec_type = 1;
		}
	|	CHARSYM
		{
			dec_type = 2;
		}
	;

/* 变量 */
var: ID
	{
		$$ = position ($1);
	}
	|	ID LSQBRK expression RSQBRK
		{
			//数组
			$$ = position($1);
			//还应该有其他操作
		}
	;


get_table_addr: {
					$$ = p_table;	// 记录本层标识符的初始位置
				}
				;

get_code_addr:	{
					$$ = p_code;
				}
				;



////////////////////////////////////////////////////////
//程序部分
%%

int yyerror(char *s)
{
	err_num = err_num + 1;
  	printf("\nError(%d): %s\n",line, s);
	return 0;
}

//  在符号表中加入一项
void enter(enum object k)
{
	p_table++; //符号表指针自增
	strcpy(table[p_table].name, id);//name
	table[p_table].kind = k;		//kind
	switch (k)
	{
		case var_int:	
			table[p_table].level = lev;
			table[p_table].val = num;
			break;
		case var_char:
			table[p_table].level = lev;
			table[p_table].val = num;
			break;
		case var_int_array:
			table[p_table].level = lev;
			table[p_table].arr_size = size;
			break;
		case var_char_array:
			table[p_table].level = lev;
			table[p_table].arr_size = size;

	}
}

// 为本层变量分配相对地址，从3开始分配
void set_addr(int n)
{
	//需要分配n个地址
	int i;
	for(i = 1; i <= n; i++)
		table[p_table - i + 1].addr = n - i + 3;
}

// 查找标识符在符号表中的位置
int position(char *s)
{
	int i;
	strcpy(table[0].name, s);//????
	i = p_table;
	while(strcmp(table[i].name, s) != 0)
		i--;
	return i;
}

// 初始化虚拟机
void init()
{
	p_table = 0;	//符号表指针
	p_code = 0;		//虚拟机指针
	
  	lev = 0;
  	num = 0;
  	
	err_num = 0;	//错误数
}


// 生成虚拟机代码 
void gen(enum fct x, int y, int z)
{
	if (p_code >= code_max)
	{
		printf("Program is %d longer than %d!\n", p_code, code_max);	// 生成的虚拟机代码程序过长
		exit(1);
	}
	if ( z >= addr_max)
	{
		printf("Displacement address %d is larger than %d!\n", z, addr_max);	//地址偏移越界
		exit(1);
	}
	//写入中间代码
	code[p_code].f = x;
	code[p_code].l = y;
	code[p_code].a = z;
	p_code++;
}

// 输出符号表
void print_table()
{
	printf("===Symbol Table===\n");
	int i;//符号表编号
	printf("     kind       name  val/level  address  size\n");
	for (i = 1; i <= p_table; i++)
	{
		switch (table[i].kind)
		{
			case var_int:
				printf("%3d  int  %8s", i, table[i].name);
				printf("%8d%10d%9d\n", table[i].val, table[i].addr,table[i].arr_size);
				break;
			case var_char:
				printf("%3d  char  %7s", i, table[i].name);
				printf("%8d%10d%9d\n", table[i].val, table[i].addr, table[i].arr_size);
				break;
			case var_int_array:
				printf("%3d  array_int  %2s", i, table[i].name);
				printf("%8d%10d%9d\n", table[i].val, table[i].addr, table[i].arr_size);
				break;
			case var_char_array:
				printf("%3d  array_char  %s", i, table[i].name);
				printf("%8d%10d%9d\n", table[i].val, table[i].addr, table[i].arr_size);
				break;
		}
	}
	printf("==================\n");
}



// 输出目标代码
void print_code()
{
	printf("===virtual code===\n");
	int cur = 0;	//current line number
	char name[][5]=
	{
		{"lit"},{"opr"},{"lod"},{"sto"},{"cal"},{"ini"},{"jmp"},{"jpc"},
	};
	
	//print
	for (cur = 0; cur < p_code; cur++)
		printf("%d %s %d %d\n", cur, name[code[cur].f], code[cur].l, code[cur].a);
	
	printf("==================\n");
}

void print_data_stack(int top, struct stack* s)
{
	//print data stack
	int t = top;
	printf("\n===Data Stack===\n");
	for(; t >= 0; t--)
	{
		printf("%d | %d\n",t,s[t].val);
	}
}

// 通过过程基址求上l层过程的基址
int base(int l, struct stack* s, int b)
{
	int b1;
	b1 = b;
	//level>0 不在当前层
	while (l > 0)
	{
		b1 = s[b1].val;
		l--;	//更新层数
	}
	//level=0 直接输出b 即b1
	return b1;
}

// 解释程序
void interpret()
{
	struct stack s[stack_max];		// 栈
	int top = 0;			// 栈顶指针
	int p = 0;				// 指令指针
	int base_addr = 1;		// 指令基址
	struct instruction i;	// 存放当前指令
	
	printf("Execute x0...\n");

	//主程序栈底初始化
	s[0].val = 0; // s[0]不用
	s[1].val = 0; // SL 主程序的三个联系单元均置为0
	s[2].val = 0; // DL
	s[3].val = 0; // RA


	do {
		#ifdef DEBUG
			printf("----- After Code %d -----\n",p);
		#endif
	    i = code[p++];	// 读当前指令 更新p
		switch (i.f)	// 解释过程
		{
			case lit:	// 将常量a的值放入栈顶
				top++;			//栈顶指针指向空位
				switch (i.l)
				{
					case 1://int
						s[top].tp = var_int;
						s[top].val = i.a;
						break;
					case 2://char
						s[top].tp = var_char;
						s[top].val = i.a;
						break;
					case 3://array int
						break;
					case 4://array char
						break;
				}
				break;
			case lod:	// 取相对地址为a的内存的值到栈顶
				top++;
				s[top].val = s[base(i.l,s,base_addr) + i.a].val;
				break;
			case sto:	// 栈顶的值存到相对地址为a处
				s[base(i.l, s, base_addr) + i.a].val = s[top].val;
				top--;	//存储后出栈
				break;
			case cal:	// 调用子过程 NOT USED
				s[top + 1].val = base(i.l, s, base_addr);	/* 将父过程基地址入栈，即建立静态链 */
				s[top + 2].val = base_addr;	/* 将本过程基地址入栈，即建立动态链 */
				s[top + 3].val = p;	/* 将当前指令指针入栈，即保存返回地址 */
				base_addr = top + 1;	/* 改变基地址指针值为新过程的基地址 */
				p = i.a;	/* 跳转 */
				break;
			case ini:	// 在数据栈中为被调用的过程开辟a个单元的数据区
				top += i.a;
				break;
			case jmp:	// 直接跳转
				p = i.a;
				break;
			case jpc:	// 条件跳转
				if (s[top].val == 0)//??
					p = i.a;
				top--;
				break;
			case opr:	// 数学or逻辑运算
				switch (i.a)
				{
					case 0:	// 函数调用结束后返回
						top = base_addr - 1;
						p = s[top + 3].val; 
						base_addr = s[top + 2].val;
						break;
					case 1: // 栈顶元素取反 NOT USED
						s[top].val = - s[top].val;
						break;
					case 2: // 加法 栈顶两数相加 值进栈
						top--;
						s[top].val = s[top].val + s[top+1].val;
						break;
					case 3:	// 减法
						top--;
						s[top].val = s[top].val - s[top+1].val;
						break;
					case 4:	// 乘法
						top--;
						s[top].val = s[top].val * s[top+1].val;
						break;
					case 5:	// 除法
						top--;
						s[top].val = s[top].val / s[top+1].val;
						break;
					case 6: // 奇偶判断 NOT USED
						s[top].val = s[top].val % 2;
						break;
					case 7: // NOT USED
						break;
					case 8:	// ==
						top--;
						s[top].val = (s[top].val == s[top + 1].val);
						break;
					case 9: // !=
						top--;
						s[top].val = (s[top].val != s[top + 1].val);
						break;
					case 10: // <
						top--;
						s[top].val = (s[top].val < s[top + 1].val);
						break;
					case 11: // <=
						top--;
						s[top].val = (s[top].val <= s[top + 1].val);
						break;
					case 12: // >
						top--;
						s[top].val = (s[top].val > s[top + 1].val);
						break;
					case 13: // >=
						top--;
						s[top].val = (s[top].val >= s[top + 1].val);
						break;
					case 14: // pop 出栈
						printf("\nOUTPUT:");
						switch (s[top].tp)
						{
							case var_int:
								printf(" %d\n", s[top].val);
								break;
							case var_char:
								if(s[top].val >= 32 && s[top].val <= 126)
									printf(" %c\n", s[top].val);
								else
									yyerror("Not a character!");
								break;
							case var_int_array:
								printf(" %d\n", s[top].val);
								break;
							case var_char_array:
								if(s[top].val >= 32 && s[top].val <= 126)
									printf(" %c\n", s[top].val);
								else
									yyerror("Not a character!");
								break;
						}		
						top--;
						break;
					case 15: // 输出换行符
						printf("\n");
						break;
					case 16: // push 读入一个输入值并入栈
						top++;
						printf("input : ");
						scanf("%d\n", &(s[top].val));
						break;
				}
				break;		
		}
		#ifdef DEBUG
		print_table();
		print_data_stack(top,s);
		#endif
	} while (p != 0);
	printf("Execute over.\n");



}

int main(void)
{
	//printf("Input x0 file name:	");
	//scanf("%s", input);				// 输入文件名
	strcpy(input, "test0.x0");
	
	//open input file
	if ((fin = fopen(input, "r")) == NULL)
	{
		printf("Error(0): Can't open the file %s!\n", input);
		exit(1);
	}

	redirectInput(fin);	//set input file to 'yyin'

	init();				//initial virtual machine
  	yyparse();			//build complier

	if(err_num == 0)
	{
		printf("\n===Parsing success!===\n");
		print_code();	// 输出所有中间代码
		interpret();	// 调用解释执行程序
	}
  	else
	{
		printf("Error: %d errors in x0 program.\n", err_num);
	}

	return 0;
}



