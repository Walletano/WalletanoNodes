#!/usr/bin/perl

use FindBin qw($Bin);
use lib $Bin;
use config;

use JSON;
use JSON::RPC::Legacy::Client;
use Data::Dumper;
use Digest::SHA qw(sha256_hex);

use Time::HiRes qw(sleep);

$url = "https://api.walletano.com/api/def/listpayments/apikey/".$apikey."/";

use FindBin qw($RealBin);
use File::Spec;

use File::Path qw(make_path);

my $log_file = File::Spec->catfile($RealBin, 'logs/initiatepayments.log');
my $log_dir = File::Spec->catdir($RealBin, 'logs');

# create the directory if it does not exist
make_path($log_dir);

# create the file if it does not exist
unless (-e $log_file) {
    open my $fh, '>', $log_file or warn "Could not create $log_file: $!";
    close $fh;
}

open(my $log_fh, '>>', $log_file) or warn "Couldn't open log file: $!";

while (1) {
	my @pwfiles = glob("$watcherfiledir/paymentwatcher-*");
	if ($lastapirequest + $minapirequesttime < time) {
		# before we crawl the URL, let's delete any dormant paymentwatcher file

		opendir(my $dh, $watcherfiledir) or warn "Failed to open directory: $!";

		print $log_fh time." - Open dir: $watcherfiledir to delete dormant paymentwatcher files\n";

		while (my $filename = readdir($dh)) {
			next unless ($filename =~ /^paymentwatcher-/); # skip files that don't match the pattern
			unlink("$watcherfiledir/$filename") or warn "Failed to delete file $filename: $!"; # delete the file
		}

		closedir($dh);

		print $log_fh time." - Passed $minapirequesttime seconds - Query payments URL...\n";
		$log_fh->flush();

		$lastapirequest = time;
		$output = qx{curl --silent $url};
	}
	elsif (@pwfiles) {
		my $mod_time = 0;
		my $pwfile = $pwfiles[0];
		print $log_fh time." - Reading payment from $pwfile...\n";

		open my $pwfh, '<', $pwfile or warn "Cannot open $pwfile: $!"; # open the file for reading
		read($pwfh, $output, -s $pwfh);
		close($pwfh);

		my $mod_time = (stat($pwfile))[9]; # get modification time

		if ($output =~ s/---EOF---\n?$//) {
			unlink $pwfile or warn "Cannot delete $pwfile: $!"; # delete the file
		}
		elsif (time - $mod_time > 30) {
			# if the paymentwatcher file is older than 30 seconds and upload is still not finished, we consider the upload aborted or other error and delete the file so it can continue faster to read other possible payments
			unlink $pwfile or warn "Cannot delete $pwfile: $!"; # delete the file
		}
		else {
			print $log_fh time." - Uploaded file not ready yet...\n";
		}

	}
	elsif (-e $watcherfilename) {
		unlink $watcherfilename;

		print $log_fh time." - Watcherfile exist, Query payments URL...\n";
		$log_fh->flush();

		$lastapirequest = time;
		$output = qx{curl --silent $url};
	}
	else {
	}

	if ($output) {
		my $output_json = eval { decode_json($output) };
		$output = "";

		$paymentslist = $output_json->{'paymentslist'};

		for my $payment (@{$paymentslist}) {
			$addtocmd = "";
			print $log_fh "$payment->{payment_hash}\n";
			$log_fh->flush();

			$compared_hash = sha256_hex($payment->{payment_request}.$nodesecret);
			if ($compared_hash ne $payment->{verifyhash}) {
				print $log_fh "Wrong verification hash, stop execution, do not proceed with payment! $compared_hash ne $payment->{verifyhash}\n";
				$log_fh->flush();
			}
			else {
				print $log_fh "Correct verification hash, proceed with payment...\n";
				if ($payment->{invoice_value} == 0) {
					$addamount = "--amt $payment->{payment_value}";
				}
				else {
					$addamount = "";
				}

				$fee_limit = int($payment->{payment_value} * $maxppm / 1000000 + 0.999) + $maxbase;

				$wltid_hash = sha256_hex("WLT".$payment->{wltid});

				if ($pubkey eq $payment->{destination}) {
					$addtocmd = "";
				}

				$commandtoexecute = "$lncli_comd payinvoice $payment->{payment_request} $addamount --timeout 9m30s --fee_limit $fee_limit --allow_self_payment $addtocmd -f &";
				system($commandtoexecute);
				print $log_fh $commandtoexecute."\n";
				$log_fh->flush();
			}
		}
	}

	if (int(time) % 10 == 0 && $lastlogprinted != int(time)) {
		$lastlogprinted = int(time);
		print $log_fh time." - Initiate Payments - Sleeping for a while...\n";
		$log_fh->flush();
	}

	sleep $sleeptime;
}

sub connectdb {
#############

	$dsn="DBI:mysql:database=$database;host=$dbserver:$dbport;max_allowed_packet=64;mysql_compression=1";
	$dbh = DBI->connect($dsn,$dbuser,$dbpass) || configerror('connect', $0);

	$dbh->{'mysql_enable_utf8'} = 1 if($flag_utf8_mode);
	$dbh->do(qq{SET NAMES 'utf8';}) if($flag_utf8_mode);

}



sub disconnectdb {
################

	# mysql gives a warning for this command
	$dbh->disconnect;

}

sub execsql {
###########

my ($sql_statement);

($sql_statement) = @_;

my $sth = $dbh->prepare($sql_statement) || &configerror('prep_sql', $0);

if ($dbh) {
	if (defined($sql_statement)) {

		eval
			{
				local $SIG{ALRM} = sub {&configerror('sql_timeout',$0);};
				alarm($sql_timeout_secs);
				$sth->execute || &configerror('sql', $0);
				alarm(0);
			};
		}
		else {
			&configerror('sql', $0);
		}
	}
	else {
		&configerror('connect');
	}

	return $sth;

}

exit;