#
# format_results.gawk
#
# Author: Gerrit Riessen, gerrit.riessen@open-source-consultants.de 
# Copyright (C) 2002 Gerrit Riessen
# This code is licensed under the GNU Public License.
# $Id: format_results.gawk,v 1.1 2002/02/20 16:04:56 riessen Exp $ 
#
# Extra required files:
#  -- utilities.gawk (execute_command)
#  -- handle_command_line.gawk
#
# This script must be called with the phester.protocol file that is generated 
# by the phester.sh command.
#
BEGIN {
  ARGS[0] = "(with-protocol)";
  ARGS_VALS[0] = "0";
  ARGS_DESC[0] = "Include the protocol in output";

  ARGS[1] = "(run-out|ro)";
  ARGS_VALS[1] = "results.runs.html";
  ARGS_DESC[1] = "Output File name for the results by runs";

  ARGS[2] = "(files-out|fo)";
  ARGS_VALS[2] = "results.files.html";
  ARGS_DESC[2] = "Output file name for the results sorted by modified files";

  ARGS[3] = "(gawk-engine|gawk)";
  ARGS_VALS[3] = "gawk";
  ARGS_DESC[3] = "Gawk engine to use to execute gawk scripts";

  ARGS[4] = "(lib-dir|lib)";
  ARGS_VALS[4] = "/www/development/utils/gawk";
  ARGS_DESC[4] = "Library directory containing Gawk utilites";

  ARGS_CNT = 5;
  handleCommandLine();

  with_protocol = ARGS_VALS[0];
  sort_by_run = ARGS_VALS[1];
  sort_by_files = ARGS_VALS[2];
  gawk_engine = ARGS_VALS[3];

  if ( is_set( sort_by_files ) ) {
    sort_by_run = 0;
  }

  # base name of the run all unit test results file
  RAUT_FNAME = "run_all_unit_tests";
  # is only set to zero if the first run has not yet been encountered
  parsing_run = 0;
  # this contains the protocol for a run
  protocol = "";
  # stores the files that were modified in the run
  mod_files[0] = "";
  md_count = 0;
  # we're generating a html page as output
  printf( "<html><head><title>Phester Results</title></head><body>\n" ) \
    >> ARGS_VALS[1];
  printf( "<html><head><title>Phester Results</title></head><body>\n" ) \
    >> ARGS_VALS[2];

  # generate patch script details
  gp_options = sprintf( "-f %s/handle_command_line.gawk", ARGS_VALS[4] );
  gp_script = sprintf( "%s/generate_patch_script.gawk", ARGS_VALS[4] );
#    gp_options = "-f /www/development/utils/gawk/handle_command_line.gawk";
#    gp_script = "/www/development/utils/php/phester/generate_patch_script.gawk";

  # changes made as part of each run. changes begin at 1: the protocol
  # is stored at 0. The value is html code for the change.
  run_changes[0,0] = "";

  # files modified, zero indexed list of files modified
  files_modified[0] = "";
  fm_count = 0;

  # changes made to file: index is the file name comma a change number
  file_changes["",0] = "";
  fm_changes[""] = 0;

  # source directory, set by one of the match rules
  src_dir = "";

  # various different text outputs (SP_FOR == sprintf format).
  # the first index value is whether there was a change, the second index
  # is whether the unit tests failed, and the third index is whether the
  # string "Allowed memory" appeared in the unit_test output (this basically
  # isn't a failure, it's a memory problem).
  SP_FOR[0,0,0] = "Run %d, Change %d did nothing ... \n";
  SP_FOR[1,0,0] = "<b><a target=\"_blank\" href=\"change.%d.%d.html\">Changes</a></b> to <b>%s</b> made but not detected by unit tests";
  SP_FOR[0,1,0] = "<b>WARNING</b> no changes but <a target=\"_blank\" href=\"raut.%d.%d.html\">unit tests</a> failed<br>\n";
  SP_FOR[0,1,1] = "<b>WARNING</b> no changes but <a target=\"_blank\" href=\"raut.%d.%d.html\">unit tests (memory allocation)</a> failed<br>\n";
  SP_FOR[1,1,0] = "<a target=\"_blank\" href=\"change.%d.%d.html\">Changes</a> to <b>%s</b> caused <a target=\"_blank\" href=\"raut.%d.%d.html\">unit tests</a> to fail";
  SP_FOR[1,1,1] = "<a target=\"_blank\" href=\"change.%d.%d.html\">Changes</a> to <b>%s</b> caused <a target=\"_blank\" href=\"raut.%d.%d.html\">unit tests (memory allocation)</a> to fail";
}

