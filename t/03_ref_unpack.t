use strict;
use warnings;

use Test::More;
use File::Spec;
use Clone qw(clone);
use FindBin qw($Bin);

use_ok 'SMPP::Packet';

my $pdu = {
    version          => 0x34,
    status           => 0,
    seq              => 28,
    message_id       => 44,
    destination_addr => '380504139380',
    esme_addr        => '380504139380',
    short_message    => q{},
    message_state    => 2,
    short_message    => 'yeynAymyath6 TykUshcajag9 NobOnOis7 addOrman4',
};

my $ref_dir = File::Spec->catfile( $Bin, 'ref_packets' );
opendir my $dh, $ref_dir
    or die "Cannot open directory with reference packets: $!\n";

while ( my $packet_type = readdir $dh ) {
    my $ref_file = File::Spec->catfile( $Bin, 'ref_packets', $packet_type );
    next if !-f $ref_file;
    next if $packet_type eq 'submit_multi';
    next if $packet_type eq 'submit_multi_resp';
    open my $fh, '<', $ref_file
        or die "Cannot open file with reference packet content\n";
    my $ref_pdu_content = <$fh>;
    close $fh
        or die "Cannot open file with reference packet content\n";

    my $my_pdu_ref = SMPP::Packet::unpack_pdu({ data => $ref_pdu_content });

    KEY:
    foreach my $key ( keys %{$pdu} ) {
        next KEY if !exists $my_pdu_ref->{$key};
        is $my_pdu_ref->{$key}, $pdu->{$key}, "check '$packet_type' packet content";
        if ( $my_pdu_ref->{$key} ne $pdu->{$key} ) {
            use Data::Dumper;
            print Dumper $my_pdu_ref;
        }
    }
}
closedir $dh;

done_testing;
