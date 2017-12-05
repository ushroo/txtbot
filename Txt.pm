####################################################################################################
###
### Txt.pm
###
####################################################################################################

package Txt;

####################################################################################################

use warnings;
use strict;
use 5.010;

use WWW::Twilio::API;
use DBI;

####################################################################################################

sub clean($);

sub name_by_number($$);
sub number_by_name($$);

sub txt_add($);
sub txts_since($$$);

sub media_for($$$);
sub media_work($);
sub media_set_filename($$$);
sub media_set_status($$$);

sub q($$@);
sub connect($);
sub close($);
sub err($);

####################################################################################################

sub clean($)
    {
    my $s = shift;

    $s =~ s/^\s+//;
    $s =~ s/\s+$//;
    $s =~ s/\s+/ /g;

    return $s;
    }

####################################################################################################

sub resolve_who($$)
    {
    my $self = shift;
    my $who  = shift;

    ### might be a pnum

    if ($self->is_valid_pnum($who))
        {
        return $who;
        }

    ### might be a name

    return $self->number_by_name($who);
    }

####################################################################################################

sub is_valid_pnum($$)
    {
    my $self = shift;
    my $pnum = shift;

    return $pnum =~ /^\+1[0-9]{10}$/ ? 1 : 0;
    }

####################################################################################################

sub send_sms($$$)
    {
    my $self = shift;
    my $pnum = shift;
    my $body = shift;

    ### verify pnum

    unless ($self->is_valid_pnum($pnum))
        {
        say "[txt] bad pnum '$pnum'";

        return 0;
        }

    ### verify body

    $body = clean $body;

    unless ($body)
        {
        say "[txt] bad body '$body'";

        return 0;
        }

    ### length restriction

    my $len = length $body;

    if ($len > 160)
        {
        my $extra = $len - 160;

        say "[txt] body too long (by $extra)";

        return 0;
        }

    ### try to send that txt now

    my $rval = system '/usr/local/bin/curl' =>
                      '-X', 'POST',
                      'https://api.twilio.com/2010-04-01/Accounts/AC.../Messages.json',
                      '-s', '-k',
                      '--data-urlencode', 'To=' . $pnum,
                      '--data-urlencode', 'From=+..........',
                      '--data-urlencode', 'Body=' . $body,
                      '-u', 'AC...:...',
                      '--retry', 3, '--retry-delay', 2;

    ### success download

    if ($rval == 0)
        {
        say "[txt] sent sms '$pnum' '$body'";
        return 1;
        }
    else
        {
        say "[txt] failed to send sms '$pnum' '$body'";
        return 0;
        }

    ### UNREACHABLE

    ### this is the old, original code which wont work on old linux crypto

    my $twilio = WWW::Twilio::API->new(
        AccountSid => 'AC...',
        AuthToken  => '...',
        );

    my $res = $twilio->POST('Messages',
        From => '+..........',
        To   => $pnum,
        Body => $body,
        );

    unless ($res)
        {
        say "[txt] bad response: $!";

        return 0;
        }

    unless ($res->{code} == 201)
        {
        say "[txt] bad code $res->{code}: $res->{message}"; # $res->{content}

        return 0;
        }

    say "[txt] sent $pnum '$body'";

    return 1;
    }

####################################################################################################

sub send_mms($$$$)
    {
    my $self = shift;
    my $pnum = shift;
    my $mediaurl = shift;
    my $body = shift;

    ### verify pnum

    unless ($self->is_valid_pnum($pnum))
        {
        say "[txt] bad pnum '$pnum'";

        return 0;
        }

    ### verify body

    $body = clean $body;

    unless ($body)
        {
        say "[txt] bad body '$body'";

        return 0;
        }

    ### length restriction

    my $len = length $body;

    if ($len > 160)
        {
        my $extra = $len - 160;

        say "[txt] body too long (by $extra)";

        return 0;
        }

    ### try to send that mms now

    my $rval = system '/usr/local/bin/curl' =>
                      '-X', 'POST',
                      'https://api.twilio.com/2010-04-01/Accounts/AC.../Messages.json',
                      '-s', '-k',
                      '--data-urlencode', 'To=' . $pnum,
                      '--data-urlencode', 'From=+..........',
                      '--data-urlencode', 'Body=' . $body,
                      '-d', 'MediaUrl=' . $mediaurl,
                      '-u', 'AC...:...',
                      '--retry', 3, '--retry-delay', 2;

    ### success download

    if ($rval == 0)
        {
        say "[txt] sent mms '$pnum' '$body' '$mediaurl'";
        return 1;
        }
    else
        {
        say "[txt] failed to send mms '$pnum' '$body' '$mediaurl'";
        return 0;
        }
    }

