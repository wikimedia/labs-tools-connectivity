 # 
 # Data uploader for 
 # '''[[:ru:User:Mashiah_Davidson/toolserver/isolated.sh|isolated.sh]]'''.
 # 
 # Works on the Toolserver and uploads connectivity analysis statistics
 # and multiple redirects list to Russian Wikipedia.
 #
 # <pre>

#!/usr/bin/perl

use strict; # 'strict' insists that all variables be declared

my $outpage=shift;
my $mode=shift;
my $user=shift;
my $tstime=shift;

print $user." grants permissions to bot ";
my $pass="";
open FILE, '</home/'.$user.'/.ru.cnf' or die $!;
while( my $line = <FILE> )
{
  if( $line =~ /^user\s*=\s*\"([^\"]*)\"$/ )
  {
    $user = $1;
  }
  elsif( $line =~ /^password\s*=\s*\"([^\"]*)\"$/ )
  {
    $pass = $1
  }
}
close FILE;
print $user."\n";

use Perlwikipedia;
use Encode;

my $editor=Perlwikipedia->new($user);
$editor->{debug} = 0;
$editor->set_wiki('ru.wikipedia.org','w');
$editor->login($user, $pass);

#            may need to be driven from outside
#my $article="User:Mashiah Davidson/".$outpage;
my $article=decode('utf8','Участник:Mashiah Davidson/'.$outpage);

my $current=$editor->get_text($article);
chomp $current;

my $text;
if( $mode eq 'pre' )
{
  # the constant is split to look better in the web
  $text = '<'.'pre'.'>';
} elsif( $mode eq 'stat') {
  $text='{| class="wikitable"'."\n".'|-'."\n";
}
my $columns=0;
while( <> )
{
  my $cur=decode('utf8', $_);
  if( $mode eq 'stat' )
  {
    if( $cur =~ /^\*\[/ )
    {
      $cur='| valign="top" | '."\n".$cur;
      $columns++;
    } elsif ( $cur !~ /^\*/ ) {
      $cur="|-\n".
           '| colspan='.
           $columns.
           ' | <center><font color="green">'."'''".
           $cur.
           "'''</font></center>\n";
    }
  }
  $text=$text.$cur;
}
if( $mode eq 'pre' )
{
  # the constant is split to look better in the web
  $text=$text.'</'.'pre'.'>';
} elsif( $mode eq 'stat') {
  $text=$text.'|}'."\n";
}

if( $text eq $current )
{
  print ":: echo no need to upload\n";
}
else
{
  my $edit_summary='updated, toolserver time is '.$tstime;

  my $is_minor = 0;
  # Note: This does not warn of edit conflicts, 
  #       it just overwrites existing text.
  $editor->edit($article, $text, $edit_summary, $is_minor);

  print ":: echo data successfully upload\n";
  print ":: s3 call stat_uploaded\n";
}

# </pre>