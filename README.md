# NAME

SMPP::Packet

# SYNOPSIS

    use SMPP::Packet;

# DESCRIPTION

Reading and writing SMPP (Short Message Peer-to-Peer) packets.

# Examples
unpack SMPP packet
```
    my $pdu_ref = SMPP::Packet::unpack_pdu(
        {
            version => 0x34,
            data    => $packet,
        }
    );
    warn Dumper $pdu_ref;
    SMPP::Packet::hexdump($packet);
```

pack SMPP packet
```
    my $resp_pdu = SMPP::Packet::pack_pdu(
        {
            version   => 0x34,
            cmd       => 0,
            status    => 0,
            seq       => 0,
            command   => 'bind_transceiver_resp',
            system_id => 23
        }
    );
    SMPP::Packet::hexdump($resp_pdu);
```
# LICENSE

Copyright (C) Mykola Marzhan.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

Mykola Marzhan <delgod@delgod.com>
