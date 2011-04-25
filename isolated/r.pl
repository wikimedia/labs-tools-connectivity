#!/usr/bin/perl
 #
 # Authors: [[:ru:user:Mashiah Davidson]]
 #
 # Data uploader for 
 # '''[[:ru:User:Mashiah_Davidson/toolserver/isolated.sh|isolated.sh]]'''.
 # 
 # Works on the Toolserver and uploads connectivity analysis statistics
 # or multiple redirects list to Russian Wikipedia.
 #
 # <pre>

use strict; # 'strict' insists that all variables be declared

binmode STDOUT, ':utf8';

my $outpage=shift;
my $mode=shift;
my $user=shift;
my $tstime=shift;
my $fix_stat_for=shift;
my $reply_to=shift;
my $language=shift;

open FILE, '</home/'.$user.'/.'.$language.'.cnf' or die ":: echo $!";
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

my $editor=Perlwikipedia->new($user);
$editor->{debug} = 0;
$editor->set_wiki( $language.'.wikipedia.org', 'w' );
my $loginstatus=$editor->login($user, $pass);

if ( $loginstatus eq '1' ) {
  die 'invalid login; possibly ~/.'.$language.'.cnf contains wrong data'.". the error returned: ".$editor->{errstr};
}

my $article=decode('utf8',$outpage);

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
    } elsif ( $cur !~ /^(\<\!\-\-\s|)\*/ ) {
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

my $time_to_upload=0;

if( $current eq '' ) 
{

  print ":: echo page is empty, upload required\n";
  $time_to_upload=1;

} elsif( $text eq $current ) {

  print ":: echo data not changed, no need for upload\n";
  $time_to_upload=0;

} else {

  my @lastedit=$editor->get_history($article,1);

  my $editcomment = $lastedit[0]->{comment};

  if( $editcomment !~ qr/(\d{4})\-(\d\d)\-(\d\d)\s(\d\d)\:(\d\d)\:(\d\d)$/ )
  {
    print ":: echo upload due to unrecognizable comment for the previous edit\n";
    $time_to_upload=1;
  } else {

    #
    # Mashiah Davidson: thanks to Dr.Ruud for my time saved
    # (http://www.nntp.perl.org/group/perl.datetime/2006/05/msg6342.html)
    #
    sub delta_time
    {
      my $t ;

      my $RE = qr/(\d{4})\-(\d\d)\-(\d\d)\s(\d\d)\:(\d\d)\:(\d\d)$/ ;

      sub calc { ( ( ( ( $1*365.25 + $2*365.25/12 + $3
                       ) * 24 + $4
                     ) * 60 + $5
                   ) * 60 + $6
                 )
               }

      $_[0] =~ $RE  and  $t -= calc()  and
      $_[1] =~ $RE  and  $t += calc()  and  return $t ;
      return
    }

    my $minutes_left=int(delta_time( $editcomment, $tstime)/60);

    if ( $minutes_left >= $fix_stat_for ) {
      print ":: echo time to upload now\n";
      $time_to_upload=1;
    } else {
      print ":: echo too early to upload\n";
      $time_to_upload=0;
    }
  }
}

if( $time_to_upload ) {
  my $edit_summary='updated, toolserver time is '.$tstime;

  my $is_minor = 0;
  # Note: This does not warn of edit conflicts, 
  #       it just overwrites existing text.
  my $response=$editor->edit($article, $text, $edit_summary, $is_minor);

  if ($response) {
    print ":: echo data successfully uploaded\n";
  }
  else
  {
    print ":: echo error uploading data: ".$editor->{errstr}."\n";
  }

  print ":: s".$reply_to." done wikistat\n";
}

# </pre>