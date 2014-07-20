package SMPP::Packet;

use strict;
use warnings;

use Data::Dumper;
use List::Util qw/first/;

use base qw(Exporter);
our $VERSION     = '0.01';
our %EXPORT_TAGS = ( 'all' => [qw{pack_pdu unpack_pdu hexdump}], );
our @EXPORT_OK   = @{ $EXPORT_TAGS{'all'} };

my $header_dict = {
    0x34 => {
        template    => 'NNNN',        # v3.4 'NNNN', #4> v4.0 'NNNNxxxx', must change in tandem with above <4#
        lenght      => 16,            # v3.4 16, #4> v4.0 20, must change in tandem with smpp_version <4#
        cmd_version => 0x00000000,    # v3.4 0x00000000, #4> v4 0x00010000; to be or'd with cmd <4#
    },
};
my $body_dict = {
    0x34 => {
        bind_receiver => {
            id       => 0x00000001,
            template => 'Z*Z*Z*CCCZ*',
            attr_seq => [qw/system_id password system_type interface_version addr_ton addr_npi address_range/],
        },
        bind_receiver_resp => {
            id       => 0x80000001,
            template => 'Z*',
            attr_seq => [qw/system_id/],
        },
        bind_transmitter => {
            id       => 0x00000002,
            template => 'Z*Z*Z*CCCZ*',
            attr_seq => [qw/system_id password system_type interface_version addr_ton addr_npi address_range/],
        },
        bind_transmitter_resp => {
            id       => 0x80000002,
            template => 'Z*',
            attr_seq => [qw/system_id/],
        },
        submit_sm => {
            id       => 0x00000004,
            template => 'Z*CCZ*CCZ*CCCZ*Z*CCCCC',
            attr_seq => [
                qw/service_type source_addr_ton source_addr_npi source_addr dest_addr_ton dest_addr_npi destination_addr esm_class protocol_id priority_flag schedule_delivery_time validity_period registered_delivery replace_if_present_flag data_coding sm_default_msg_id sm_length/
            ],
        },
        submit_sm_resp => {
            id       => 0x80000004,
            template => 'Z*',
            attr_seq => [qw/message_id/],
        },
        bind_transceiver => {
            id       => 0x00000009,
            template => 'Z*Z*Z*CCCZ*',
            attr_seq => [qw/system_id password system_type interface_version addr_ton addr_npi address_range/],
        },
        bind_transceiver_resp => {
            id       => 0x80000009,
            template => 'Z*',
            attr_seq => [qw/system_id/],
        },
        unbind => {
            id       => 0x00000006,
            template => q{},
            attr_seq => [],
        },
        'bind' => {
            id       => 0x00000009,
            template => 'Z*Z*Z*CCCZ*',
            attr_seq => [qw/system_id password system_type interface_version addr_ton addr_npi address_range/],
        },
    },
};

sub pack_pdu {
    my ($data_ref) = @_;

    validate($data_ref)
        or return;

    my $body_str = get_body_str($data_ref);
    my $header_str = get_header_str( $data_ref, length $body_str );

    return $header_str . $body_str;
}

sub validate {
    my ($data_ref) = @_;

    my @header_attr = qw/version command status seq/;
    my @missing_attr = grep { !exists $data_ref->{$_} } @header_attr;
    if ( scalar @missing_attr > 0 ) {
        warn 'following mandatory header fields are missing: ' . join( ', ', @missing_attr ) . "\n";
        return;
    }

    my $body_attr_ref = $body_dict->{ $data_ref->{'version'} }->{ $data_ref->{'command'} }->{'attr_seq'};
    @missing_attr = grep { !exists $data_ref->{$_} } @{$body_attr_ref};
    if ( scalar @missing_attr > 0 ) {
        warn 'following mandatory body fields are missing: ' . join( ', ', @missing_attr ) . "\n";
        return;
    }

    return 1;
}

sub get_header_str {
    my ( $data_ref, $body_len ) = @_;

    my $head_templ  = $header_dict->{ $data_ref->{'version'} }->{'template'};
    my $head_len    = $header_dict->{ $data_ref->{'version'} }->{'lenght'};
    my $cmd_version = $header_dict->{ $data_ref->{'version'} }->{'cmd_version'};
    my $op_code     = $body_dict->{ $data_ref->{'version'} }->{ $data_ref->{'command'} }->{'id'};

    return pack $head_templ, $head_len + $body_len, $op_code | $cmd_version, $data_ref->{'status'}, $data_ref->{'seq'};
}

sub get_body_str {
    my ($data_ref) = @_;
    my $template   = $body_dict->{ $data_ref->{'version'} }->{ $data_ref->{'command'} }->{'template'};
    my $attr_seq   = $body_dict->{ $data_ref->{'version'} }->{ $data_ref->{'command'} }->{'attr_seq'};
    return pack $template, map { $data_ref->{$_} } @{$attr_seq};
}

sub unpack_pdu {
    my ($data_ref) = @_;

    my %pdu;
    my $head_templ = $header_dict->{ $data_ref->{'version'} }->{'template'};
    my $head_len   = $header_dict->{ $data_ref->{'version'} }->{'lenght'};
    ( $pdu{'length'}, $pdu{'command_id'}, $pdu{'status'}, $pdu{'seq'} ) = unpack $head_templ, $data_ref->{'data'};

    $pdu{'version'} = $data_ref->{'version'};
    $pdu{'command'} = get_command_name( $data_ref->{'version'}, $pdu{'command_id'} );

    if ( $pdu{'length'} <= $head_len ) {
        return \%pdu;
    }
    my $body_str = substr $data_ref->{'data'}, $head_len;
    my $template = $body_dict->{ $data_ref->{'version'} }->{ $pdu{'command'} }->{'template'};
    my $attr_seq = $body_dict->{ $data_ref->{'version'} }->{ $pdu{'command'} }->{'attr_seq'};
    my @options  = unpack $template, $body_str;

    my $body_len = 0;
    foreach my $idx ( 0 .. $#{$attr_seq} ) {
        $pdu{ ${$attr_seq}[$idx] } = $options[$idx];
        my $attr_len = length $options[$idx];
        $body_len += $attr_len > 1 ? $attr_len + 1 : 1;
    }

    if ( exists $pdu{'sm_length'} ) {
        ( $pdu{'short_message'} ) = unpack "a$pdu{'sm_length'}", substr $body_str, $body_len;
    }
    return \%pdu;
}

sub get_command_name {
    my ( $version, $command_id ) = @_;
    return first { $command_id == $body_dict->{$version}->{$_}->{'id'} } keys %{ $body_dict->{$version} };
}

sub hexdump {
    local ( $!, $@ );
    no warnings qw(uninitialized);
    while ( $_[0] =~ /(.{1,32})/smg ) {
        my $line = $1;
        my @c = ( ( map { sprintf "%02x", $_ } unpack( 'C*', $line ) ), ( ("  ") x 32 ) )[ 0 .. 31 ];
        $line =~ s/(.)/ my $c=$1; unpack("c",$c)>=32 ? $c : '.' /egms;
        print STDERR "$_[1] ", join( " ", @c, '|', $line ), "\n";
    }
    print STDERR "\n";
}

1;
