package SiteSearchUtils;

use strict;

sub checkPrevBatchDir {
  my ($prevBatchDir, $batchType, $batchName) = @_;

  return 0 unless -e $prevBatchDir;

  die "\nError: Incomplete batch dir (no DONE file): $prevBatchDir.  Please delete it first.\n" unless -e "$prevBatchDir/DONE";

  print STDOUT "Batch '$batchType $batchName' already present in targetDir.  Skipping.\n";
  return 1;
}

sub runWdkReport {
  my ($wdkServiceUrl, $targetDir, $batchDirPrefix, $batchType, $batchName, $organismAbbrev) = @_;
  my @temp = glob("$targetDir/${batchDirPrefix}_${batchType}_${batchName}*");

  return 0 if checkPrevBatchDir($temp[0], $batchType, $batchName);

  my $cmd = "ssCreateWdkRecordsBatch $batchType $batchName $wdkServiceUrl $targetDir";
  $cmd .= " --paramName organismAbbrev --paramValue $organismAbbrev" if $organismAbbrev;
  runCmd($cmd);
  return 1;
}

sub runWdkReportParam {
  my ($wdkServiceUrl, $targetDir, $batchDirPrefix, $batchType, $batchName, $paramName, $paramValue) = @_;
  my @temp = glob("$targetDir/${batchDirPrefix}_${batchType}_${batchName}*");

  return 0 if checkPrevBatchDir($temp[0], $batchType, $batchName);

  my $cmd = "ssCreateWdkRecordsBatch $batchType $batchName $wdkServiceUrl $targetDir  --paramName $paramName --paramValue $paramValue";
  runCmd($cmd);
  return 1;
}

sub runCmd {
  my ($cmd) = @_;
  print STDOUT "Running $cmd\n";
  system($cmd) && die "Failed\n";
}

sub getDbh {
  my ($props) = @_;

  my $u  = $props->{databaseLogin};
  my $pw = $props->{databasePassword};
  my $dsn = $props->{dbiDsn};
  $dbh = DBI->connect($dsn, $u, $pw) ||  die "Couldn't connect to database: " . DBI->errstr;
  $dbh->{RaiseError} = 1;
  return $dbh;
}

sub getPropsFromFile {
  my ($propFile) = @_;
  open(F, $propFile) || die "Error: can't open config file '$propFile'\n";
  my $props;
  while(<F>) {
    next if /^\s+$/;  # skip blank lines
    next if /^\s+\#/; # skip comments
    /(\w+)\=(\S+)/;
    $props->{$1} = $2;
  }
  return $props;
}

1;
