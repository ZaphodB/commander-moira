package data;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(%records);
# dont mess with those data structures, they are hardcoded in the commander moira backend!!!
our %records=(
	"test.example.com" => {
		"SOA" => {
			"192.168.0.0/24" => {
				type => "RR",
				ttl => 1234,
				content => "localhost hostmaster.does.not.matter 0 10800 3600 604800 3600",
			},
			"WILDCARD" => {
				type => "RR",
				ttl => 3600,
				content => "localhost hostmaster.maybe.does.matter 0 10800 3600 604800 3600",
			},
		},
		"NS" => {
			"WILDCARD" => {
				type => "RRSET",
				ttl => 300,
				content => [
					"ns1.example.com",
					"ns2.example.com",
					],
			},
		},
		"A" => {
			"192.168.0.0/24" => {
				type => "RR",
				ttl => 1234,
				content => "127.0.0.16",
			},
			"WILDCARD" => {
				type => "RR",
				ttl => 3600,
				content => "127.0.0.3",
			},
		},
		"TXT" => {
			"192.168.0.0/24" => {
				type => "RR",
				ttl => 3600,
				content => "\"you are coming from some RFC1918 network\"",
			},
			"WILDCARD" => {
				type => "RR",
				ttl => 3600,
				content => "\"you are coming from someplace that i do not know\"",
			},
		},
	},
	"www.example.org" => {
		"NS" => {
			"WILDCARD" => {
				type => "RRSET",
				ttl => 300,
				content => [
					"ns1.example.com",
					"ns2.example.com",
					],
			},
		},
		"SOA" => {
			"10.0.0.0/8" => {
				type => "RR",
				ttl => 60,
				content => "localhost hostmaster.example.com 0 10800 3600 604800 3600",
			},
			"192.168.0.0/24" => {
				type => "RR",
				ttl => 60,
				content => "localhost hostmaster.example.org 0 10800 3600 604800 3600",
			},
		},
		"A" => {
			"10.0.0.0/8" => {
				type => "RR",
				ttl => 60,
				content => "127.0.0.4",
			},
			"192.168.0.0/24" => {
				type => "RR",
				ttl => 60,
				content => "127.0.0.5",
			},
		},
	},
);
