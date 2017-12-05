#!/usr/bin/perl
####################################################################################################
##
## txt-importjson.pl
##
####################################################################################################

use strict;
use 5.010;

use File::Slurp;
use File::Find;
use JSON;

use Txt;

####################################################################################################

main:
    {
    my $path = '/home/robot/txt/data';
    my $t    = Txt->connect;

    unless ($t)
        {
        die "no database";
        }

    my $code = sub
        {
        return unless (-f $File::Find::name);
        return unless ($File::Find::name =~ /json$/);

        my $json = read_file($File::Find::name);

        unless ($json)
            {
            die "read_file($File::Find::name)";
            }

        my $href = decode_json($json);

        unless ($href)
            {
            die "decode_json($json)";
            }

        my $rval = $t->txt_add($href);

        unless ($rval)
            {
            die "txt_add($json):" . $t->err;
            }
        };

    find({ wanted => $code, follow => 1 }, $path);

    $t->close;
    }

####################################################################################################
## eof
####################################################################################################
