%{
  #include <stdio.h>
  #include <stdlib.h>
  #include <math.h>
  #include <string.h>
  #include "defs.h"
  #include "symtab.h"
  #include "codegen.h"

  int yyparse(void);
  int yylex(void);
  int yyerror(char *s);
  void warning(char *s);

  extern int yylineno;
  int out_lin = 0;
  char char_buffer[CHAR_BUFFER_LENGTH];
  int error_count = 0;
  int warning_count = 0;
  int var_num = 0;
  int gl_var_num = 0;
  int fun_idx = -1;
  int fcall_idx = -1;
  unsigned var_type = 0;
  int has_return = 0;
  int check_var_type = 0;
  char check_const_names[SYMBOL_TABLE_LENGTH][20];
  int check_const_iter = 0;
  int check_const_repeat = 0;
  int lab_num = 0;
  int while_num = -1;
  int check_num = -1;
  int num_rel = 0;
  int cond_if_while = 0;
  FILE *output;
%}

%union {
  int i;
  char *s;
}

%token <i> _TYPE
%token _IF
%token _ELSE
%token _RETURN
%token <s> _ID
%token <s> _INT_NUMBER
%token <s> _UINT_NUMBER
%token _LPAREN
%token _RPAREN
%token _LBRACKET
%token _RBRACKET
%token _ASSIGN
%token _SEMICOLON
%token _COMMA
%token <i> _AROP
%token <i> _RELOP
%token <i> _LOGOP
%token _INCREMENT
%token _WHILE
%token _CHECK
%token _WHEN
%token _BREAK
%token _OTHERWISE
%token _COLON
%token _QMARK

%type <i> num_exp exp literal function_call arguments rel_exp cond_exp postinc parameters only_params if_part cond_op exp_c when_literal_part check_part

%nonassoc ONLY_IF
%nonassoc _ELSE

%%

program
  : global_var_list function_list
      {  
        if(lookup_symbol("main", FUN) == NO_INDEX)
          err("undefined reference to 'main'");
       }
  ;
  
global_var_list
	: /* empty */
	| global_var_list global_var
	;
	
global_var
	: _TYPE _ID _SEMICOLON
		{
        if(lookup_symbol($2, GL_VAR) == NO_INDEX) {
           insert_symbol($2, GL_VAR, $1, ++gl_var_num, NO_ATR);
           gen_glob_var(lookup_symbol($2, GL_VAR));
           
        }
        else 
           err("redefinition of '%s'", $2);
		}
	;

function_list
  : function
  | function_list function
  ;

function
  : _TYPE _ID
      {
        fun_idx = lookup_symbol($2, FUN);
        if(fun_idx == NO_INDEX)
          fun_idx = insert_symbol($2, FUN, $1, NO_ATR, NO_ATR);
        else 
          err("redefinition of function '%s'", $2);
          
          code("\n%s:", $2);
        	code("\n\t\tPUSH\t%%14");
        	code("\n\t\tMOV \t%%15,%%14");
      }
    _LPAREN parameters _RPAREN body
      {
      	if ($5 > 9)
      		err("function '%s' has too many arguments", $2);
        clear_symbols(fun_idx + 1);
        var_num = 0;
        if (get_type(fun_idx) != VOID && has_return == 0)
        	warn("no 'return', in function returning non-void");
        has_return = 0;
        
        code("\n@%s_exit:", $2);
        code("\n\t\tMOV \t%%14,%%15");
        code("\n\t\tPOP \t%%14");
        code("\n\t\tRET");
      }
  ;

parameters
  : /* empty */
      { set_atr1(fun_idx, 0); $$ = 0;}

  | only_params
  ;
  
only_params
	: _TYPE _ID
      {
        insert_symbol($2, PAR, $1, 1, NO_ATR);
        set_atr1(fun_idx, 1);
        set_atr2(fun_idx, $1);
        $$ = 1;
      }
  | only_params _COMMA _TYPE _ID
  		{
  			$$ = $$ + 1;
  			if(lookup_symbol($4, VAR|PAR) == NO_INDEX) {
        	insert_symbol($4, PAR, $3, $$, NO_ATR);
        }
    		else 
      		err("redefinition of '%s'", $4);
      		
      	set_atr1(fun_idx, $$);
        set_atr2(fun_idx, get_atr2(fun_idx)*10 + $3);
			}
	;

