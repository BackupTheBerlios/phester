#
# php_changer.gawk
#
# Author: Gerrit Riessen, gerrit.riessen@open-source-consultants.de 
# Copyright (C) 2002 Gerrit Riessen
# This code is licensed under the GNU Public License.
# $Id: php_changer.gawk,v 1.1 2002/02/20 16:04:56 riessen Exp $ 
#
# Required gawk scripts:
#   handle_command_line.gawk
#
BEGIN {
  ARGS[0] = "(changes|c)";
  ARGS_VALS[0] = "1";
  ARGS_DESC[0] = "The number of changes that should be made";

  ARGS[1] = "(seed|s)";
  ARGS_VALS[1] = "2342";
  ARGS_DESC[1] = "Seed for the random number generator";
  
  ARGS[2] = "(percent|p)";
  ARGS_VALS[2] = "0.5";
  ARGS_DESC[2] = "Percentage chance change will occur, 0.0 (0%) to 1.0 (100%)";

  ARGS[3] = "(debug)";
  ARGS_VALS[3] = "0";
  ARGS_DESC[3] = "Debug level 0,1,2,...";

  ARGS_CNT = 4;
  handleCommandLine();
  
  srand( ARGS_VALS[1] );

  # stores the modified parse tree if the statement was parsed
  parse_tree[0] = 0;
  parse_tree_elements = 0;

  # various regular expressions required to parse the statements
  re_var_name = "[a-zA-Z][a-zA-Z0-9_]*";
  re_number = "[0123456789]+";
  re_var = sprintf( "[$]%s((->)%s)*", re_var_name, re_var_name );
  re_opers = "(!=)|(==)|(>=)|(<=)|<|>";
  re_opers_assig = "(+=)|(-=)|(*=)|(/=)|=";
  re_opers_alg = "+|-|/|*";

  re_expr_func = sprintf( "(%s)([ \t]*(%s)[ \t]*((%s)|(%s)))*", re_var, 
                          re_opers_alg, re_number, re_var );
  re_expr = sprintf( "(%s)[ \t]*(%s)[ \t]*((%s)|(%s))", 
                     re_var, re_opers, re_expr_func, re_number );

  re_assig_num = sprintf( "(%s)[ \t]*(%s)[ \t]*(%s)", 
                          re_var, re_opers_assig, re_number);

  re_inc_dec = sprintf( "(%s)[ \t]*((++)|(--))", re_var );

  # several different "for" statements
  # assignment of variable, normal expression and a inc/dec-rement statement
  re_for[0] = sprintf( "[ \t]*(%s)[ \t]*[;][ \t]*(%s)[ \t]*[;][ \t]*(%s)[ \t]*", 
                       re_assig_num, re_expr, re_inc_dec );

  # several different "if" statements
  # <variable> <oper> <number>
  re_if[0] = sprintf( "(%s)[ \t]*(%s)[ \t]*(%s)", re_var, re_opers, re_number);
  # <variable> <oper> <variable>
  re_if[1] = sprintf( "(%s)[ \t]*(%s)[ \t]*(%s)", re_var, re_opers, re_var );
  # <variable> <oper> <variable> (<alg oper> <number/variable>)+
  re_if[2] = sprintf( "(%s)[ \t]*(%s)[ \t]*(%s)",re_var,re_opers,re_expr_func);
  # <number> <oper> <variable>
  re_if[3] = sprintf( "(%s)[ \t]*(%s)[ \t]*(%s)", re_number, re_opers, re_var);
  # function call, e.g. if ( function() )
  re_if[4] = sprintf( "(%s)[(][^)]*[)]", re_var_name );

  # these are the inverse operator (IO) arrays
  IO_FROM[0] = "=="; IO_TO[0] = "<";
  IO_FROM[1] = "!="; IO_TO[1] = ">=";
  IO_FROM[2] = "<="; IO_TO[2] = ">";
  IO_FROM[3] = ">="; IO_TO[3] = "<";
  IO_FROM[4] = ">";  IO_TO[4] = "<";
  IO_FROM[5] = "<";  IO_TO[5] = ">";
  
}

