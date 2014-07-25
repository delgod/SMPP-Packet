use strict;
use warnings;

use Test::More;
use SMPP::Packet qw/pack_pdu unpack_pdu/;

my $pdu = {
    version   => 0x34,
    status    => 0,
    seq       => 28,
    command   => 'bind_transmitter_resp',
    system_id => 'SMSGW'
};
my $pdu_packet = pack_pdu($pdu);
ok $pdu_packet, 'pack_pdu($pdu)';

my $pdu_hashref = unpack_pdu($pdu_packet);
ok $pdu_hashref, 'unpack_pdu($pdu_packet)';

foreach my $key ( keys %{ $pdu_hashref } ) {
    next if !exists $pdu->{$key};
    is $pdu_hashref->{$key}, $pdu->{$key}, "check '$key' value";
}

done_testing;