body
  : _LBRACKET variable_list 
  		{
        if(var_num)
          code("\n\t\tSUBS\t%%15,$%d,%%15", 4*var_num);
        code("\n@%s_body:", get_name(fun_idx));
    	}
  	statement_list _RBRACKET
  ;

variable_list
  : /* empty */
  | variable_list variable
  ;

variable
  : _TYPE
  	{
  		var_type = $1;
  	}
  	vars _SEMICOLON
  ;
  
vars
	: _ID
		{
		if (var_type == VOID)
  			err("variable '%s' declared void", $1);
        if(lookup_symbol($1, VAR|PAR) == NO_INDEX)
           insert_symbol($1, VAR, var_type, ++var_num, NO_ATR);
        else 
           err("redefinition of '%s'", $1);
  	}
	| vars _COMMA _ID
		{
		if (var_type == VOID)
  			err("variable '%s' declared void", $3);
		if(lookup_symbol($3, VAR|PAR) == NO_INDEX)
			insert_symbol($3, VAR, var_type, ++var_num, NO_ATR);
    else 
      err("redefinition of '%s'", $3);
		}
	;

statement_list
  : /* empty */
  | statement_list statement
  ;

statement
  : compound_statement
  | assignment_statement
  | if_statement
  | return_statement
  | postinc_statement
  | while_statement
  | check_statement
  ;

compound_statement
  : _LBRACKET statement_list _RBRACKET
  ;

assignment_statement
  : _ID _ASSIGN num_exp _SEMICOLON
      {
        int idx = lookup_symbol($1, VAR|PAR|GL_VAR);
        if(idx == NO_INDEX)
          err("invalid lvalue '%s' in assignment", $1);
        else
          if(get_type(idx) != get_type($3))
            err("incompatible types in assignment");
        gen_mov($3, idx);
      }
  ;

num_exp
  : exp
  | num_exp _AROP exp
      {
        if(get_type($1) != get_type($3))
          err("invalid operands: arithmetic operation");
        else {
		      int t1 = get_type($1);    
		      code("\n\t\t%s\t", ar_instructions[$2 + (t1 - 1) * AROP_NUMBER]);
		      gen_sym_name($1);
		      code(",");
		      gen_sym_name($3);
		      code(",");
		      free_if_reg($3);
		      free_if_reg($1);
		      $$ = take_reg();
		      gen_sym_name($$);
		      set_type($$, t1);
        }
      }
  ;

exp
  : literal
  | _ID
      {
        $$ = lookup_symbol($1, VAR|PAR|GL_VAR);
        if($$ == NO_INDEX)
          err("'%s' undeclared", $1);
      }
  | function_call
  		{
        $$ = take_reg();
        gen_mov(FUN_REG, $$);
      }
  | _LPAREN num_exp _RPAREN
      { $$ = $2; }
  | postinc
  | cond_op
  ;

literal
  : _INT_NUMBER
      { $$ = insert_literal($1, INT); }

  | _UINT_NUMBER
      { $$ = insert_literal($1, UINT); }
  ;

function_call
  : _ID 
      {
        fcall_idx = lookup_symbol($1, FUN);
        if(fcall_idx == NO_INDEX)
          err("'%s' is not a function", $1);
      }
    _LPAREN arguments _RPAREN
      {
        if(get_atr1(fcall_idx) != $4)
          err("wrong number of args to function '%s'", 
              get_name(fcall_idx));
        code("\n\t\t\tCALL\t%s", get_name(fcall_idx));
        if($4 > 0)
          code("\n\t\t\tADDS\t%%15,$%d,%%15", $4 * 4);
        set_type(FUN_REG, get_type(fcall_idx));
        $$ = FUN_REG;
      }
  ;

