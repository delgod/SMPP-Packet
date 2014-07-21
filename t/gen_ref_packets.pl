#!/usr/bin/perl

use strict;
use warnings;

use SMPP::Packet qw/pack_pdu unpack_pdu/;
use AnyEvent::Socket qw/tcp_server/;
use AnyEvent::PacketReader;
use FindBin qw($Bin);
use File::Spec;
use Net::SMPP;

my $watcher;
my $done        = AnyEvent->condvar;
my $server_port = 9900;
start_smpp_server();
send_smpp_packets();
$done->recv;
exit 0;

sub start_smpp_server {
    tcp_server(
        '127.0.0.1',
        $server_port,
        sub {
            my ($fh) = @_;
            $watcher = packet_reader(
                $fh, 'N@!0',
                sub {
                    return if !$_[0];
                    process_packet( $fh, $_[0] );
                }
            );
        }
    );

    return;
}

sub process_packet {
    my ( $socket, $packet ) = @_;
    my $pdu_ref = SMPP::Packet::unpack_pdu(
        {
            version => 0x34,
            data    => $packet,
        }
    );
    my $filename = File::Spec->catfile( $Bin, 'ref_packets', $pdu_ref->{'command'} );
    open my $etalon_fh, '>', $filename
        or die "Cannot create $filename: $!";
    print {$etalon_fh} $packet;
    close $etalon_fh
        or die "Cannot create $filename: $!";

    my $resp_pdu = SMPP::Packet::pack_pdu( { version => 0x34, status => 0, seq => 0, command => 'enquire_link_resp' } );
    syswrite $socket, $resp_pdu;

    if ( $pdu_ref->{'command'} eq 'data_sm_resp' ) {
        $done->send();
    }

    return;
}

sub send_smpp_packets {
    my $cli = Net::SMPP->new_connect( '127.0.0.1', port => $server_port, smpp_version => 0x34, async => 1 );
    $cli->set_version(0x34);

    $cli->generic_nack( seq => 28 );
    $cli->bind_receiver( seq => 28 );
    $cli->bind_receiver_resp( seq => 28 );
    $cli->bind_transmitter( seq => 28 );
    $cli->bind_transmitter_resp( seq => 28 );
    $cli->query_sm( message_id => 44, seq => 28 );
    $cli->query_sm_resp( message_state => 2, message_id => 44, seq => 28 );
    $cli->submit_sm( destination_addr => '380504139380', seq => 28 );
    $cli->submit_sm_resp( message_id => 44, seq => 28 );
    $cli->deliver_sm( destination_addr => '380504139380', seq => 28 );
    $cli->deliver_sm_resp( message_id => 44, seq => 28 );
    $cli->unbind( seq => 28 );
    $cli->unbind_resp( seq => 28 );
    $cli->replace_sm( message_id => 44, seq => 28 );
    $cli->replace_sm_resp( seq => 28 );
    $cli->cancel_sm( destination_addr => '380504139380', message_id => 44, seq => 28 );
    $cli->cancel_sm_resp( seq => 28 );
    $cli->bind_transceiver( seq => 28 );
    $cli->bind_transceiver_resp( seq => 28 );
    $cli->outbind( seq => 28 );
    $cli->enquire_link( seq => 28 );
    $cli->enquire_link_resp( seq => 28 );
    $cli->submit_multi( destination_addr => '380504139380' );
    $cli->submit_multi_resp( message_id => 44, error_status_code => 0, seq => 28 );
    $cli->alert_notification( esme_addr => '380504139380', seq => 28 );
    $cli->data_sm( destination_addr => '380504139380', seq => 28 );
    $cli->data_sm_resp( message_id => 44, seq => 28 );

    return;
}
