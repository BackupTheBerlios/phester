#
# generate_patch_script.gawk
#
# Author: Gerrit Riessen, gerrit.riessen@open-source-consultants.de 
# Copyright (C) 2002 Gerrit Riessen
# This code is licensed under the GNU Public License.
# $Id: generate_patch_script.gawk,v 1.1 2002/02/20 16:04:56 riessen Exp $ 
#
# Requires:
#   handle_command_line.gawk
#
BEGIN {
  ARGS[0] = "(title|t)";
  ARGS_VALS[0] = "unknown";
  ARGS_DESC[0] = "Title for the html page";
  
  ARGS_CNT = 1;
  handleCommandLine();

  printf( "BEGIN {\n  print \"<html><head><title>%s</title></head><body><pre>\";\n}\n",ARGS_VALS[0] );

  # flag to tell us what we last encountered
  parsing = "";

  # flag to indicate that something was not interpreted correctly
  failed_to_interpret = 0;
  failure_text = "";
}

function handle_multi_line_change() {
  printf( "NR >= %d && NR <= %d {\n", ch_mline_from, ch_mline_to );
  printf( "  printf( \"<span style=\\\"color:blue\\\">%%s</span>\\n\",gensub( \"<\", \"\\\\&lt;\", $0));\n");
  printf( "  if ( NR == %d ) {\n", ch_mline_to );
  # replace backslashes with double backslashes
  gsub( "\\\\", "\\\\", replacement );
  gsub( "\"", "\\\"", replacement );
  printf( "    print( \"<span style=\\\"color:red\\\">%s</span>\" );\n", 
          gensub( "^[<]br[>]", "", "g", replacement ) );
  printf( "  }\n  next;\n}\n" );
}

function handle_single_line_change() {
  # need to handle the just read in change
  printf( "NR == %d {\n  ", orig_line ); 
  # replace backslashes with double backslashes
  gsub( "\\\\", "\\\\", replacement );
  gsub( "\"", "\\\"", replacement );
  printf( "  print( \"<span style=\\\"color:red\\\">%s</span>\" );\n    next;\n}\n", 
          gensub("^[<]br[>]", "", "g",replacement));
}

function handle_delete() {
  printf( "NR >= %d && NR <= %d {\n", delete_from, delete_to );
  printf( "  printf( \"<span style=\\\"color:blue\\\">%%s</span>\\n\",gensub( \"<\", \"\\\\&lt;\", $0));\n");
  printf( "  next;\n}\n" );
}

function check_parsing_flag() {
  if ( parsing == "change_sline" ) {
    handle_single_line_change();
  } else if ( parsing == "delete" ) {
    handle_delete();
  } else if ( parsing == "change_mline" ) {
    handle_multi_line_change();
  }
}

#
# ============================================================================
# Here begin the regular expression matches
# ============================================================================
#
match( $0, "^([0-9]+),([0-9]+)d([0-9]+)", line_nums ) {
  check_parsing_flag();
  parsing = "delete";
  delete_from = line_nums[1];
  delete_to = line_nums[2];
  next;
}

match( $0, "^([0-9]+),([0-9]+)c([0-9]+)(,([0-9]+))?", line_nums ) {
  check_parsing_flag();
  parsing = "change_mline";
  ch_mline_from = line_nums[1];
  ch_mline_to = line_nums[2];
  replacement = "";
  next;
}

match( $0, "^([0-9]+)c([0-9]+)(,([0-9]+))?", line_nums ) {
  check_parsing_flag();
  parsing = "change_sline";
  orig_line = line_nums[1];
  original = "";
  replacement = "";
  next;
}

/^</ {
  gsub( "[$]", "[$]" );
  gsub( "[(]", "[(]" );
  gsub( ")", "[)]" );
  original = sprintf( "%s\\n%s", original, 
                      gensub( "^<[ \t]*" , "^[ \\\\t]*", "g" ) );
  next;
}

/^>/ {
  gsub( "<", "\\&lt;" );
  replacement = sprintf( "%s<br>%s", replacement, gensub( "^> ", "", "g" ) );
  next;
}

/^---$/ {
  next;
}

// {
  # if we get this far, then something failed ....
  failed_to_interpret++;
  failure_text = sprintf( "%s<br>%d: %s", failure_text,NR,$0);
}

END {
  check_parsing_flag();
  printf( "\n// {   gsub( \"<\", \"\\\\&lt;\" );print $0; }\nEND {\n");
  if ( failed_to_interpret > 0 ) {
    printf( "  print \"<h1>WARNING: Error '%s'</h1>\";\n  print \"%s\";\n",
            FILENAME, failure_text );
  } 
  printf( "  print \"</pre></body></html>\";\n}\n" );

}