arguments
  : /* empty */
    { $$ = 0; }

  | num_exp
    { 
      if((unsigned long)(get_atr2(fcall_idx) / pow(10,(get_atr1(fcall_idx)-1))) != get_type($1))
        err("incompatible type for argument in '%s'",
            get_name(fcall_idx));
      free_if_reg($1);
      code("\n\t\t\tPUSH\t");
      gen_sym_name($1);
      $$ = 1;
    }
  | arguments _COMMA num_exp
  	{
  		$$ = $$ + 1;
  		if ((unsigned long)(get_atr2(fcall_idx) / pow(10,(get_atr1(fcall_idx)-$$))) % 10 != get_type($3))
  			err("incompatible type for argument in '%s'",
            get_name(fcall_idx));
      free_if_reg($3);
      code("\n\t\t\tPUSH\t");
      gen_sym_name($3);
  	}
  ;

if_statement
  : if_part %prec ONLY_IF
  	{ code("\n@exit%d:", $1); }
  | if_part _ELSE statement
  	{ code("\n@exit%d:", $1); }
  ;

if_part
  : _IF _LPAREN
  		{
        $<i>$ = lab_num++;
        code("\n@if%d:", lab_num-1);
        cond_if_while = 1;
      }
  	cond_exp
  		{
        if (num_rel == 1) {
        	code("\n\t\t%s\t@false%d", opp_jumps[$4], lab_num-1);
        }
        code("\n@true%d:", $<i>3);
        num_rel = 0;
        cond_if_while = 0;
      }
  	_RPAREN statement
  		{
        code("\n\t\tJMP \t@exit%d", $<i>3);
        code("\n@false%d:", $<i>3);
        $$ = $<i>3;
      }
  ;

cond_exp
	: rel_exp
		{
			num_rel++;
		}
	| cond_exp _LOGOP 
		{
			num_rel++;
			if (num_rel == 2) {
				if (cond_if_while == 0) {
					if ($2 == OR) 
						code("\n\t\t%s\t@true%d", jumps[$1], lab_num);
					else
						code("\n\t\t%s\t@false%d", opp_jumps[$1], lab_num);
				}
				else if (cond_if_while == 1) {
					if ($2 == OR) 
						code("\n\t\t%s\t@true%d", jumps[$1], lab_num-1);
					else
						code("\n\t\t%s\t@false%d", opp_jumps[$1], lab_num-1);
				}
				else if (cond_if_while == 2){
					if ($2 == OR) {
						code("\n\t\t%s\t@while_true%d", jumps[$1], while_num);
					}
					else {
						code("\n\t\t%s\t@exit_while%d", opp_jumps[$1], while_num);
					}
				}
			}
		}
		rel_exp
		{	
				if (cond_if_while == 0) {
					if ($2 == OR) 
						code("\n\t\t%s\t@true%d", jumps[$4], lab_num);
					else
						code("\n\t\t%s\t@false%d", opp_jumps[$4], lab_num);
				}
				else if (cond_if_while == 1) {
					if ($2 == OR) 
						code("\n\t\t%s\t@true%d", jumps[$4], lab_num-1);
					else
						code("\n\t\t%s\t@false%d", opp_jumps[$4], lab_num-1);
				}
				else if (cond_if_while == 2) {
					if ($2 == OR) {
						code("\n\t\t%s\t@exit_while%d", opp_jumps[$4], while_num);
					}
					else {
						code("\n\t\t%s\t@exit_while%d", opp_jumps[$4], while_num);
					}
				}
		}
	;
	
rel_exp
  : num_exp _RELOP num_exp
      {
        if(get_type($1) != get_type($3))
          err("invalid operands: relational operator");
        $$ = $2 + ((get_type($1) - 1) * RELOP_NUMBER);
        gen_cmp($1, $3);
      }
  ;