function debug( string ) {
  print string >> "/dev/stderr";
}

function dump_array( ary,     jdx ) {
  for ( jdx=0; jdx in ary; jdx++ ) {
    debug( "  " jdx " = [" ary[jdx] "]" );
  }
}

function is_set( variable ) {
  return ( variable != 0 );
}

function convert_to_html( source_file, file_name, mod_file ) {
  # Arguments:
  #  source_file is the patch file containing the changes to mod_file
  #  file_name is the output file
  #  mod_file is the file on which the changes were made
  
  # use the generate_patch_script.gawk to generate a gawk script
  # that in turn generates a html page containing the highlighted changes
  tmp = sprintf( "/tmp/%d.gawk", 10000 * rand() );
  com = sprintf( "rm -f %s; %s %s -f %s --title=%s %s > %s",
                 tmp, gawk_engine, gp_options, gp_script, file_name, 
                 source_file, tmp );
  execute_command( com );

  target = sprintf( "%s/%s", src_dir, file_name );
  com = sprintf( "rm -f %s; %s -f %s %s > %s", target,gawk_engine,
                 tmp,mod_file,target);
  execute_command( com );

  # clean up
  execute_command( sprintf( "rm -f %s", tmp ) );
}

function generate_html_pages( run_num, change_num, basename, mod_file,
                              size_raut, size_change ) {

  if ( size_change > 0 ) {
    convert_to_html( sprintf( "%s/%s.%d.%d", src_dir, basename, run_num, 
                              change_num ),
                     sprintf( "change.%d.%d.html", run_num, change_num ),
                     mod_file );
  }
  
  if ( size_raut > 0 ) {
    convert_to_html( sprintf( "%s/%s.%d.%d", src_dir, RAUT_FNAME, 
                              run_num, change_num ),
                     sprintf( "raut.%d.%d.html", run_num, change_num ),
                     sprintf( "%s/%s.0.0", src_dir, RAUT_FNAME ) );
  }

  # check for a memory allocation error, i.e. the run all unit tests script
  # failed because it was unable to allocate enough memory.
  com = sprintf( "grep \"<b>Fatal error</b>:  Allowed memory size of\" %s/%s.%d.%d", src_dir, RAUT_FNAME, run_num, change_num );

  idx_s = sprintf( "%d%s%d%s%d", (size_change > 0), SUBSEP, (size_raut > 0),
                   SUBSEP, (execute_command( com ) != "") );

  return ( sprintf( SP_FOR[idx_s], run_num, change_num, mod_file, 
                    run_num, change_num ));
}

function dump_modified_file_information() {
  debug( "dumping modified files information ..." );
  for ( idx = 0; idx < fm_count; idx++ ) {
    printf( "<hr width=\"80%\"><h2>%s</h2><br><table>\n", 
            files_modified[idx] ) >> ARGS_VALS[2];
    for ( jdx = 0; jdx < fm_changes[files_modified[idx]]; jdx++ ) {
      print( "<tr><td>", file_changes[files_modified[idx],jdx], \
             "</td></tr>" ) >> ARGS_VALS[2];
    }
    print "</table>" >> ARGS_VALS[2];
  }
}

