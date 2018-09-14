/* Reverse Polish Notation calculator. */



%{
#include <stdlib.h> /* malloc */
#include <stdio.h> /* For pinrtf, etc. */
#include <math.h> /* For pow, used in the grammar. */
#include <string.h> /* strlen. */
#include <ctype.h>
#include "mfcalc.h" /* Contains definition of 'symrec' */

typedef struct YYLTYPE 
{
	double first_line;
	double first_column;
	double last_line;
	double last_column;
} YYLTYPE;

#define YYLTYPE YYLTYPE

# define YYLLOC_DEFAULT(Cur, Rhs, N) \
do \
	if (N) \
	{ \
		(Cur).first_line = YYRHSLOC(Rhs, 1).first_line; \
		(Cur).first_column = YYRHSLOC(Rhs, 1).first_column; \
		(Cur).last_line = YYRHSLOC(Rhs, N).last_line; \
		(Cur).last_column = YYRHSLOC(Rhs, N).last_column; \
	} \
	else \
	{ \
		(Cur).first_line	= (Cur).last_line	= YYRHSLOC(Rhs, 0).last_line; \
		(Cur).first_column = (Cur).last_column = YYRHSLOC(Rhs, 0).last_column; \
	} \
while (0)

int yylex (void);
void yyerror (char const *);
%}

%require "3.0.4"

/* Bison declarations.	*/ 
%define api.value.type union /* Generate YYSTYPE from these types. */ 
%token <double> NUM /* Simple double precision number. */
%token <symrec*> VAR FNCT /* Symbol table pointer; variable and functioin. */
%token <char*> STRING /* Simple string. */
%type <double> exp
%precedence EQU '='
%left MIN '-' PLUS'+'
%left MUL '*' DIV '/'
%precedence NEG	/* negation(unary minus) */ 
%right EXP '^'	/* exponentiation */

%destructor { printf ("discard symbol width type, position %lf.\n", @$.first_line); } <*>
%destructor { printf ("discard symbol without type, position %lf.\n", @$.first_line); } <>
/**/
%destructor { free ($$); printf ("discard symbol typed symrec*, position %lf.\n", @$.first_line); } <char*> 
%destructor { printf ("discard symbol nameed NUM, position %lf.\n", @$.first_line); } NUM

%%
/* The grammar follows.	*/ 
input:
%empty
| input line
;

line:
'\n'
| exp '\n'	{ printf ("\t%.10g\n", $1); }
| error '\n' { yyerror; }
;

exp[result]:
NUM	{ $$ = $1;	}
| VAR { $result = $VAR->value.var; }
| VAR '=' exp { $$ = $3; $1->value.var = $3; }
| FNCT '(' exp ')' { $$ = (*($1->value.fnctptr))($3); }
| exp '+' exp	{ $$ = $1 + $3;	}
| exp '-' exp	{ $$ = $1 - $3;	}
| exp '*' exp	{ $$ = $1 * $3;	}
| exp[left] '/' exp[right]
	{
		if($3) {
			$result = $left / $right;	
		}
		else {
			$result = 1;
			fprintf(stderr, "%lf.%lf-%lf.%lf: division by zero", @3.first_line, @3.first_column, @3.last_line, @3.last_column);
		}
	}
| '-' exp	%prec NEG { $$ = -$2;	}
| exp '^' exp	{ $$ = pow ($1, $3); }
| '(' exp ')'	{ $$ = $2;	}
;
%%

symrec *
putsym (char const *sym_name, int sym_type)
{
	symrec *ptr = (symrec *) malloc (sizeof (symrec)); 
	ptr->name = (char *) malloc (strlen (sym_name) + 1); 
	strcpy (ptr->name,sym_name);
	ptr->type = sym_type;
	ptr->value.var = 0; /* Set value to 0 even if fctn.	*/ 
	ptr->next = (struct symrec *)sym_table;
	sym_table = ptr; 
	return ptr;
}

symrec *
getsym (char const *sym_name)
{
	symrec *ptr;
	for (ptr = sym_table; ptr != (symrec *) 0; ptr = (symrec *)ptr->next)
		if (strcmp (ptr->name, sym_name) == 0) 
			return ptr;
	return 0;
}