return_statement
  : _RETURN num_exp _SEMICOLON
      {
      	has_return = 1;
      	if (get_type(fun_idx) == VOID)
      		err("'return' with value, in function returning void");
        else if(get_type(fun_idx) != get_type($2))
          err("incompatible types in return");
        gen_mov($2, FUN_REG);
        code("\n\t\tJMP \t@%s_exit", get_name(fun_idx));
      }
  | _RETURN _SEMICOLON
  	{
  		has_return = 1;
  		if (get_type(fun_idx) != VOID)
  			warn("'return' with no value, in function returning non-void");
  		code("\n\t\tJMP \t@%s_exit", get_name(fun_idx));
  	}
  ;
  
postinc_statement
	: postinc _SEMICOLON
	;
	
postinc
	: _ID _INCREMENT
		{
        int idx = lookup_symbol($1, VAR|PAR|GL_VAR);
        if(idx == NO_INDEX)
          err("'%s' undeclared", $1);
        else {
        	$$ = take_reg();
					gen_mov(idx, $$);
		      int t1 = get_type(idx);  
		      code("\n\t\t%s\t", ar_instructions[(t1 - 1) * AROP_NUMBER]);
		      gen_sym_name(idx);
		      code(",");
		      code("$1");
		      code(",");
		      free_if_reg(idx);
		      gen_sym_name(idx);
		      free_if_reg(idx);
        }
    }
	;
	
while_statement
	: _WHILE _LPAREN
		{
      $<i>$ = ++while_num;
      code("\n@while%d:", while_num);
      cond_if_while = 2;
    }
	  cond_exp
		{
			if (num_rel == 1)
      	code("\n\t\t%s\t@exit_while%d", opp_jumps[$4], $<i>3);
      //code("\n\t\tJMP\t@exit_while%d", $<i>3);
      num_rel = 0;
      cond_if_while = 0;
      code("\n@while_true%d:", $<i>3);
    }
	  _RPAREN statement
	  {
        code("\n\t\tJMP \t@while%d", $<i>3);
        code("\n@exit_while%d:", $<i>3);
	  }
	;
	
check_statement
	: check_part _RBRACKET
	{
		code("\n\t\tJMP \t@exit_check%d", check_num);
		code("\n@exit_when%d:", check_num);
		for (int i = 0; i < check_const_iter; ++i) {
				if(get_type($1) == INT)
    			code("\n\t\tCMPS \t");
				else
					code("\n\t\tCMPU \t");
				gen_sym_name($1);
				code(",$%s", check_const_names[i]);
				free_if_reg($1);
				code("\n\t\tJEQ \t@when%d%s", check_num, check_const_names[i]);
				
		}
  		
		code("\n@exit_check%d:", check_num);
		
		for (int i = 0; i < SYMBOL_TABLE_LENGTH; ++i) {
  			strcpy(check_const_names[i],"");
  		}
  	check_const_iter = 0;
	}
	| check_part 
	{
		code("\n@otherwise%d:", check_num);
	}
	_OTHERWISE _COLON statement_list _RBRACKET
	{
		code("\n\t\tJMP \t@exit_check%d", check_num);
		code("\n@exit_when%d:", check_num);
		for (int i = 0; i < check_const_iter; ++i) {
				if(get_type($1) == INT)
    			code("\n\t\tCMPS \t");
				else
					code("\n\t\tCMPU \t");
				gen_sym_name($1);
				code(",$%s", check_const_names[i]);
				free_if_reg($1);
				code("\n\t\tJEQ \t@when%d%s", check_num, check_const_names[i]);
				
		}
		code("\n\t\tJMP \t@otherwise%d", check_num);
		code("\n@exit_check%d:", check_num);
		
		for (int i = 0; i < SYMBOL_TABLE_LENGTH; ++i) {
  			strcpy(check_const_names[i],"");
  		}
  	check_const_iter = 0;
	}
	;
	
check_part
	: _CHECK _LPAREN _ID 
		{
			int idx = lookup_symbol($3, VAR|PAR|GL_VAR);
      if(idx == NO_INDEX)
        err("invalid variable '%s' in check", $3);
      check_var_type = get_type(idx);
      
      
      code("\n@check%d:", ++check_num);
      code("\n\t\tJMP \t@exit_when%d", check_num);
		}
	_RPAREN _LBRACKET when_part
	{
		$$ = lookup_symbol($3, VAR|PAR|GL_VAR);
	}
	;
	
