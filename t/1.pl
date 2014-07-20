#!/usr/bin/perl

use SMPP::Packet;
use Data::Dumper;

open my $fh, '<', './etalon/submit_sm';
my $packet = <$fh>;
close $fh;


    my $pdu_ref = SMPP::Packet::unpack_pdu({
        version => 0x34,
        data => $packet,
    });

    my $resp_ref = {
        version => 0x34,
        status => 0,
        seq => 2,
        command => 'submit_sm',
          'service_type' => '',
          'source_addr_ton' => 0,
          'source_addr_npi' => 0,
          'source_addr' => 'smppsvrtst.pl',
          'dest_addr_ton' => 0,
          'dest_addr_npi' => 0,
          'destination_addr' => '380504139380',
          'esm_class' => 0,
          'protocol_id' => 0,
          'priority_flag' => 0,
          'schedule_delivery_time' => '',
          'validity_period' => '',
          'registered_delivery' => 0,
          'replace_if_present_flag' => 0,
          'data_coding' => 0,
          'sm_default_msg_id' => 0,
          'short_message' => 'test32d3',
      };
    my $resp_pdu = SMPP::Packet::pack_pdu($resp_ref);

    #warn Dumper $pdu_ref;
    SMPP::Packet::hexdump( $packet );
    #warn Dumper $resp_ref;
    SMPP::Packet::hexdump( $resp_pdu );

    if ( $packet ne $resp_pdu ) {
        print "ERROR\n";
    }
    else {
        print "OK\n";
    }
