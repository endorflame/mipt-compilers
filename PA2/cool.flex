/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/*
 *  Add Your own definitions here
 */

int comment_level = 0; /* to trace nested comments */

#define CHECK_STRING_OVERFLOW;		if(strlen(string_buf) + 1 + 1 > MAX_STR_CONST)\
                    {\
                        cool_yylval.error_msg = "String constant too long";\
                        BEGIN(STRING_ERROR);\
                        return ERROR;\
                    }\
%}

%option  yylineno

%x STRING
%x STRING_ERROR

%x COMMENT
%x COMMENT_DASH

/*
 * Define names for regular expressions here.
 */

/* Option "?i:foo" is equivalent to option "[fF][oO][oO]" and used for convinience */

CLASS		(?i:class)
ELSE		(?i:else)
FALSE		f(?i:alse)
FI		(?i:fi)
IF		(?i:if)
IN		(?i:in)
INHERITS	(?i:inherits)
ISVOID		(?i:isvoid)
LET		(?i:let)
LOOP		(?i:loop)
POOL		(?i:pool)
THEN		(?i:then)
WHILE		(?i:while)
CASE		(?i:case)
ESAC		(?i:esac)
NEW		(?i:new)
OF		(?i:of)
NOT		(?i:not)
TRUE		t(?i:rue)

BOOL		{TRUE}|{FALSE}
CHAR		[A-Za-z]
DIGIT		[0-9]
INTEGER		{DIGIT}+
NEWLINE		"\n"
CAPITAL		[A-Z]
LOWER		[a-z]
OPS 		[-=:;.(){}@,~+*/<]
WHITESPACE	[ \n\f\r\t\v]*

OBJECTID	{LOWER}({CHAR}|{DIGIT}|"_")*
TYPEID		{CAPITAL}({CHAR}|{DIGIT}|"_")*
SELFID		"self"
SELF_TYPEID	"SELF_TYPE"

DARROW          =>
ASSIGN 		<-
LE		<=

%%

*/ Nested comments */

<INITIAL>--             {BEGIN(COMMENT_DASH);}
<COMMENT_DASH><<EOF>> {
	 curr_lineno = yylineno;
	 yyterminate();
}
                        
<COMMENT_DASH>[\n]      { curr_lineno = yylineno; BEGIN(INITIAL); }
<COMMENT_DASH>[^\n]     {}
<INITIAL>"(*"           { BEGIN(COMMENT); comment_level++; }
<INITIAL>"*)"           {
                          curr_lineno = yylineno;
                          cool_yylval.error_msg = "Unmatched *)";
                          return ERROR;
                        }

<COMMENT>"("+"*"        {  comment_level++;
                        }
<COMMENT>"*"+")"        {  comment_level--;
                           if (comment_level == 0)
                           {
                              BEGIN(INITIAL);
                           }
                        }
<COMMENT>[^*(]|"("[^*]|"*"[^)] {}
<COMMENT><<EOF>>        {
                            curr_lineno = yylineno;
                            cool_yylval.error_msg = "EOF in comment";
			    BEGIN(INITIAL);
			    return ERROR;
                        }

<INITIAL>\"     {
                    strcpy(string_buf, "");
                    BEGIN(STRING);
                }
<STRING>\"      {   
                    BEGIN(INITIAL); 
                    curr_lineno=yylineno;
				    cool_yylval.symbol = stringtable.add_string(string_buf);
				    return STR_CONST;
                }

<STRING>\\b     {  
                    curr_lineno = yylineno;
                    CHECK_STRING_OVERFLOW;                              
                    strcat(string_buf, "\b");
                }
<STRING>\\t     {  
                    curr_lineno = yylineno;
                    CHECK_STRING_OVERFLOW;                 
                    strcat(string_buf, "\t");
                }                
<STRING>\\n     {  
                    curr_lineno = yylineno;
                    CHECK_STRING_OVERFLOW;             
                    strcat(string_buf, "\n");
                }
<STRING>\\f     {  
                    curr_lineno=yylineno;
                    CHECK_STRING_OVERFLOW;                 
                    strcat(string_buf, "\f");
                }
<STRING>\\\x00  {
                    BEGIN(STRING_ERROR);
                    curr_lineno = yylineno;
                    cool_yylval.error_msg = "String contains escaped null character.";
                    return ERROR;
                }
<STRING>\\.     { 
                    curr_lineno=yylineno;
                    CHECK_STRING_OVERFLOW;                                
                    strcat(string_buf, yytext+1);
                }                              
                
<STRING>\\\n    {  
                    curr_lineno=yylineno;
                    CHECK_STRING_OVERFLOW;            
                    strcat(string_buf, "\n");
                }                
<STRING>\n      {  
                    BEGIN(INITIAL);
                    curr_lineno = yylineno;
                    cool_yylval.error_msg = "Unterminated string constant"; 
                    return ERROR;
                }

<STRING>\x00	{ 
                    BEGIN(STRING_ERROR);
                    curr_lineno = yylineno;
                    cool_yylval.error_msg = "String contains null character.";
                    return ERROR;
                }    
                    
                 
