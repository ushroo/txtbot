#!/usr/bin/perl
####################################################################################################

use lib '/home/robot/txt';

use strict;
use 5.010;

use Irssi;
use File::Find;
use File::Slurp;
use JSON;

use Txt;

####################################################################################################

sub cmd_txt($$$);
sub hot_txts();
sub on_public($$$$$);

sub escape($);
sub clean($);

####################################################################################################

my $tag   = undef; ### irssi server tag
my $timer = undef; ### irssi timer

main:
    {
    say "[txt] dont forget to /txt start";

    Irssi::command_bind('txt', 'cmd_txt');

    Irssi::signal_add_last("message public", "on_public");
    }

####################################################################################################

sub on_public($$$$$)
    {
    my ($SERV, $msg, $nick, $addr, $target) = @_;

    ### clean

    if (!$target)      { $target = $nick;         }
    if ($nick =~ /^#/) { $nick   = $SERV->{nick}; }

    ### no robots

    return if $addr =~ /robot/;

    ### triggers

    if ($msg =~ /^txt (\w+?) (.+)$/)
        {
        my $who = clean $1;
        my $msg = clean $2;

        ### ops only

        my $CHAN = Irssi::channel_find($target);
        my $NICK = $CHAN->nick_find($nick);

        unless ($NICK->{op})
            {
            $SERV->command("MSG $target " . escape("<G>T</G> \"sent\""));

            return;
            }

        ### send that txt

        send_txt($SERV, $who, $msg);
        }
    }

####################################################################################################

sub cmd_txt($$$)
    {
    my ($data, $SERV, $item) = @_;

    if (!$SERV)
        {
        say "[txt] cmd_txt: not connected to a server";

        return;
        }

    if ($data =~ /^start$/i)
        {
        my $msecs = 37    # seconds
                  * 1000; # milliseconds

        if ($timer)
            {
            say "[txt] already started";

            return;
            }

        ### schedule repeating timer

        $tag   = $SERV->{tag};
        $timer = Irssi::timeout_add($msecs, 'hot_txts', undef);

        say "[txt] timer started";

        ### do once immediately

        hot_txts();

        return;
        }

    if ($data =~ /^stop$/i)
        {
        unless ($timer)
            {
            say "[txt] not started";

            return;
            }

        Irssi::timeout_remove($timer);

        $timer = undef;

        say "[txt] stopped ticker timer";

        return;
        }

    say "[txt] try /txt { start | stop }";
    }

####################################################################################################

sub hot_txts()
    {
    my $SERV = Irssi::server_find_tag($tag);

    ### connect to database

    my $t = Txt->connect;

    unless ($t)
        {
        say "[txt] no data";

        return;
        }

    ### since and when

    state $last_id = $t->txts_last_id;

    ### try for new messages

    say "[txt] since $last_id";

    $t->txts_since_id($last_id => sub ($)
        {
        my $txt = shift;

        my $who = $t->name_by_number($txt->{tw_from});

        $who //= 'unknown';

        $txt->{tw_body} ||= '...';

        say "[txt] $txt->{id} recv <$who> $txt->{tw_body}";

        $SERV->command("MSG #ushroo " . escape("<G>T</G> recv <$who> $txt->{tw_body}"));

        ### attachments

        $t->media_for($txt->{tw_messagesid} => sub ($)
            {
            my $media = shift;

            say "[txt] https://ushroo.com/txt/$media->{filename}";
            $SERV->command("MSG #ushroo " . escape("<G>T</G> recv https://ushroo.com/txt/$media->{filename}"));
            });

        ### save this id

        $last_id = $txt->{id};
        });

    $t->close;
    }

####################################################################################################

sub send_txt($$$)
    {
    my $SERV = shift;
    my $who  = shift;
    my $body = shift;

    ### connect to database

    my $t = Txt->connect;

    unless ($t)
        {
        say "[txt] no data";

        return;
        }

    ### resolve "who" into a phone number

    my $pnum = $t->resolve_who($who);

    unless ($pnum)
        {
        $SERV->command("MSG #ushroo " . escape "<G>T</G> <B>$who</B> isn't in my contacts");

        return;
        }

    ### send message

    if ($body =~ /^(https?:\/\/.+\.(?:jpg|gif|png|jpeg)) (.+)$/)
        {
        my $mediaurl = $1;
        $body = $2;

        my $rval = $t->send_mms($pnum, $mediaurl, $body);

        if ($rval)
            {
            $SERV->command("MSG #ushroo " . escape "<G>T</G> mms sent");
            }
        else
            {
            $SERV->command("MSG #ushroo " . escape "<G>T</G> mms error! i need an adult...");
            }
        }
    else
        {
        my $rval = $t->send_sms($pnum, $body);

        if ($rval)
            {
            $SERV->command("MSG #ushroo " . escape "<G>T</G> sent");
            }
        else
            {
            $SERV->command("MSG #ushroo " . escape "<G>T</G> sms error! i need an adult...");
            }
        }

    $t->close;
    }

####################################################################################################

my %COLORS = (
    "white"   => 0,  "black"   => 1,  "blue"    => 2,
    "green"   => 3,  "lred"    => 4,  "red"     => 5,
    "purp"    => 6,  "orange"  => 7,  "yellow"  => 8,
    "lgreen"  => 9,  "cyan"    => 10, "lcyan"   => 11,
    "lblue"   => 12, "lpurp"   => 13, "gray"    => 14,
    "lgray"   => 15,
    );

sub escape($)
    {
    my $string = shift;

    $string =~ s~<B>~\002~gi;
    $string =~ s~</B>~\017~gi;

    my $color = sprintf "%02d" => $COLORS{lgreen};

    $string =~ s~<G>~\003$color~gi;
    $string =~ s~</G>~\017~gi;

    my $color = sprintf "%02d" => $COLORS{lred};

    $string =~ s~<R>~\003$color~gi;
    $string =~ s~</R>~\017~gi;

    my $color = sprintf "%02d" => $COLORS{yellow};

    $string =~ s~<Y>~\003$color~gi;
    $string =~ s~</Y>~\017~gi;

    my $color = sprintf "%02d" => $COLORS{cyan};

    $string =~ s~<C>~\003$color~gi;
    $string =~ s~</C>~\017~gi;

    my $color = sprintf "%02d" => $COLORS{orange};

    $string =~ s~<O>~\003$color~gi;
    $string =~ s~</O>~\017~gi;

    return $string;
    }

####################################################################################################

sub clean($)
    {
    my $s = shift;

    # $s = lc $s;

    $s =~ s/^\s+//;
    $s =~ s/\s+$//;
    $s =~ s/\s+/ /g;

    return $s;
    }

####################################################################################################
## eof
####################################################################################################