symrec *
removesym (char const *sym_name)
{
	symrec *pre_ptr = ((void *)0);
	symrec *ptr = sym_table;
	while (ptr != (symrec *) 0) {
		if (strcmp (ptr->name, sym_name) == 0) 
			break;
		pre_ptr = ptr;
		ptr = (symrec *)ptr->next;
	}
	
	if (pre_ptr) 
	{
		pre_ptr->next = ptr->next;
	}

	free(ptr);
}

/* Called by yyparse on error.	*/ 
void
yyerror (char const *s)
{
	fprintf (stderr, "%s\n", s);
}

int
yylex (void)
{
	int c;

	/* Ignore white space, get first nonwhite character.	*/ 
	while ((c = getchar ()) == ' ' || c == '\t')
		++yylloc.last_column;

	/* Step. */
	yylloc.first_line = yylloc.last_line;
	yylloc.first_column = yylloc.last_column;

	if (c == EOF) return 0;

	/* Char starts a number => parse the number.	*/ 
	if (c == '.' || isdigit (c))
	{
		double decimalSize = 1;
		int dcimalStartMark = 0;
		if (c == '.') 
		{
			dcimalStartMark = 1;
		}

		double num = c - '0';
		++yylloc.last_column;
		while (isdigit(c = getchar ()) || c == '.') {
			if (dcimalStartMark == 1) 
			{
				decimalSize *= 10;
			}

			if (c == '.') {
				dcimalStartMark = 1;
				continue;
			}
			/* update location. */
			++yylloc.last_column;

			num = num * 10 + c - '0';
		}

		yylval.NUM = num / decimalSize;

		/* push last non-digit charactor to stdin */
		ungetc (c, stdin);

		return NUM;
	}

	/* Char starts an identifier => read the name.	*/ 
	if (isalpha (c))
	{
		/* Initially make the buffer long enough for a 40-character symbol name.	*/
		static size_t length = 40; 
		static char *symbuf = 0; 
		symrec *s;
		int i;
		if (!symbuf)
		{
			symbuf = (char *) malloc (length + 1); 
		}

		i = 0;
		do
		{
			/* If buffer is full, make it bigger.	*/ 
			if (i == length)
			{
				length *= 2;
				symbuf = (char *) realloc (symbuf, length + 1);
			}

			/* Add this character to the buffer.	*/ 
			symbuf[i++] = c;

			/* Get another character.	*/ 
			c = getchar ();

			/* update location. */
			++yylloc.last_column;
		} while (isalnum (c));

		ungetc (c, stdin); 
		symbuf[i] = '\0';

		/* try to find the symbol */
		s = getsym (symbuf); 

		/* push new symbol */
		if (s == 0)
			s = putsym (symbuf, VAR);

		yylval.VAR = s; 

		/* return symbol type */
		return VAR;
	}

	/* update location. */
	if (c == '\n') {
  	++yylloc.last_line;
  	yylloc.last_column = 0;
  }
  else {
  	++yylloc.last_column;
  }

	/* Any other character is a token by itself.	*/ 
	return c;
}

struct init
{
	char const *fname; 
	double (*fnct) (double);
};

struct init const arith_fncts[] =
{
	{ "atan", atan },
	{ "cos",	cos	},
	{ "exp",	exp	},
	{ "ln",	log	},
	{ "sin",	sin	},
	{ "sqrt", sqrt },
	{ "ceil", ceil },
	{ "floor", floor },
	{ 0, 0 }
};

struct init_constant
{
	char const *name; 
	double val;
};

struct init_constant const constants[] =
{
	{ "PI", 3.1415926 },
	{ "ZERO",	0	},
	{ "INFINITE",	99999 },
	{ 0, 0 }
};

/* The symbol table: a chain of 'struct symrec'.	*/ 
symrec *sym_table;

/* Put arithmetic functions in table.	*/ 
static
void
init_table (void)
{
	int i;
	for (i = 0; arith_fncts[i].fname != 0; i++)
	{
		symrec *ptr = putsym (arith_fncts[i].fname, FNCT);
		ptr->value.fnctptr = arith_fncts[i].fnct;
	}

	for (i = 0; constants[i].name != 0; i++)
	{
		symrec *ptr = putsym (constants[i].name, VAR);
		ptr->value.var = constants[i].val;
	}
}

int
main (int argc, char const* argv[])
{
	yylloc.first_line = yylloc.last_line = 1;
	yylloc.first_column = yylloc.last_column = 0;
	init_table (); 
	return yyparse ();
}
