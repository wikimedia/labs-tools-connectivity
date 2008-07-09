#!/usr/bin/perl
 #
 # Authors: [[:ru:user:Mashiah Davidson]], still alone
 #
 # Double redirects resolver
 # 
 # Works on the Toolserver and resolves double redirects.
 #
 # Inputs: Takes list of redirects pointing other redirects from stdin.
 #
 #         First parameter passed defines wiki-prefix (ru, en, ...)
 #
 #         Operates on behalf of a user defined by second command
 #         line parameter.
 #
 #         Takes user password from /home/.<wiki-prefix>.cnf given there
 #         in the format of: password = "<password>".
 #                  
 # <pre>

use strict; # 'strict' insists that all variables be declared

my $wikilang=shift;
my $user=shift;
open FILE, '</home/'.$user.'/.'.$wikilang.'.cnf' or die ':: echo /home/'.$user.'/.'.$wikilang.'.cnf: '.$!;
print ":: echo ".$user." grants permissions to bot ";
my $pass="";
while( my $line = <FILE> )
{
  if( $line =~ /^user\s*=\s*\"([^\"]*)\"$/ )
  {
    $user = $1;
  }
  elsif( $line =~ /^password\s*=\s*\"([^\"]*)\"$/ )
  {
    $pass = $1;
  }
}
close FILE;
print $user."\n";

use Perlwikipedia;
use Encode;

my $m_P=decode('utf8', 'П');
my $m_p=decode('utf8', 'п');
my $m_E=decode('utf8', 'Е');
my $m_e=decode('utf8', 'е');
my $m_R=decode('utf8', 'Р');
my $m_r=decode('utf8', 'р');
my $m_N=decode('utf8', 'Н');
my $m_n=decode('utf8', 'н');
my $m_A=decode('utf8', 'А');
my $m_a=decode('utf8', 'а');
my $m_V=decode('utf8', 'В');
my $m_v=decode('utf8', 'в');
my $m_L=decode('utf8', 'Л');
my $m_l=decode('utf8', 'л');
my $m_I=decode('utf8', 'И');
my $m_i=decode('utf8', 'и');

my $editor=Perlwikipedia->new($user);
$editor->{debug} = 0;
$editor->set_wiki($wikilang.'.wikipedia.org','w');
my $loginstatus=$editor->login($user, $pass);

if ( $loginstatus eq '1' ) {
  die ':: echo invalid login; possibly ~/.'.$wikilang.'.cnf contains wrong data';
}

my $success_count=0;
my $failed_count=0;
my $ntd_count=0;
my $self_redir=0;
my $redir_pair=0;

my @timings;
my $perminallowed=10;

my @timings=();

sub do_edit
{
  my $name=shift;
  my $edit_summary=shift;
  my $text=shift;

  my $is_minor = 0;

  # no need to wait before the first edit
  if( $success_count != 0 )
  {
    # first $perminallowed edits are to be smeared over a minute uniformly
    if( $success_count < $perminallowed )
    {
      while( time < $timings[ 0 ] + 60 * $success_count / $perminallowed ){}
    }
    # do not allow edits earlier than after a minute from 
    # first of last $perminallowed edits
    else
    {
      while( time < $timings[ $success_count % $perminallowed ] + 60 ){}
    }
  }
  # Note: This does not warn of edit conflicts, 
  #       it just overwrites existing text.
  my $response=$editor->edit($name, $text, $edit_summary, $is_minor);

  if ($response) {
    $timings[ $success_count % $perminallowed ]=time;
    $success_count+=1;
  }
  else
  {
    $failed_count+=1;
    print ":: echo page is probably read-only / protected\n";
  }
}

while( <> )
{
  my $mr=decode('utf8', $_);
  chomp $mr;

  my $mr_text=$editor->get_text($mr);

#  print ":: echo ".length( $mr_text )."bytes\n";

  if( $editor->{errstr} ne '' )
  {
    $failed_count+=1;
    $editor->{errstr}='';
    print ":: echo error getting ".($failed_count+$success_count)."st/nd/rd/th name in the list\n";
  }
  else
  {
    if(
        $mr_text=~m{
                     ^[\s\t\n\r]*
                     \#
                     (?:
                       # I know about "i" modifier but it doesn't work for utf8.
                       # Just to show the principle for utf-8 matched below.
                       (?:R|r)(?:E|e)(?:D|d)(?:I|i)(?:R|r)(?:E|e)(?:C|c)(?:T|t)
                     |
                       (?:$m_P|$m_p)(?:$m_E|$m_e)(?:$m_R|$m_r)(?:$m_E|$m_e)(?:$m_N|$m_n)(?:$m_A|$m_a)(?:$m_P|$m_p)(?:$m_R|$m_r)(?:$m_A|$m_a)(?:$m_V|$m_v)(?:$m_L|$m_l)(?:$m_E|$m_e)(?:$m_N|$m_n)(?:$m_I|$m_i)(?:$m_E|$m_e)
                     )
                     [\s]*
                     \[\[
                          ([^\]]+)
                     \]\]
                   }mx 
      )
    {
      my $r=$1;

      # just in case there is an anchor in the link
      my $anchor="";
      if( $r =~ /^([^\#]+)\#([^\#]+)$/ )
      {
        $r=$1;
        $anchor=$2;
      }

      if( $r eq $mr )
      {
        do_edit( $r, '{{db|happy self-redirect}}', '{{db|happy self-redirect}}'."\n#REDIRECT [[$r]]" );
        if( $editor->{errstr} ne '' )
        {
          $failed_count+=1;
          $editor->{errstr}='';
          print ":: echo error editing happy double self-redirext\n";
        }
        else
        {
          $self_redir+=1;
        }
      }
      else
      {
        my $r_text=$editor->get_text($r);
      
        if( $editor->{errstr} ne '' )
        {
          $failed_count+=1;
          $editor->{errstr}='';
          print ":: echo error getting in chain started from ".($failed_count+$success_count)."st/nd/rd/th name in the list\n";
        }
        else
        {
          if(
              $r_text=~m{
                          ^[\s\t\n\r]*
                          \#
                          (?:
                            # I know about "i" modifier.
                            # Just to show the principle for utf-8 matched below.
                            (?:R|r)(?:E|e)(?:D|d)(?:I|i)(?:R|r)(?:E|e)(?:C|c)(?:T|t)
                            |
                            (?:$m_P|$m_p)(?:$m_E|$m_e)(?:$m_R|$m_r)(?:$m_E|$m_e)(?:$m_N|$m_n)(?:$m_A|$m_a)(?:$m_P|$m_p)(?:$m_R|$m_r)(?:$m_A|$m_a)(?:$m_V|$m_v)(?:$m_L|$m_l)(?:$m_E|$m_e)(?:$m_N|$m_n)(?:$m_I|$m_i)(?:$m_E|$m_e)
                          )
                          [\s]*
                          \[\[
                               ([^\]]+)
                          \]\]
                        }mx 
            )
          {
            my $target=$1;
          
            if( $target eq $r )
            {
              # Multiple redirects in the list we are working on can be pointing
              # this happy self-redirect.
              # Here we rely on web-API smartness and suppose edits with
              # the same content will not occur.
              do_edit( $r, '{{db|happy self-redirect}}', '{{db|happy self-redirect}}'."\n#REDIRECT [[$r]]" );
              if( $editor->{errstr} ne '' )
              {
                $failed_count+=1;
                $editor->{errstr}='';
                print ":: echo error editing a happy self-redirect\n";
              }
              else
              {
                $self_redir+=1;
                print ":: echo happy self-redirect\n";
              }
            }
            elsif( $target eq $mr )
            {
              do_edit( $r, '{{db|ring of two redirects}}', '{{db|ring of two redirects}}'."\n#REDIRECT [[$r]]" );
              if( $editor->{errstr} ne '' )
              {
                $failed_count+=1;
                $editor->{errstr}='';
                print ":: echo error editing a ring of two redirects\n";
              }
              else
              {
                do_edit( $mr, '{{db|ring of two redirects}}', '{{db|ring of two redirects}}'."\n#REDIRECT [[$mr]]" );
                if( $editor->{errstr} ne '' )
                {
                  $failed_count+=1;
                  $editor->{errstr}='';
                  print ":: echo error editing a ring of two redirects\n";
                }
                else
                {
                  $redir_pair+=1;
                  print ":: echo a ring of two redirects\n";
                }
              }
            }
            else
            {
              # applying an anchor if required
              if( $anchor ne '' )
              {
                $target=$target.'#'.$anchor;
              }

              # resolving the double redirect
              do_edit( $mr, 'double redirects resolving with perlwikipedia', "#REDIRECT [[$target]]");
              if( $editor->{errstr} ne '' )
              {
                $failed_count+=1;
                $editor->{errstr}='';
                print ":: echo error editing to resolve double redirect";
              }
              else
              {
                print ":: echo a redirect resolved\n";
              }
            }
          }
          else
          {
            print ":: echo not a multiple redirect actually\n";
            $ntd_count+=1;
          }
        }
      }
    }
    else
    {
      print ":: echo first redirect not found\n";
      $ntd_count+=1;
    }
  }
}

print ":: echo $self_redir redirects point itself, $redir_pair rings of two redirects\n";
print ":: echo $success_count successfull edits, $ntd_count items with nothing to do, $failed_count failed edits\n";

# </pre>
