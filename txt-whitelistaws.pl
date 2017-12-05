#!/usr/bin/perl
####################################################################################################
##
## whitelist-aws.pl
##
##  1) download <https://ip-ranges.amazonaws.com/ip-ranges.json>
##  2) foreach ip range, add to table <awswhitelist>
##  3) add to /etc/pf.conf
##
##      pass in inet proto tcp from <awswhitelist> to any port 6543
##
####################################################################################################

use warnings;
use strict;
use 5.010;

use LWPAgent;
use JSON;

sub cmd_add($);
sub cmd_flush();

####################################################################################################

main:
    {
    my $ua = LWPAgent->new;

    ### get fresh ip range json document

    my $url = 'https://ip-ranges.amazonaws.com/ip-ranges.json';

    say "fetching $url";

    my $json = $ua->get_fast($url);

    unless ($json)
        {
        die "no json: $!";
        }

    ### try decode

    my $href = decode_json($json); ### XXX i think this can die?

    unless ($href)
        {
        die "bad json: $!";
        }

    ### flush the existing table

    cmd_flush();

    ### headers

    say sprintf '%-30s %-30s %-30s' => 'prefix', 'region', 'service';
    say sprintf '%-30s %-30s %-30s' => ('-' x 25) x 3;

    ### whitelist the ips

    foreach my $pre (@{ $href->{prefixes} })
        {
        say sprintf '%-30s %-30s %-30s' => $pre->{ip_prefix}, $pre->{region}, $pre->{service};

        cmd_add($pre->{ip_prefix});
        }
    }

####################################################################################################

sub cmd_add($)
    {
    my $ip = shift;

    system 'sudo', '/sbin/pfctl', '-t', 'awswhitelist', '-T', 'add', $ip;
    }

####################################################################################################

sub cmd_flush()
    {
    system 'sudo', '/sbin/pfctl', '-t', 'awswhitelist', '-T', 'flush';
    }

####################################################################################################
## eof
####################################################################################################
