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
        generic_nack => {
            id       => 0x80000000,
            template => q{},
            attr_seq => [],
        },
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
        query_sm => {
            id       => 0x00000003,
            template => 'Z*CCZ*',
            attr_seq => [qw/message_id source_addr_ton source_addr_npi source_addr/],
        },
        query_sm_resp => {
            id       => 0x80000003,
            template => 'Z*Z*CC',
            attr_seq => [qw/message_id final_date message_state error_code/],
        },
        submit_sm => {
            id       => 0x00000004,
            template => 'Z*CCZ*CCZ*CCCZ*Z*CCCCC',
            attr_seq => [
                qw/service_type source_addr_ton source_addr_npi source_addr dest_addr_ton dest_addr_npi destination_addr esm_class protocol_id priority_flag schedule_delivery_time validity_period registered_delivery replace_if_present_flag data_coding sm_default_msg_id sm_length short_message/
            ],
        },
        submit_sm_resp => {
            id       => 0x80000004,
            template => 'Z*',
            attr_seq => [qw/message_id/],
        },
        deliver_sm => {
            id       => 0x00000005,
            template => 'Z*CCZ*CCZ*CCCZ*Z*CCCCC',
            attr_seq => [
                qw/service_type source_addr_ton source_addr_npi source_addr dest_addr_ton dest_addr_npi destination_addr esm_class protocol_id priority_flag schedule_delivery_time validity_period registered_delivery replace_if_present_flag data_coding sm_default_msg_id sm_length short_message/
            ],
        },
        deliver_sm_resp => {
            id       => 0x80000005,
            template => 'Z*',
            attr_seq => [qw/message_id/],
        },
        unbind => {
            id       => 0x00000006,
            template => q{},
            attr_seq => [],
        },
        unbind_resp => {
            id       => 0x80000006,
            template => q{},
            attr_seq => [],
        },
        replace_sm => {
            id       => 0x00000007,
            template => 'Z*CCZ*Z*Z*CCC',
            attr_seq => [
                qw/message_id source_addr_ton source_addr_npi source_addr schedule_delivery_time validity_period registered_delivery sm_default_msg_id sm_length short_message/
            ],
        },
        replace_sm_resp => {
            id       => 0x80000007,
            template => q{},
            attr_seq => [],
        },
        cancel_sm => {
            id       => 0x00000008,
            template => 'Z*Z*CCZ*CCZ*',
            attr_seq => [
                qw/service_type message_id source_addr_ton source_addr_npi source_addr dest_addr_ton dest_addr_npi destination_addr/
            ],
        },
        cancel_sm_resp => {
            id       => 0x80000008,
            template => q{},
            attr_seq => [],
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
        outbind => {
            id       => 0x0000000b,
            template => 'Z*Z*',
            attr_seq => [qw/system_id password/],
        },
        enquire_link => {
            id       => 0x00000015,
            template => q{},
            attr_seq => [],
        },
        enquire_link_resp => {
            id       => 0x80000015,
            template => q{},
            attr_seq => [],
        },
        submit_multi => {
            id => 0x00000021,

            # TODO: non-trivial parsing
        },
        submit_multi_resp => {
            id => 0x80000021,

            # TODO: non-trivial parsing
        },
        alert_notification => {
            id       => 0x00000102,
            template => 'CCZ*CCZ*',
            attr_seq => [qw/source_addr_ton source_addr_npi source_addr esme_addr_ton esme_addr_npi esme_addr/],
        },
        data_sm => {
            id       => 0x00000103,
            template => 'Z*CCZ*CCZ*CCC',
            attr_seq => [
                qw/service_type source_addr_ton source_addr_npi source_addr dest_addr_ton dest_addr_npi destination_addr esm_class registered_delivery data_coding/
            ],
        },
        data_sm_resp => {
            id       => 0x80000103,
            template => 'Z*',
            attr_seq => [qw/message_id/],
        },
    },
};

