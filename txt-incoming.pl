#!/usr/bin/perl
####################################################################################################
##
## txt-incoming.pl
##
##  nginx.conf:
##
##      upstream mojo
##          {
##          server 127.0.0.1:3000;
##          }
##
##      server
##          {
##          ...
##
##          location /hello
##              {
##              proxy_pass http://mojo;
##              }
##          }
##
##  robot@lotor $ /usr/local/bin/morbo /home/robot/txt/txt-incoming.pl
##
##  https://ip-ranges.amazonaws.com/ip-ranges.json
##
##  callback : https://ushroo.com:6543/hello
##   pf.conf : pass in inet proto tcp from <awswhitelist> to any port 6543 rdr-to 127.0.0.1 port 443
##
##  PHONE --> SMS --> TWILIO --> SSL REQ TO https://ushroo.com:6543/hello --> GATEWAY -->
##  FWD TO 192.168.0.5:6543 --> FIREWALL --> PASS IN FROM <awswhitelist> RDR-TO 127.0.0.1:443 -->
##  NGINX --> LOCATION /hello --> PROXY_PASS http://127.0.0.1:3000 --> MOJOLICIOUS --> POST /hello
##  --> ENCODE_JSON --> WRITE TO LOCAL DISK
##
####################################################################################################

use 5.010;
use strict;
use warnings;

use Mojolicious::Lite;
use File::Slurp;
use Encode;
use JSON;

use Txt;

####################################################################################################

post '/hello' => sub
    {
    my $c = shift;

    ### save all posted variables

    my $href = { };

    $href->{Time} = time;                                     ### no timestamp is provided by Twilio

    foreach my $n (@{ $c->req->params->names })
        {
        $href->{$n} = encode_utf8($c->param($n));

        say "-- $n : $href->{$n}";
        }

    ### try to stash to disk

    my $filename = "/home/robot/txt/data/SMS-" . $href->{MessageSid} . ".json";

    write_file $filename => encode_json($href);

    ### try to stash to database

    my $txt = Txt->connect;

    unless ($txt)
        {
        die "no database";
        }

    $txt->txt_add($href);
    $txt->close;

    ### all ok

    return $c->render(text => '', status => 200)
    };

####################################################################################################
##
## consume any request to /
##

any '/' => sub
    {
    my $c = shift;

    return $c->render(text => 'uho big guy', status => 404)
    };

####################################################################################################
##
## consume any request to /.+
##

any '/:any' => sub
    {
    my $c = shift;

    return $c->render(text => 'uho big guy', status => 404)
    };

####################################################################################################

## only the first passphrase is used to create new signatures, but all of them for verification.
## increase security without invalidating all your existing signed cookies by rotating passphrases.
## add new ones to the front and remove old ones from the back.

app->secrets([
    '618837b87aa21d17c211982b49bb512d175aa92997326574a6778799d2519c91',         ## newest
    '2bd46ebb4135845ca5c1078c043036f0159b955e0d19b6e6b47c899e8accc28a',         ## older
    '963831589e63eec2bab0f70a881017f971b95ba99616613180297fc3c5f0248c',         ## oldest
    ]);

app->start;

####################################################################################################
## eof
####################################################################################################