# ********
# functions
# ********
function make_change() {
  return ( rand() > (1.0 - ARGS_VALS[2]) );
}
function parse_for(    idx,a,jdx ) {
  for ( idx=0; idx in re_for; idx++ ) {
    if ( match( mat, sprintf( "[(][ \t]*(%s)[ \t]*[)]",re_for[idx]), a ) ) {

      if ( ARGS_VALS[3] > 0 ) {
        print "FOR (" idx ") --> [" mat "] {" \
          substr( mat, RSTART, RLENGTH ) "}";
        for ( jdx=0; jdx in a; jdx++ ) {
          print "  " jdx " = [" a[jdx] "]";
        }
      }

      if ( idx == 0 ) {
        # inverse the dec/inc-rement
        if ( match( mat, "[+][+][ \t]*[)]" ) ) {
          sub( "[+][+][ \t]*[)]", "--)", mat );
        } else {
          sub( "[-][-][ \t]*[)]", "++)", mat );
        }
        return 1;
      } else if ( idx == 1 ) {
      }
    }
  }
  return 0;
}
function parse_if(     idx,a,jdx ) {
  for ( idx=0; idx in re_if; idx++ ) {
    if ( ARGS_VALS[3] > 1 ) {
      print "IF looking for: " sprintf( "[(][ \t]*(%s)[ \t]*[)]", re_if[idx]);
    }

    if ( match( mat, sprintf( "[(][ \t]*(%s)[ \t]*[)]", re_if[idx]), a ) ) {

      if ( ARGS_VALS[3] > 0 ) {
        print "IF (" idx ") --> [" mat "] {" \
          substr( mat, RSTART, RLENGTH ) "}";
        for ( jdx=0; jdx in a; jdx++ ) {
          print "  " jdx " = [" a[jdx] "]";
        }
      }

      # unfortunately we need to know which "if" regexp matched, so we know
      # what we can do something useful ...
      if ( idx == 0 ) {
        # replace the number with one added to it
        #  this is insane: \x in the replace string does not work
        #  with either sub or gsub .... so have to use match
        match( mat, "([9876543210]+)[ \t]*[)]", a );
        sub( "([9876543210]+)[ \t]*[)]", sprintf( "(%s + 1))", a[1]), mat );
        return 1;
      } else if ( idx == 1 ) {
        # this is the variable-operator-variable case, change the operator
        for ( jdx=0; jdx in IO_FROM; jdx++ ) {
          if ( gsub( IO_FROM[jdx], IO_TO[jdx], mat ) ) {
            break;
          }
        }
        return 1;
      } else if ( idx == 2 ) {
      } else if ( idx == 3 ) {
      } else if ( idx == 4 ) {
        # function call if
        gsub( "[)]([^)]*)[)]", ") == 0)", mat );
        return 1;
      }
    }
  }
  return 0;
}


# ********
# matches
# ********
match( $0, "for[ \t]*[(][^;]*;[^;]*;[^)]*[)]", res ) && ARGS_VALS[0] > 0 {
#    print "Hit a for loop --> \n" $0;
  if ( make_change() ) {
    pre=substr( $0, 0, RSTART - 1 );
    post=substr( $0, RSTART+RLENGTH );
    mat=substr( $0, RSTART, RLENGTH );
    orig_mat = mat;
    if ( parse_for() ) {
      printf("// ----change (%d), original: %s\n", NR, orig_mat );
      printf("%s%s%s\n", pre, mat, post );
      ARGS_VALS[0]--;
      next;
    }
  }
}

match( $0, "if[ \t]*[(].*[)][^)]*", res ) && ARGS_VALS[0] > 0 {
  if ( make_change() ) {
    pre=substr( $0, 0, RSTART - 1 );
    post=substr( $0, RSTART+RLENGTH );
    mat=substr( $0, RSTART, RLENGTH );
    orig_mat = mat;
    if ( parse_if() ) {
      printf("// ----change (%d), original: %s\n", NR, orig_mat );
      printf("%s%s%s\n", pre, mat, post );
      ARGS_VALS[0]--;
      next;
    }
  }
}

// {
  print $0;
}

END {
  # nothing to do in the end
}