when_part
	: when_literal_part
	 	statement_list
		{
			if (get_type($1) != check_var_type)
				err("incompatible types in check");
			strcpy(check_const_names[check_const_iter++], get_name($1));
		}
	| when_literal_part
		statement_list _BREAK _SEMICOLON
		{
			if (get_type($1) != check_var_type)
				err("incompatible types in check");
			strcpy(check_const_names[check_const_iter++], get_name($1));
			code("\n\t\tJMP \t@exit_check%d", check_num);
		}
	| when_part when_literal_part
		statement_list
		{
			if (get_type($2) != check_var_type)
				err("incompatible types in check");
				
			check_const_repeat = 0;
			for (int i = 0; i < SYMBOL_TABLE_LENGTH; ++i) {
				if (strcmp(check_const_names[i], get_name($2)) == 0) {
					err("duplicate check value");
					check_const_repeat = 1;
					break;
				}
			}
			if (check_const_repeat != 1)
				strcpy(check_const_names[check_const_iter++], get_name($2));
			
		}
	| when_part when_literal_part
	 statement_list _BREAK _SEMICOLON
		{
			if (get_type($2) != check_var_type)
				err("incompatible types in check");
				
			check_const_repeat = 0;
			for (int i = 0; i < SYMBOL_TABLE_LENGTH; ++i) {
				if (strcmp(check_const_names[i], get_name($2)) == 0) {
					err("duplicate check value for");
					check_const_repeat = 1;
					break;
				}
			}
			if (check_const_repeat != 1)
				strcpy(check_const_names[check_const_iter++], get_name($2));
			code("\n\t\tJMP \t@exit_check%d", check_num);
		}
	;
	
when_literal_part
	: _WHEN literal
		
	 	_COLON 
	 	{
			code("\n@when%d%s:", check_num, get_name($2));
			$$ = $2;
		}
	;
	
cond_op
	: _LPAREN cond_exp 
			{
				code("\n@if%d:", lab_num++);
				if (num_rel == 1)
        	code("\n\t\t%s\t@false%d", opp_jumps[$2], lab_num-1);
        code("\n@true%d:", lab_num-1);
        $<i>$ = take_reg();
        num_rel = 0;
      }
		_RPAREN _QMARK exp_c
			{
				gen_mov($6, $<i>3);
				code("\n\t\tJMP \t@exit%d", lab_num-1);
        code("\n@false%d:", lab_num-1);
			}
		_COLON exp_c 
			{
				if (get_type($6) != get_type($9))
					err("types mismatch");
				gen_mov($9, $<i>3);

				code("\n@exit%d:", lab_num-1);
				$$ = $<i>3;
			}
	;
	
exp_c
	: _ID
		{
      $$ = lookup_symbol($1, VAR|PAR|GL_VAR);
      if($$ == NO_INDEX)
        err("'%s' undeclared", $1);
    }
	|	literal
	;

%%

int yyerror(char *s) {
  fprintf(stderr, "\nline %d: ERROR: %s", yylineno, s);
  error_count++;
  return 0;
}

void warning(char *s) {
  fprintf(stderr, "\nline %d: WARNING: %s", yylineno, s);
  warning_count++;
}

int main() {
	for (int i = 0; i < SYMBOL_TABLE_LENGTH; ++i) {
  	strcpy(check_const_names[i],"");
  }
  int synerr;
  init_symtab();
  output = fopen("output.asm", "w+");

  synerr = yyparse();
  clear_symtab();
  fclose(output);
  
  if(warning_count)
    printf("\n%d warning(s).\n", warning_count);

  if(error_count)
    printf("\n%d error(s).\n", error_count);

  if(synerr)
    return -1;  //syntax error
  else if(error_count)
    return error_count & 127; //semantic errors
  else if(warning_count)
    return (warning_count & 127) + 127; //warnings
  else
    return 0; //OK
    
}