function dump_run_information() {
  debug( "dumping run information ..." );
  for ( rdx = 1; ; rdx++ ) {
    idx = sprintf( "%d%s0", rdx, SUBSEP );
    if ( !(idx in run_changes) ) {
      return;
    }

    printf( "<hr width=\"80%\"><h2>Run %d </h2><br>\n", rdx ) >> ARGS_VALS[1];
    if ( is_set( with_protocol ) ) {
      debug( "dumping protocol" );
      printf( "<pre>%s</pre><hr width=\"30%\">\n", 
              gensub( "<", "\\&lt;", run_changes[idx] )) >> ARGS_VALS[1];
    }
    printf( "<table>\n" ) >> ARGS_VALS[1];
    
    for ( cdx = 1; ; cdx++ ) {
      idx = sprintf( "%d%s%d", rdx, SUBSEP, cdx );
      if ( !(idx in run_changes) ) {
        break;
      }
      print( "<tr><td>",run_changes[idx],"</td></tr>" ) >> ARGS_VALS[1];
    }

    print( "</table>" ) >> ARGS_VALS[1];
  }
}

function handle_run() {
  com = sprintf( "ls -s --block-size=32 %s/*.%s.*", src_dir, current_run );
  file_sizes = execute_command( com );

  run_changes[current_run,0] = protocol;

  # for each modified file write out some useful information
  for ( idx = 0; idx < md_count; idx++ ) {

    bname = base_name( mod_files[ idx ] );
    match( file_sizes, sprintf("([0-9]+) [^ ]*%s[.]%d[.]%d", bname, 
                               current_run, idx ), fs_ary );
    change_size = fs_ary[1];
    match( file_sizes, sprintf("([0-9]+) [^ ]*%s[.]%d[.]%d", RAUT_FNAME, 
                               current_run, idx ), fs_ary );
    raut_size = fs_ary[1];
    
    if ( change_size == 0 && raut_size == 0 ) {
      run_changes[current_run,(idx+1)] = \
        sprintf( SP_FOR[0,0,0], current_run, idx );
      continue;
    }

    if ( !files_changes[mod_files[idx],0] ) {
      files_modified[fm_count++] = mod_files[idx];
      files_changes[mod_files[idx],0] = "fubar";
      fm_changes[mod_files[idx]] = 0;
    }

    # debug information
    debug( sprintf( "Run %d,%d Sizes: RAUT: %d Change: %d", current_run,idx,
                    raut_size, change_size ) );
    
    # now check whether changes were made ....
    run_changes[current_run,(idx+1)] = \
      generate_html_pages( current_run, idx, bname, mod_files[idx], 
                           raut_size, change_size );

    file_changes[mod_files[idx],fm_changes[mod_files[idx]]++] = \
      run_changes[current_run,(idx+1)];
  }
}

match( $0, "Output directory:[ ]*(.+)$", a ) {
  src_dir = a[1];
}

match( $0, "Making changes to[ ]*(.+)$", a ) {
  mod_files[md_count++] = a[1];
}

match( $0, "--------------- Run:[ ]*([0-9]+)  ---------------", run_ary ) {
  if ( parsing_run ) {
    # handle the just read in run
    # obtain the file sizes of all files related to the run
    handle_run();
  } else {
    # this is the first run, that is we don't have a run
    # that needs to be handled ...
    parsing_run = 1;
  }

  # update all relevant variables
  current_run = run_ary[1];
  protocol = "";
  md_count = 0;
  next;
}

// {
  protocol = sprintf( "%s\n%s", protocol, $0 );
}

END {
  if ( is_set( md_count ) ) {
    handle_run();
  }

  dump_run_information();
  dump_modified_file_information();

  printf( "\n</body></html>\n" ) >> ARGS_VALS[1];
  printf( "\n</body></html>\n" ) >> ARGS_VALS[2];
}

