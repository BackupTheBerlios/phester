#
# utilities.gawk
#
# Author: Gerrit Riessen, gerrit.riessen@open-source-consultants.de 
# Copyright (C) 2001 Gerrit Riessen
# This code is licensed under the GNU Public License.
# $Id: utilities.gawk,v 1.1 2002/04/24 16:59:31 riessen Exp $ 
#

#
# this file contains a number of useful code snippets which can be
# included in scripts requiring the functionality.
#

# Function creates two lookup tables, one for mapping from Hex to dec and
# the other for mapping from dec to hex, these are called HEX2DEC and DEC2HEX
# respectively. The value range for these tables is from 00 to ff(255) and
# uses lowercase letters.
#
# the function takes no parameters, and defines a number of local variables.
function create_hex_dec_lookup(   cnt,num2let,idx,jdx,str) {
  num2let[0]="0";  num2let[1]="1";  num2let[2]="2";  num2let[3]="3";
  num2let[4]="4";  num2let[5]="5";  num2let[6]="6";  num2let[7]="7";
  num2let[8]="8";  num2let[9]="9";  num2let[10]="a"; num2let[11]="b";
  num2let[12]="c"; num2let[13]="d"; num2let[14]="e"; num2let[15]="f";
  cnt=0;
  for ( idx = 0; idx < 16; idx++ ) {
    for ( jdx = 0; jdx < 16; jdx++ ) {
      str = sprintf( "%s%s", num2let[idx], num2let[jdx] );
      HEX2DEC[str] = cnt;
      DEC2HEX[cnt] = str;
      cnt++;
    }
  }
}

# Execute a specific command and return the output (standard output) as 
# string
function execute_command( com,     output, line ) 
{
  output = "";
  while ( (com | getline line) > 0 )     
    {
      if ( output != "" ) {
        output = sprintf( "%s\n%s", output, line );
      } else {
        output = line;
      }
    }
  close( com );
  return output;
}

# Function fills the filenames array with the file names found in the
# directory passed as the first argument. The filenames array is cleared
# and the function returns the number of files found.
function get_all_filenames( dir, filenames,        num_files ) {
  num_files = split( sprintf("%s\n",
                             execute_command( sprintf("cd %s && ls .",dir))),
                     filenames, "\n");
  return num_files;
}

# returns the file name at the end of the path specification, i.e. does
# the same as the unix command 'basename'
function base_name( file_path ) {
  # ASSUME: that the file separator is '/'
  num_dir = split( file_path, ary, "/" );
  return ary[num_dir];
}

function array_shift( ary, len, amount,    idx ) {
  if ( amount == 0 ) {
    return len;
  } else if ( amount > 0 ) {
    for ( idx = len-1; idx > -1; idx-- ) {
      ary[idx+amount] = ary[idx];
      ary[idx] = "";
    }
    return (len+amount);
  } else {
    # amount less than zero which implies shifting towards zero, we
    amount *= -1;
    if ( amount > len ) {
      delete ary;
      return 0;
    }
    for ( idx = 0; idx < len; idx++ ) {
      if ( idx+amount > len-1 ) {
        delete ary[idx];
      } else {
        ary[idx] = ary[idx+amount];
      }
    }
    return (len - amount);
  }
}

