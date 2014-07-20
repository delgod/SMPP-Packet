use strict;
use warnings;

use Test::More;

use_ok 'SMPP::Packet';

my $pdu = {
    version   => 0x34,
    cmd       => 0,
    status    => 0,
    seq       => 0,
    command   => 'bind_transceiver_resp',
    system_id => 23
};

my $pdu_packet = SMPP::Packet::pack_pdu($pdu);
ok $pdu_packet, 'pack_pdu($params)';

my $pdu_hashref = SMPP::Packet::unpack_pdu( { version => 0x34, data => $pdu_packet } );
ok $pdu_hashref, 'unpack_pdu($params)';
is $pdu_hashref->{command},   $pdu->{command},   'check "command" value';
is $pdu_hashref->{system_id}, $pdu->{system_id}, 'check "system_id" value';

done_testing;
