#!/usr/bin/perl -w
# PowerDNS Coprocess backend
# This Program is brought to you by help of the Song 'Commander Moira' by Ninja 9000 hence its name. ;-)
# (c) 2007,2008 by Stefan Schmidt

use strict;
use warnings;
use Net::CIDR;
use Net::Patricia;
use Tie::Cache;
#use Data::Dumper;
#$Data::Dumper::Purity = 1; # try your hardest
use lib "/root/pdns/backend";
use data;
$|=1;					# no buffering
my %cache=();
tie %cache, 'Tie::Cache', {
	Debug => 1,
	MaxCount => 30000,
	MaxBytes => 10485760,
	};
my %tries=();
$SIG{'HUP'}=\&flush;
$SIG{'USR1'}=\&dump_cache;
sub init_tries () {
	foreach my $qnamekey (keys %data::records) {
		foreach my $qtypekey (keys %{$data::records{$qnamekey}}) {
			$tries{pt}{$qnamekey}{$qtypekey}= new Net::Patricia;
			@{$tries{nc}{$qnamekey}{$qtypekey}}=();
			foreach my $cidrkey (keys %{$data::records{$qnamekey}{$qtypekey}}) {
				next if $cidrkey eq "WILDCARD";
				if($cidrkey=~/\./) {
					$tries{pt}{$qnamekey}{$qtypekey}->add_string($cidrkey);
				} elsif ($cidrkey=~/:/) {
					push @{$tries{nc}{$qnamekey}{$qtypekey}},$cidrkey;
				} else {
					die("parse error - unable to determine whether cidr range is ipv4(.) or ipv6(:) in $cidrkey");
				}
			}
		}
	}
}
sub flush () {
	%data::records=();
	%cache=();
	undef %data::records;
	do '/root/pdns/backend/data.pm' or die "can't recreate data from /root/pdns/backend/data.pm: $@";
	init_tries();
}
sub fetch_records ($$$) {
	my ($qname,$qtype,$network)=@_;
	my $answer;
	if((exists $data::records{$qname})
		&&(exists $data::records{$qname}{$qtype})
		&&(exists $data::records{$qname}{$qtype}{$network})
		&&(exists $data::records{$qname}{$qtype}{$network}{type})
		&&(defined $data::records{$qname}{$qtype}{$network}{type})
		&&($data::records{$qname}{$qtype}{$network}{type} ne "CNAME")) {
		if($data::records{$qname}{$qtype}{$network}{type} eq "RRSET") {
			RRSET: foreach my $rr (@{ $data::records{$qname}{$qtype}{$network}{content} }) {
				$answer.="DATA	$qname	IN	$qtype	$data::records{$qname}{$qtype}{$network}{ttl}	1	$rr\n";
			}
		} else {
			$answer="DATA	$qname	IN	$qtype	$data::records{$qname}{$qtype}{$network}{ttl}	1	$data::records{$qname}{$qtype}{$network}{content}\n";
		}
	} elsif ((exists $data::records{$qname})
		&&(exists $data::records{$qname}{$qtype})
		&&(exists $data::records{$qname}{$qtype}{$network})
		&&(exists $data::records{$qname}{$qtype}{$network}{type})
		&&(defined $data::records{$qname}{$qtype}{$network}{type})
		&&($data::records{$qname}{$qtype}{$network}{type} eq "CNAME")) {
		$answer="DATA	$qname	IN	CNAME	$data::records{$qname}{$qtype}{$network}{ttl}	1	$data::records{$qname}{$qtype}{$network}{content}\n";
	}
	return $answer;
}
sub print_records ($$$) {
	my ($qname,$qtype,$ip)=@_;
	my $answer;
	if($ip=~/\./) {
		#IPv4 - Net::Patricia
		if((exists $tries{pt}{$qname})
			&&(exists $tries{pt}{$qname}{$qtype})
			&&(defined $tries{pt}{$qname}{$qtype})) {
			my $network=$tries{pt}{$qname}{$qtype}->match_string($ip);
			if((defined $network)&&($network ne "")) {
				$answer=fetch_records($qname,$qtype,$network);
			} else {
				$answer=fetch_records($qname,$qtype,"WILDCARD");
			}
		}
	} elsif ($ip=~/:/) {
		#IPv6 - Net::CIDR
		if((exists $tries{nc}{$qname})
			&&(exists $tries{nc}{$qname}{$qname})
			&&(defined @{$tries{nc}{$qname}{$qtype}})) {
			if(Net::CIDR::cidrlookup($ip, @{$tries{nc}{$qname}{$qtype}})) {
				if((exists $data::records{$qname})
					&&(exists $data::records{$qname}{$qtype})) {
					foreach my $key (keys %{$data::records{$qname}{$qtype}}) {
						if($key ne "WILDCARD") {
							my @cidrlist=($key);
							if(Net::CIDR::cidrlookup($ip, @cidrlist)) {
								$answer=fetch_records($qname,$qtype,$key);
							} else {
								$answer=fetch_records($qname,$qtype,"WILDCARD");
							}
						}
					}
				}
			}
		}
	} else {
		$answer="LOG	parse error - unable to determine whether cidr range is ipv4(.) or ipv6(:) in $ip\n";
	}
	return $answer;
}
sub dump_cache () {
	if(open OUT,">/root/pdns/backend/tmp/cache.dump") {
		foreach my $key (keys %cache) {
			print OUT "$key -> $cache{$key}\n";
		}
		close OUT;
	}
	#if(open OUT,">/root/pdns/backend/tmp/data.structures.dump") {
	#	print OUT "### %cache ###\n\n";
	#	print OUT Data::Dumper->Dump([\%cache]);
	#	print OUT "### %data::records\n\n";
	#	print OUT Data::Dumper->Dump([\%data::records]);
	#	print OUT "### %tries ###\n\n";
	#	print OUT Data::Dumper->Dump([\%tries]);
	#	close OUT;
	#}
}
init_tries();
my $line=<>;
chomp($line);
unless($line eq "HELO\t2") {
	print "FAIL\n";
	<>;
	exit;
}
print "OK	Commander Moira fireing at Will!\n";	# print our banner
my @last_query=();
my ($type,$qname,$qclass,$qtype,$id,$ip,$lip);
LINE: while(<>)
{
	chomp();
	my @arr=split(/\t/);
	if((defined $arr[0])&&($arr[0] eq "PING")) {
		print "LOG	Commander Moira is still alife!\n";
		print "END\n";
		next LINE;
	}
	if((defined $arr[0])&&($arr[0] eq "AXFR")) {
		if(@last_query==7) {
			($type,$qname,$qclass,$qtype,$id,$ip,$lip)=@last_query;
			$qtype="ANY";
			my $cachekey="${qname}_${qtype}_${ip}";
			if((exists $cache{$cachekey})&&(defined $cache{$cachekey})&&($cache{$cachekey} ne "1")) {
				print $cache{$cachekey};
				print "END\n";
				next LINE;
			} elsif((exists $cache{$cachekey})&&(defined $cache{$cachekey})&&($cache{$cachekey} eq "1")) {
				print "END\n";
				next LINE;
			}
			my $answer;
			if(exists $data::records{$qname}) {
				foreach my $record_type (keys %{$data::records{$qname}}) {
					$answer.=print_records($qname,$record_type,$ip);
				}
			}
			if((defined $answer)&&($answer ne "")) {
				$cache{$cachekey}=$answer;
				print $answer;
			}
		}
		print "END\n";
		next LINE;
	}
	if((@arr)&&(@arr<7)) {
		print "LOG	PowerDNS sent too few arguments, wrong ABI Version 1 in config?\n";
		print "FAIL\n";
		next LINE;
	}
	($type,$qname,$qclass,$qtype,$id,$ip,$lip)=@arr;
	my $cachekey;
	if((defined $type)&&(defined $qname)&&(defined $qclass)&&(defined $qtype)&&(defined $id)&&(defined $ip)&&(defined $lip)) {
		$cachekey="${qname}_${qtype}_${ip}";
		#print "cachekey: \"$cachekey\"\n";
	} else {
		print "FAIL\n";
		next LINE;
	}
	if((exists $cache{$cachekey})&&(defined $cache{$cachekey})&&($cache{$cachekey} ne "1")) {
		#print "positive cache hit\n";
		print $cache{$cachekey};
		print "END\n";
		next LINE;
	} elsif((exists $cache{$cachekey})&&(defined $cache{$cachekey})&&($cache{$cachekey} eq "1")) {
		#print "negative cache hit\n";
		print "END\n";
		next LINE;
	}
	if($type ne "Q") {
		#print "type ne \"Q\"\n";
		print "END\n";
		next LINE;
	}
	if((defined $type)&&(defined $qname)&&(defined $qclass)&&(defined $qtype)&&(defined $id)&&(defined $ip)&&(defined $lip)) {
		#print "new request - type: \"$type\" qname: \"$qname\" qclass: \"$qclass\" qtype: \"$qtype\" id: \"$id\" ip: \"$ip\" lip: \"$lip\"\n";
		if(exists $data::records{$qname}) {
			if((exists $data::records{$qname}{$qtype})||($qtype eq "ANY")) {
				#print "found $data::records{$qname} and $data::records{$qname}{$qtype}\n";
				my $answer;
				if($qtype eq "ANY") {
					foreach my $record_type (keys %{$data::records{$qname}}) {
						my $tmp=print_records($qname,$record_type,$ip);
						if((defined $tmp)&&($tmp ne "")) {
							$answer.=$tmp;
						}
					}
				} else {
					$answer=print_records($qname,$qtype,$ip);
				}
				if((defined $answer)&&($answer ne "")) {
					$cache{$cachekey}=$answer;
					print $answer;
				}
			} elsif ((!exists $data::records{$qname}) && ((!exists $data::records{$qname}{$qtype})||($qtype eq "ANY"))) {
				#print "did not find any data\n";
				$cache{$cachekey}=1;
			}
		}
		@last_query=($type,$qname,$qclass,$qtype,$id,$ip,$lip);
	} else {
		#print "error - type: \"$type\" qname: \"$qname\" qclass: \"$qclass\" qtype: \"$qtype\" id: \"$id\" ip: \"$ip\" lip: \"$lip\"\n";
		print "LOG	ERROR - some parts are missing - this should not happen!\n";
	}
	print "END\n";
	next LINE;
}
