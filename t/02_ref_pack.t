use strict;
use warnings;

use Test::More;
use File::Spec;
use Clone qw(clone);
use FindBin qw($Bin);

use SMPP::Packet qw(pack_pdu);

my $pdu = {
    version          => 0x34,
    status           => 0,
    validity_period  => 8,
    seq              => 28,
    sc_msg_reference => 44,
    msg_reference    => 44,
    message_id       => 44,
    destination_addr => '380504139380',
    esme_addr        => '380504139380',
    short_message    => q{},
    message_state    => 2,
    message_status   => 2,
    short_message    => 'yeynAymyath6 TykUshcajag9 NobOnOis7 addOrman4',
    num_msgs_submitted => 3,
    num_msgs_delivered => 4,
    done_date => '',
    submit_date => '',
    submit_time_stamp => '',
};

my $ref_dir = File::Spec->catfile( $Bin, 'ref_packets' );
opendir my $dh, $ref_dir
    or die "Cannot open directory with reference packets: $!\n";

while ( my $packet_type = readdir $dh ) {
    my $ref_file = File::Spec->catfile( $Bin, 'ref_packets', $packet_type );
    next if !-f $ref_file;
    next if $packet_type eq 'submit_multi';
    next if $packet_type eq 'submit_multi_resp';
    next if $packet_type eq 'submit_sm_v4';
    next if $packet_type eq 'submit_sm_resp_v4';

    local $/ = undef;
    open my $fh, '<', $ref_file
        or die "Cannot open file with reference packet content\n";
    my $ref_pdu_content = <$fh>;
    close $fh
        or die "Cannot open file with reference packet content\n";

    my $my_pdu = clone $pdu;
    $my_pdu->{'command'} = $packet_type;
    if ( $packet_type =~ m/_v4/ ) {
        $my_pdu->{'command'} =~ s/_v4//;
        $my_pdu->{'version'} = 0x40;
    }
    my $my_pdu_content = pack_pdu($my_pdu);

    ok $my_pdu_content, "pack '$packet_type' packet";
    next if !$my_pdu_content;

    if ( $my_pdu_content and $my_pdu_content eq $ref_pdu_content ) {
        pass "check '$packet_type' packet content";
    }
    else {
        fail "check '$packet_type' packet content";
        if ($my_pdu_content) {
            warn "Got: \n";
            SMPP::Packet::hexdump($my_pdu_content);
            warn "Expected: \n";
            SMPP::Packet::hexdump($ref_pdu_content);
        }
    }
}
closedir $dh;

done_testing;