my %default = (
    version           => 0x34,
    system_id         => q{},     # 5.2.1, usually needs to be supplied
    password          => q{},     # 5.2.2
    system_type       => q{},     # 5.2.3, often optional, leave empty
    interface_version => 0x34,    # 5.2.4
    addr_ton          => 0x00,    # 5.2.5  type of number
    addr_npi          => 0x00,    # 5.2.6  numbering plan indicator
    address_range     => q{},     # 5.2.7  regular expression matching numbers

    ### Default values for submit_sm and deliver_sm
    service_type            => q{},     # NULL: SMSC defaults, #4> on v4 this is message_class <4#
    source_addr_ton         => 0x00,    #? not known, see sec 5.2.5
    source_addr_npi         => 0x00,    #? not known, see sec 5.2.6
    source_addr             => q{},     ## NULL: not known. You should set this for reply to work.
    dest_addr_ton           => 0x00,    #??
    dest_addr_npi           => 0x00,    #??
    destination_addr        => q{},     ### Destination address must be supplied
    esm_class               => 0x00,    # Default mode (store and forward) and type (5.2.12, p.121)
    protocol_id             => 0x00,    ### 0 works for TDMA & CDMA, for GSM set according to GSM 03.40
    priority_flag           => 0,       # non-priority/bulk/normal
    schedule_delivery_time  => q{},     # NULL: immediate delivery
    validity_period         => q{},     # NULL: SMSC default validity period
    registered_delivery     => 0x00,    # no receipt, no ack, no intermed notif
    replace_if_present_flag => 0,       # no replacement
    data_coding             => 0,       # SMSC default alphabet
    sm_default_msg_id       => 0,       # Do not use canned message

    ### default values for alert_notification
    esme_addr_ton => 0x00,
    esme_addr_npi => 0x00,

    ### default values for query_sm_resp
    final_date => q{},                  # NULL: message has not yet reached final state
    error_code => 0,                    # no error

);

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

    my @header_attr   = qw/version command status seq/;
    my $body_attr_ref = $body_dict->{ $data_ref->{'version'} }->{ $data_ref->{'command'} }->{'attr_seq'};
    my @missing_attr;
    foreach my $mandatory_field ( @header_attr, @{$body_attr_ref} ) {
        next if exists $data_ref->{$mandatory_field};
        next if $mandatory_field eq 'sm_length';
        if ( exists $default{$mandatory_field} ) {
            $data_ref->{$mandatory_field} = $default{$mandatory_field};
        }
        else {
            push @missing_attr, $mandatory_field;
        }
    }
    if ( scalar @missing_attr > 0 ) {
        warn 'following mandatory fields are missing: ' . join( ', ', @missing_attr ) . "\n";
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

    if ( first { $_ eq 'short_message' } @{$attr_seq} ) {
        $data_ref->{'sm_length'} = length $data_ref->{'short_message'};
        $template .= 'a*';
    }
    if ( !defined $template ) {
        warn "Unknown command: $data_ref->{'command'}\n";
        return q{};
    }
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
    my $template = $body_dict->{ $data_ref->{'version'} }->{ $pdu{'command'} }->{'template'};
    my $attr_seq = $body_dict->{ $data_ref->{'version'} }->{ $pdu{'command'} }->{'attr_seq'};
    if ( !defined $template ) {
        warn "Unknown command: $pdu{'command'}\n";
        return \%pdu;
    }

    my $body_str = substr $data_ref->{'data'}, $head_len;
    my @options = unpack $template, $body_str;

    my $body_len = 0;
    foreach my $idx ( 0 .. $#{$attr_seq} ) {
        my $attr_name = ${$attr_seq}[$idx];
        next if $attr_name eq 'short_message';
        $pdu{$attr_name} = $options[$idx];

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
    my ($hex_str) = @_;
    local ( $!, $@ ) = ( $!, $@ );
    while ( $hex_str =~ /(.{1,32})/smg ) {
        my $line = $1;
        my @c = ( ( map { sprintf '%02x', $_ } unpack 'C*', $line ), ( (q{  }) x 32 ) )[ 0 .. 31 ];
        $line =~ s/(.)/ my $c=$1; unpack("c",$c)>=32 ? $c : '.' /egms;
        warn join( q{ }, @c, q{|}, $line ), "\n";
    }
    warn "\n";

    return;
}

1;