####################################################################################################

sub name_by_number($$)
    {
    my $self = shift;
    my $pnum = shift;

    my $rval = $self->q('SELECT name FROM users WHERE pnum = ?' => $pnum);

    return $rval ? $rval->{name} : undef;
    }

####################################################################################################

sub number_by_name($$)
    {
    my $self = shift;
    my $name = shift;

    my $rval = $self->q('SELECT pnum FROM users WHERE name = ?' => $name);

    return $rval ? $rval->{pnum} : undef;
    }

####################################################################################################

sub txt_add($)
    {
    my $self = shift;
    my $txt  = shift;

    ### whew

    $self->q('INSERT INTO txts ( tw_Time, ' .
             'tw_MessageSid, tw_Body, tw_From, tw_FromCity, ' .
             'tw_FromCountry, tw_FromState, tw_FromZip, tw_NumMedia, ' .
             'tw_SmsMessageSid, tw_SmsSid, tw_SmsStatus, tw_To, '.
             'tw_ToCity, tw_ToCountry, tw_ToState, tw_ToZip ) ' .
             'VALUES ( ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ? )' =>
             $txt->{Time},
             $txt->{MessageSid}, $txt->{Body}, $txt->{From}, $txt->{FromCity},
             $txt->{FromCountry}, $txt->{FromState}, $txt->{FromZip}, $txt->{NumMedia},
             $txt->{SmsMessageSid}, $txt->{SmsSid}, $txt->{SmsStatus}, $txt->{To},
             $txt->{ToCity}, $txt->{ToCountry}, $txt->{ToState}, $txt->{ToZip}
             );

    ### any media attached to this message

    if ($txt->{NumMedia} > 0)
        {
        for my $idx (map { $_ - 1 } 1 .. $txt->{NumMedia})
            {
            my $url  = $txt->{"MediaUrl$idx"};          ### url
            my $mime = $txt->{"MediaContentType$idx"};  ### mime/type
            my $name = $url =~ s~.+/([^/]+)$~$1~r;      ### get filename from last part of url

            ### try to use the mime type

            if ($mime eq 'image/jpeg' or $mime eq 'image/jpg')
                {
                say "[txt_add] detected image (jpg)";
                $name .= '.jpg';
                }
            elsif ($mime eq 'image/png')
                {
                say "[txt_add] detected image (png)";
                $name .= '.png';
                }
            elsif ($mime eq 'video/3gpp')
                {
                say "[txt_add] detected video (3gpp)";
                $name .= '.3gp';
                }
            elsif ($mime eq 'video/mp4')
                {
                say "[txt_add] detected video (mp4)";
                $name .= '.mp4';
                }
            else
                {
                say "[txt_add] unknown mime type '$mime'";
                }

            ### save filename

            $self->q('INSERT INTO media ( tw_MessageSid, ' .
                     'idx, filename, ' .
                     'tw_MediaContentType, tw_MediaUrl ) ' .
                     'VALUES ( ?, ?, ?, ?, ? )' =>
                     $txt->{MessageSid},
                     $idx, $name,
                     $mime, $url);
            }
        }

    return 1;
    }

####################################################################################################
## get txts since given txt id value

