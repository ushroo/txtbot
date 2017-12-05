use strict;
use warnings;

package LWPAgent;

use base 'LWP::UserAgent';
use feature "state";

sub _agent
    {
    'Mozilla/4.0 (compatible; MSIE 6.0b; Windows NT 5.0; .NET CLR 1.1.4322)'
    }

sub get_fast($$)
    {
    my $self = shift;
    my $url  = shift;

    ### multiple tries

    for (0 .. 2)
        {
        ### rate limit

        state $mru = 0;

        for my $pause (time - $mru + int rand 37)
            {
            sleep(13 + $pause) if ($pause > 0);
            }

        $mru = time;

        ### do work

        my $res = $self->get($url);

        if ($res->is_success)
            {
            return $res->decoded_content;
            }
        }

    return undef;
    }

1;
