#!/usr/bin/perl
use strict;
use warnings;
use utf8;

binmode STDIN, ':encoding(utf8)';
binmode STDOUT, ':encoding(utf8)';
binmode STDERR, ':encoding(utf8)';

use FindBin qw($Bin);
use FindBin::libs;
use AnyEvent::SMTP::Server;
use WWW::PushBullet;
use Email::MIME;
use Encode qw(decode encode);
use YAML;

open FH, '<:encoding(utf8)', $Bin . '/../conf/config.yaml';
my $conf = YAML::Load(join('', <FH>)) or die;
close FH;

my $pb = WWW::PushBullet->new({apikey => $conf->{pushbullet}->{apikey}});

my $smtp = AnyEvent::SMTP::Server->new(
    port => $conf->{smtp}->{port},
);
$smtp->reg_cb(
    client => sub {
        my ($s, $con) = @_;
        warn "Client from $con->{host}:$con->{port} connected\n";
    },
    disconnect => sub {
        my ($s, $con) = @_;
        warn "Client from $con->{host}:$con->{port} gone\n";
    },
    mail => sub {
        my ($s, $mail) = @_;
        warn "Received mail from $mail->{from} to $mail->{to}\n$mail->{data}\n";

        eval {
            my $email = Email::MIME->new($mail->{data});

            my $subject = $email->header('Subject');
            $subject .= ' (from <' . $mail->{from} . '>)';

            my $body = undef;
            if($email->header('Content-Type') =~ /charset=\"?utf-8\"?/i)
            {
                $body = decode('utf-8', $email->body);
            }
            else
            {
                $body = decode('7bit-jis', $email->body);
            }
            print $body;

            $pb->push_note({
                title => encode('utf8', $subject),
                body => encode('utf8', $body),
            });
        };
        if($@)
        {
            warn "$@\n";
        }
    },
);
$smtp->start;
AnyEvent->condvar->recv;