sub txts_since_id($$$)
    {
    my $self = shift;
    my $id   = shift;
    my $call = shift;

    return $self->q('SELECT id, tw_Time, tw_Body, tw_From, tw_FromCity, tw_FromCountry, tw_FromState, tw_FromZip, tw_MessageSid, tw_NumMedia, tw_SmsMessageSid, tw_SmsSid, tw_SmsStatus, tw_To,tw_ToCity, tw_ToCountry, tw_ToState, tw_ToZip FROM txts WHERE ? < id ORDER BY id ASC' => $id, $call);
    }

####################################################################################################
## get txts since given txt id value

sub txts_last_id($)
    {
    my $self = shift;

    my $rval = $self->q('SELECT MAX ( id ) AS max FROM txts');

    return $rval ? $rval->{max} : 0;
    }

####################################################################################################
## get media attached to a txt

sub media_for($$$)
    {
    my $self = shift;
    my $msid = shift;
    my $call = shift;

    return $self->q('SELECT id, tw_MessageSid, idx, status, filename, tw_MediaContentType, tw_MediaUrl FROM media WHERE ? = tw_MessageSid ORDER BY id ASC' => $msid, $call);
    }

####################################################################################################
## get next media row which needs work (status = 0)

sub media_work($)
    {
    my $self = shift;

    return $self->q('SELECT * FROM media WHERE status = 0 ORDER BY id ASC LIMIT 1');
    }

####################################################################################################

sub media_set_filename($$$)
    {
    my $self = shift;
    my $id   = shift;
    my $file = shift;

    return $self->q('UPDATE media SET filename = ? WHERE id = ?' => $file, $id);
    }

####################################################################################################

sub media_set_status($$$)
    {
    my $self = shift;
    my $id   = shift;
    my $stat = shift;

    return $self->q('UPDATE media SET status = ? WHERE id = ?' => $stat, $id);
    }

####################################################################################################

sub q($$@)
    {
    my $self = shift;
    my $sql  = shift;
    my @args = @_;
    my $call;

    if (ref $args[-1] eq 'CODE')
        {
        $call = pop @args;
        }

    my $rval;

    $rval = eval
        {
        my $sth = $self->{dbh}->prepare($sql);

        $sth->execute(@args);

        if ($sql =~ /^select/i)
            {
            if ($call)
                {
                while (my $ref = $sth->fetchrow_hashref)
                    {
                    &$call($ref);
                    }

                return 1;
                }

            return $sth->fetchrow_hashref;
            }

        if ($sql =~ /insert/i or $sql =~ /delete/i or $sql =~ /update/i)
            {
            my $rows = $sth->rows;

            &$call($rows) if ($call);

            return $rows;
            }

        die "oh snap! $sql";
        };

    if ($@)
        {
        if ($self->err =~ /duplicate key value violates unique constraint/)
            {
            if (ref $call eq 'CODE')
                {
                &$call(0);
                }

            return 0;
            }

        die "error: q($sql -> " . join(', ' => map { "\'$_\'" } @args) . "): " . $self->err;
        }

    return $rval;
    }

####################################################################################################

sub connect($)
    {
    my $type = shift;

    my $self =
        {
        dbh => undef,
        };

    bless $self => $type;

    eval
        {
        my $ATTR =
            {
            AutoCommit => 1,
            RaiseError => 1,
            PrintError => 0,
            PrintWarn  => 0,
            };

        $self->{dbh} = DBI->connect('dbi:Pg:db=txt;host=127.0.0.1', 'txt', 'txt', $ATTR);
        };

    if ($@)
        {
        say 'txt::connect ' . $self->err;
        return undef;
        }

    return $self;
    }

####################################################################################################

sub close($)
    {
    my $self = shift;

    $self->{dbh}->disconnect;
    $self->{dbh} = undef;

    return 1;
    }

####################################################################################################

sub err($)
    {
    my $self = shift;
    my $err  = lc $DBI::errstr;

    $err =~ s/\n/ /g;
    $err =~ s/\s+/ /g;

    return $err;
    }

####################################################################################################

1;

####################################################################################################
## eof
####################################################################################################
