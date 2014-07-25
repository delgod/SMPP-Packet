# NAME

SMPP::Packet

# SYNOPSIS

    use SMPP::Packet;

# DESCRIPTION

Reading and writing SMPP (Short Message Peer-to-Peer) packets.

# Examples
unpack SMPP packet
```
    use SMPP::Packet qw/unpack_pdu/;
    my $pdu_hashref = unpack_pdu($pdu_packet);

    use Data::Dumper;
    warn Dumper $pdu_hashref;
```

pack SMPP packet
```
    use SMPP::Packet qw/pack_pdu/;
    my $pdu = {
        version   => 0x34,
        status    => 0,
        seq       => 28,
        command   => 'bind_transmitter_resp',
        system_id => 'SMSGW'
    };
    my $pdu_packet = pack_pdu($pdu);
    SMPP::Packet::hexdump($pdu_packet);
```
# LICENSE

Copyright (C) Mykola Marzhan.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

Mykola Marzhan <delgod@delgod.com>
