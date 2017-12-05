#!/usr/bin/perl
####################################################################################################
##
## txt-media-worker.pl -- run me continuously in a tmux window, not cron
##
####################################################################################################

use warnings;
use strict;
use 5.010;

use Txt;

####################################################################################################

my $MEDIA = '/home/robot/txt/media';

###################################################################################################

main:
    {
    my $t = Txt->connect;

    unless ($t)
        {
        die "no database";
        }

    say 'txt media worker started';

    while (1)
        {
        ### try to get a candidate

        my $media = $t->media_work;

        ### nothing to do

        unless ($media)
            {
            sleep 8;

            next;
            }

        ### got a candidate

        say "[$media->{id}] filename $media->{filename} $media->{tw_mediacontenttype}";

        ### maybe this attachment already exists

        my $localfile = "$MEDIA/$media->{filename}";

        if (-e $localfile)
            {
            say "existing $localfile";

            $t->media_set_status($media->{id} => 200);
            }
        else
            {
            say "fetching $localfile";

            my $rval = system '/usr/local/bin/curl' =>
                              $media->{tw_mediaurl}, '-s',
                              '--retry', 4, '--retry-delay', 17,
                              '-L', '-o', $localfile;

            ### success download

            if ($rval == 0)
                {
                say "all ok";

                $t->media_set_status($media->{id} => 200);
                }
            else
                {
                say "failed";

                $t->media_set_status($media->{id} => 404);
                }
            }
        }
    }

####################################################################################################
## eof
####################################################################################################
