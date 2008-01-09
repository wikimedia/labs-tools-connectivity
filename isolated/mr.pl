 # 
 # Double redirects resolver for 
 # '''[[:ru:User:Mashiah_Davidson/toolserver/isolated.sh|isolated.sh]]'''.
 # 
 # Works on the Toolserver and resolves double redirects for Russian Wikipedia.
 #
 # <pre>

#!/usr/bin/perl

use strict; # 'strict' insists that all variables be declared

my $user=shift;
my $pass=shift;

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
$editor->{debug} = 1;
$editor->set_wiki('ru.wikipedia.org','w');
$editor->login($user, $pass);

my $success_count=0;
my $failed_count=0;
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

  if ($response->is_success) {
    $timings[ $success_count % $perminallowed ]=time;
    $success_count+=1;
  }
  else
  {
    $failed_count+=1;
    print $response->status_line, "\n";
  }
}

while( <> )
{
  my $mr=decode('utf8', $_);
  chomp $mr;

  my $mr_text=$editor->get_text($mr);

  if( $editor->{errstr} ne '' )
  {
    $failed_count+=1;
    $editor->{errstr}='';
  }
  else
  {
    if(
        $mr_text=~m{
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
      my $r=$1;

      if( $r eq $mr )
      {
        do_edit( $r, '{{db|happy self-redirect}}', '{{db|happy self-redirect}}'."\n#REDIRECT [[$r]]" );
        $self_redir+=1;
      }

      my $r_text=$editor->get_text($r);

      if( $editor->{errstr} ne '' )
      {
        $failed_count+=1;
        $editor->{errstr}='';
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
            # Multiple redirects in the list we are working on may point
            # this happy self-redirect.
            # Here we rely on web-API smartnes and suppose edits with
            # the same content will not occur.
            do_edit( $r, '{{db|happy self-redirect}}', '{{db|happy self-redirect}}'."\n#REDIRECT [[$r]]" );
            $self_redir+=1;
          }
          elsif( $target eq $mr )
          {
            do_edit( $r, '{{db|ring of two redirects}}', '{{db|ring of two redirects}}'."\n#REDIRECT [[$r]]" );
            do_edit( $mr, '{{db|ring of two redirects}}', '{{db|ring of two redirects}}'."\n#REDIRECT [[$mr]]" );
            $redir_pair+=1;
          }
          else
          {
            do_edit( $mr, 'double redirects resolving with perlwikipedia', "#REDIRECT [[$target]]");
          }
        }
      }
    }
  }
}

print "$self_redir redirects point itself, $redir_pair rings of two redirects\n";
print "$success_count successfull edits, $failed_count failed edits\n";

# </pre>