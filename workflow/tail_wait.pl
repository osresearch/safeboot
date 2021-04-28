#!/usr/bin/perl

die("usage") if (@ARGV != 2);
($file, $expr) = @ARGV;
die("open: $file") if (!open($fh, "<", $file));
while (seek($fh, 0, 1)) {
	while (defined($line = <$fh>)) {
		exit(0) if ($line =~ $expr);
	}
	sleep(1);
}
