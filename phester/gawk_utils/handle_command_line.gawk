#
# handle_command_line.gawk
#
# Author: Gerrit Riessen, gerrit.riessen@open-source-consultants.de 
# $Id: handle_command_line.gawk,v 1.1 2002/04/24 16:59:31 riessen Exp $ 
#

#
# GAWK utility for handling command line arguments. This should be
# included in any gawk scripts that require it by adding it to
# command line of the gawk invokation:
#   gawk --source <path>/handle_command_line.gawk ....
# To use this, for each argument define:
#   ARGS[X] -- this is the argument in long form (can be reg exp)
#   ARGS_VALS[X] -- this contains a default value and later the value
#                   obtained from the command line
#   ARGS_DESC[X] -- is the description of the command line option.
# X is an index value beginning at 0.
#   ARGS_CNT -- must be set to the number of arguments specified.
# To retrieve the values call the handlesCommandLine() function. This 
# should be called in the BEGIN block, after defining the argument options.
#

############################
#
# handleCommandLine, usage and getArgValue are the only three
# functions required to parse the command line.
#
function handleCommandLine()
{
  for ( i = 0; i < ARGC; i++ )
    {
      for ( j = 0; j < ARGS_CNT; j++ )
        {
          ARGS_VALS[j] = getArgValue( ARGV[i], ARGS[j], ARGS_VALS[j], 1 );
          if ( ARGV[i] == "--help" )
            {
              usage();
              exit;
            }
        }
    }
}

function getArgValue( string, arg, elseReturnThis, setARGV ) 
{
  if ( match( string, sprintf( "--%s=", arg ) ) > 0 )
    {
      elseReturnThis = substr( string, RLENGTH+1 );
      if ( setARGV == 1 )
        {
          ARGV[i] = ARGV[--ARGC];
          i--;
        }
      else if ( setARGV == 2 )
        {
          NR = 0;
        }
    }
  else if ( match( string, sprintf( "--%s", arg ) ) > 0 )
    {
      # this is a switch option, i.e. no value, return true
      elseReturnThis = 1;
      if ( setARGV == 1 ) 
        {
          ARGV[i] = ARGV[--ARGC];
          i--;
        }
      else if ( setARGV == 2 )
        {
          NR = 0;
        }
    }

  return elseReturnThis;
}

function usage()
{
  for ( i = 0; i < ARGS_CNT; i++ )
    {
      if ( ARGS_DESC[i] == "" )
        {
          ARGS_DESC[i] = "No Description";
        }
      printf( "--%s=\"%s\"\n  %s\n", ARGS[i], ARGS_VALS[i], ARGS_DESC[i] );
    }
}

#
# End Command line Parsing
###############################
