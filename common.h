#ifndef _COMMON_H_
#define _COMMON_H_

typedef double (*func_t) (double);

/* Data type for links in the chain of symbols.	*/ 
struct symrec
{
	char *name;	/* name of symbol */
	int type;	/* type of symbol: either VAR or FNCT */ 
	union
	{
		double var;	/* value of a VAR */ 
		func_t fnctptr;	/* value of a FNCT */
	} value;
	struct symrec *next;	/* link field */
};

typedef struct symrec symrec;

/* The symbol table: a chain of ’struct symrec’.	*/ 
extern symrec *sym_table;

extern symrec *putsym (char const *, int); 
extern symrec *getsym (char const *);
#endif