<STRING>([^"\\\n\x00])+     {  
                                curr_lineno=yylineno;
                                if(strlen(string_buf) + strlen(yytext) + 1 > MAX_STR_CONST)
                                {  
                                    cool_yylval.error_msg = "String constant too long";
                                    BEGIN(STRING_ERROR);
                                    return (ERROR);
                                }                                 
                                strcat(string_buf, yytext);
                            }
<STRING_ERROR>[^\\]\n    {BEGIN(INITIAL);}
<STRING_ERROR>\"         {BEGIN(INITIAL);}
<STRING_ERROR>.     {}
<STRING_ERROR>\n    {}
<STRING><<EOF>> {
                    curr_lineno = yylineno;
                    cool_yylval.error_msg = "EOF in string constant";
                    BEGIN(INITIAL);
                    return ERROR;
                }

 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */		
<INITIAL>{CLASS}        {  curr_lineno = yylineno;  return CLASS; }	
<INITIAL>{ELSE}         {  curr_lineno = yylineno;  return ELSE;  }				
<INITIAL>{FI}    		{  curr_lineno = yylineno;  return FI;    }	
<INITIAL>{IF}           {  curr_lineno = yylineno;  return IF;    }				
<INITIAL>{IN}		   	{  curr_lineno = yylineno;  return IN;    }	
<INITIAL>{INHERITS}		{  curr_lineno = yylineno;  return INHERITS;  }		
<INITIAL>{LET}			{  curr_lineno = yylineno;  return LET;   }
<INITIAL>{LOOP}			{  curr_lineno = yylineno;  return LOOP;  }	
<INITIAL>{POOL}      	{  curr_lineno = yylineno;  return POOL;  }	
<INITIAL>{THEN}        	{  curr_lineno = yylineno;  return THEN;  }					
<INITIAL>{WHILE}		{  curr_lineno = yylineno;  return WHILE; }	
<INITIAL>{CASE}			{  curr_lineno = yylineno;  return CASE;  }	
<INITIAL>{ESAC}			{  curr_lineno = yylineno;  return ESAC;  }	
<INITIAL>{NEW}			{  curr_lineno = yylineno;  return NEW;   }
<INITIAL>{ISVOID}		{  curr_lineno = yylineno;  return ISVOID;} 				
<INITIAL>{OF}			{  curr_lineno = yylineno;  return OF;    }	
<INITIAL>{NOT}          {  curr_lineno = yylineno;  return NOT;   }
<INITIAL>{FALSE}	    {  cool_yylval.boolean = false;
                           curr_lineno = yylineno;
				           return BOOL_CONST;                      }
<INITIAL>{TRUE}			{  cool_yylval.boolean = true;
                           curr_lineno = yylineno;
				           return BOOL_CONST;                      }	
 /*
  *  Operators.
  */						   
<INITIAL>{DARROW}		{  curr_lineno = yylineno;  return DARROW;    }	
<INITIAL>"<-"		    {  curr_lineno = yylineno;  return ASSIGN;    } 	
<INITIAL>"+" 			{  curr_lineno = yylineno;  return int('+');  }
<INITIAL>"/"		    {  curr_lineno = yylineno;  return int('/');  }
<INITIAL>"-"			{  curr_lineno = yylineno;  return int('-');  }
<INITIAL>"*"			{  curr_lineno = yylineno;  return int('*');  }
<INITIAL>"="		    {  curr_lineno = yylineno;  return int('=');  }
<INITIAL>"<"		    {  curr_lineno = yylineno;  return int('<');  }
<INITIAL>"<="			{  curr_lineno = yylineno;  return LE;        }
<INITIAL>"."		    {  curr_lineno = yylineno;  return int('.');  }
<INITIAL>"~"			{  curr_lineno = yylineno;  return int('~');  }
<INITIAL>","			{  curr_lineno = yylineno;  return int(',');  }
<INITIAL>";"			{  curr_lineno = yylineno;  return int(';');  }
<INITIAL>":"			{  curr_lineno = yylineno;  return int(':');  }
<INITIAL>"("			{  curr_lineno = yylineno;  return int('(');  }
<INITIAL>")"		    {  curr_lineno = yylineno;  return int(')');  }
<INITIAL>"@"			{  curr_lineno = yylineno;  return int('@');  }
<INITIAL>"{"			{  curr_lineno = yylineno;  return int('{');  }
<INITIAL>"}"			{  curr_lineno = yylineno;  return int('}');  }
<INITIAL>{DIGIT}+       {  cool_yylval.symbol = inttable.add_string(yytext); 
                           curr_lineno = yylineno;                 
                           return INT_CONST;
				        }
 /*
 *  Identifiers
 */                        
<INITIAL>{TYPEID}       {  cool_yylval.symbol = stringtable.add_string(yytext); 
                           curr_lineno = yylineno;                 
                           return TYPEID;
				        } 	
<INITIAL>{OBJECTID}     {  cool_yylval.symbol = stringtable.add_string(yytext); 
                           curr_lineno = yylineno;                 
                           return OBJECTID;
				        }
                        
<INITIAL>{NEWLINE}      {}					
<INITIAL>{WHITESPACE}	{}
<INITIAL>.              { 
                           curr_lineno = yylineno;
                           cool_yylval.error_msg = yytext;
				           return ERROR;
				        }					
