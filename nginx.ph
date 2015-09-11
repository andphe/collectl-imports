# copyright, 2015 Andres Vargas <andphe@gmail.com>

use strict;
use WWW::Curl::Easy;

# Allow reference to collectl variables, but be CAREFUL as these should be treated as readonly
our ($miniFiller, $rate, $SEP, $datetime, $intSecs, $showColFlag);

# Global to this module
my (@now, @last, $schema, $host, $port, $uri);

sub nginxInit
{
  my $impOptsref = shift;
  my $impKeyref  = shift;
  my ($flag, $value);

  $schema = "http";
  $host   = "localhost";
  $port   = "80";
  $uri    = "nginx_status";

  my @opts=split(/,/,$$impOptsref);
  foreach my $opt ( @opts) {
    $opt   =~ /([shpu])=(.*)/;
    $flag  = $1;
    $value = $2;

    error("invalid value for option $flag import nginx") if $value eq "";

    $schema = $value if $flag eq "s";
    $host   = $value if $flag eq "h";
    $port   = $value if $flag eq "p";
    $uri    = $value if $flag eq "u";
  }

  $$impOptsref='s';
  $$impKeyref='nx';

  @now  = (0, 0, 0);
  @last = (0, 0, 0);

  return(1);
}

sub nginxUpdateHeader {}

sub nginxGetData
{
  my $response_body;
  my $curl = WWW::Curl::Easy->new;

  $curl->setopt(CURLOPT_URL, "$schema://$host:$port/$uri");
  $curl->setopt(CURLOPT_TIMEOUT, 1);
  $curl->setopt(CURLOPT_WRITEDATA,\$response_body);
  my $retcode = $curl->perform;

  my ($active, $handled, $accepts);

  if ($retcode == 0) {
    my @lines = split(/\n/, $response_body);

    $lines[0] =~ /Active connections: (\d+)/;
    $active = $1 || 0;

    $lines[2] =~ / (\d+) (\d+) (\d+)/;
    $accepts = $1 || 0;
    $handled = $2 || 0;

    record(2, "nx-0 $active");
    record(2, "nx-1 $accepts");
    record(2, "nx-2 $handled");
  }
}

sub nginxInitInterval {}

sub nginxAnalyze
{
  my $type    = shift;
  my $dataref = shift;

  $type     =~/^nx-(.*)/;
  my $index = $1;

  if ($index) {
    if ($$dataref > $last[$index]) {
      $now[$index] = $$dataref - $last[$index];
    } else {
      $now[$index] = $$dataref;
    }
    $last[$index] = $$dataref;
  } else {
    $now[$index] = $$dataref;
  }
}

sub nginxPrintBrief
{
  my $type=shift;
  my $lineref=shift;

  if ($type==1)       # header line 1
  {
    $$lineref.="<-------Nginx------->";
  }
  if ($type==2)       # header line 1
  {
    $$lineref.="  Act    Acc    Han  ";
  }
  elsif ($type==3)    # data
  {
    $$lineref.=sprintf(" %5d %5d %5d ", $now[0], $now[1], $now[2]);
  }
}

sub nginxPrintVerbose
{
  my $printHeader=shift;
  my $homeFlag=   shift;
  my $lineref=    shift;

  my $line=$$lineref='';

  if ($printHeader)
  {
    $line.="\n"    if !$homeFlag;
    $line.="# NGINX STATISTICS ($rate)\n";
    $line.="#$miniFiller  Act    Acc    Han \n";
  }
  $$lineref.=$line;
  return    if $showColFlag;

  $$lineref.=sprintf("$datetime  %5d %5d %5d \n", $now[0], $now[1], $now[2]);

  $$lineref.=$line;
}

sub nginxPrintPlot
{
  my $type=   shift;
  my $ref1=   shift;

  if ($type==1)
  {
    $$ref1.="[NX] Act    Acc    Han ${SEP}";
  }

  if ($type==3)
  {
    $$ref1.=sprintf("$SEP %5d %5d %5d ",
	  $now[0], $now[1], $now[2]);
  }
}

sub nginxPrintExport
{
  my $type=shift;
  my $ref1=shift;
  my $ref2=shift;
  my $ref3=shift;

  if ($type eq 'g')
  {
    push @$ref1, "ngix.conn.active";
    push @$ref2, 'num';
    push @$ref3, $now[0];

    push @$ref1, "ngix.conn.accepted";
    push @$ref2, 'num';
    push @$ref3, $now[1];

    push @$ref1, "ngix.conn.handled";
    push @$ref2, 'num';
    push @$ref3, $now[2];
  }
}

sub doCurl
{
}
1;
