#!/usr/bin/perl
###############

##
#         Name: Socket.pm
#       Author: H D Moore <hdm [at] metasploit.com>
#      Version: $Revision$
#      License:
#
#      This file is part of the Metasploit Exploit Framework
#      and is subject to the same licenses and copyrights as
#      the rest of this package.
#
##

package Pex::Socket;
use strict;
use IO::Socket;
use IO::Select;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(socks_setup);
our @EXPORT_OK = qw(socks_setup);

my $SSL_SUPPORT;
my $SOCKS_SUPPORT;

my %_socks_config = (
    enable => 0,
    host => '127.0.0.1',
    port => 8888,
    version => 4,
);

# Determine if SSL support is enabled
BEGIN
{
    if (eval "require Net::SSLeay")
    {
        Net::SSLeay->import();
        Net::SSLeay::load_error_strings();
        Net::SSLeay::SSLeay_add_ssl_algorithms();
        Net::SSLeay::randomize(time() + $$);
        $SSL_SUPPORT++;
    }
    if (eval "require Net::SOCKS")
    {
        Net::SOCKS->import();
        $SOCKS_SUPPORT++;
    }
}

sub socks_setup {
    my ($key, $value) = @_;
    if ($key eq 'socks') {
        if ($value) {
            $_socks_config{'enable'} = 1;
        } else {
            $_socks_config{'enable'} = 0;
        }
    } elsif ($key eq 'socks_host') {
        $_socks_config{'host'} = $value;
    } elsif ($key eq 'socks_port') {
        $_socks_config{'port'} = $value;
    } elsif ($key eq 'socks_version') {
        $_socks_config{'version'} = $value;
    }
}

sub new
{
    my ($cls, $arg) = @_;
    my $self = bless {}, $cls;
    $self->{"USE_SSL"} = $arg->{"SSL"} ? 1 : 0;
    
    if ($SSL_SUPPORT == 0 && $self->{"USE_SSL"})
    {
        print STDERR "Pex::Socket Error: SSL option has been set but Net::SSLeay has not been installed.\n";
        return undef;
    }

    if ($SOCKS_SUPPORT == 0 && $_socks_config{'enable'} == 1) {
        print STDERR "Pex::Socket Error: SOCKS option has been set but Net::SOCKS has not been installed.\n";
        return undef;
    }
    return $self;
}

sub set_error
{
    my ($self,$error) = @_;
    my @cinf = caller(1);
    $self->{"ERROR"} = $cinf[3] . " => $error";
}


sub Error
{
    my ($self) = @_;
    return ($self->{"ERROR"});
}

sub get_error
{
    my ($self) = @_;
    return ($self->{"ERROR"});
}

sub get_socket
{
    my ($self) = @_;
    return($self->{"SOCKET"});
}

sub socket_error
{
    my ($self, $ignore_conn) = @_;
    my @cinf = caller(1);
    my $reason;
    
    $reason = "no socket"       if (! $self->{"SOCKET"} || ref($self->{"SOCKET"} ne "IO::Socket"));
    $reason = "not connected"   if (! $ignore_conn && ! $reason && ! $self->{"SOCKET"}->connected());

    if ($reason)
    {
        $self->{"ERROR"} = $cinf[3] . " => invalid socket: $reason";
        return(1);
    }
    
    return(0);
}

sub close
{
    my ($self) = @_;
    if ($self->{"SOCKET"})
    {
        if ($self->{"USE_SSL"})
        {
            Net::SSLeay::free ($self->{"SSL_FD"});
            Net::SSLeay::CTX_free($self->{"SSL_CTX"});
        }
        $self->{"SOCKET"}->close();
    }
}


sub tcp
{
    my ($self, $host, $port, $lport) = @_;
    
    delete($self->{'SOCKET'});
    delete($self->{'ERROR'});

    my $s;

    if ($_socks_config{'enable'} == 1) {
        my $sock = new Net::SOCKS(
            socks_addr => $_socks_config{'host'},
            socks_port => $_socks_config{'port'}, 
            protocol_version => $_socks_config{'version'}
        );
        $s = $sock->connect(peer_addr => $host, peer_port => $port);
        # print STDERR "Connecting through $_socks_config{'host'} and $_socks_config{'port'} to $host:$port\n";
        if (!$s) {
            $self->set_error("connection failed: $!");
            return(undef);
        }
    } else {
        my %sconfig =
        (
            PeerAddr  => $host,
            PeerPort  => $port,
            Proto     => 'tcp',
            ReuseAddr => 1,
            Type      =>, SOCK_STREAM
        );

        if ($lport) { $sconfig{LocalPort} = $lport }

        $s = IO::Socket::INET->new(%sconfig);

        if (! $s || ! $s->connected())
        {
            $self->set_error("connection failed: $!");
            return(undef);
        }

        #print "Socket: ($lport) " . join(" ", keys(%sconfig)) ."\n";
        #print STDERR $s->sockhost . ":" . $s->sockport . " -> " .
        #             $s->peerhost . ":" . $s->peerport . "\n";

    }

    if ($self->{"USE_SSL"})
    {
        # Create SSL Context
        $self->{"SSL_CTX"} = Net::SSLeay::CTX_new();

        # Configure session for maximum interoperability
        Net::SSLeay::CTX_set_options($self->{"SSL_CTX"}, &Net::SSLeay::OP_ALL);
        
        # Create the SSL file descriptor
        $self->{"SSL_FD"}  = Net::SSLeay::new($self->{"SSL_CTX"});

        # Bind the SSL descriptor to the socket
        Net::SSLeay::set_fd($self->{"SSL_FD"}, fileno($s));
        
        # Negotiate connection
        my $ssl_conn = Net::SSLeay::connect($self->{"SSL_FD"});
        if ($ssl_conn <= 0)
        {
            $self->set_error("ssl error: " . Net::SSLeay::print_errs());
            $s->close();
            return(undef);
        }
    }
    
    # we have to wait until after the SSL negotiation before 
    # setting the socket to non-blocking mode
    
    $s->blocking(0);
    $s->autoflush(1);

    $self->{"SOCKET"} = $s;
    return($s->fileno());
}

sub udp
{
    my ($self, $host, $port, $lport) = @_;

    # we support broadcast mode :)
    my $bcast = $host =~ /\.255$/ ? 1 : 0;

    $lport = 0 if ! $lport;
        
    my $s = IO::Socket::INET->new
    (
        PeerAddr  => $host,
        PeerPort  => $port,
        LocalPort => $lport,
        Proto     => "udp",
        ReuseAddr => 1,
        Type      => SOCK_DGRAM,
        Broadcast => $bcast
    );

    if (! $s)
    {
        $self->set_error("socket creation failed: $!");
        return(undef);
    }

        
    $s->blocking(0);
    $s->autoflush(1);

    # disable the SSL flag if it has been set
    delete($self->{"USE_SSL"}) if defined($self->{"USE_SSL"});

    $self->{"SOCKET"} = $s;
    return(fileno($s));
}

sub send
{
    my ($self, $data, $delay) = @_;
    my $res;

    $delay = ($delay) ? $delay : 0.1;

    my $failed = 0;
    
    while (length($data) && $res != length($data))
    {    
        return(undef) if $self->socket_error();

        if (! $self->{"USE_SSL"})
        {
            $res = syswrite($self->{"SOCKET"}, $data);
        } else {
            $res = Net::SSLeay::ssl_write_all($self->{"SSL_FD"}, $data);
        }
        
        if ($res) { $data = substr($data, $res) }
        select(undef, undef, undef, $delay);
        
        # give up after five failed socket writes
        $failed++ if ! defined($res);
        return if $failed > 5;
    }

    return($res);
}

sub recv
{
    my ($self, $timeout, $blocksz) = @_;
    my ($stime, $res, $waiting);
    
    return(undef) if $self->socket_error(1);

    $timeout = 0    if ! defined($timeout);
    $blocksz = 2048 if ! defined($blocksz);
    $blocksz = 2 if $blocksz < 2;
    
    my $sel = IO::Select->new($self->{"SOCKET"});
    
    my $ssl_empty_read = 0;
    
    $res     = "";
    $stime   = time();
    $waiting = 1;
    
    while ( $waiting == 1 )
    {
        my ($sfd) = $sel->can_read(0.3);
        my ($buf, $cnt);

        $waiting-- if ($timeout != 0 && ($stime + $timeout < time()));

        if (! $sfd && ! $self->{"SOCKET"}->connected())
        {
            $self->set_error("socket disconnected");
            $self->close();
            return(undef);
        }
        
        next if ! defined($sfd);

        if ($self->{"USE_SSL"})
        {
            # Using select() with SSL is tricky, even though the socket
            # may have data, the SSL session may not. There isn't really
            # a clean way around this, so we just try until we get two
            # empty reads in a row or we time out

            $buf = Net::SSLeay::read($self->{"SSL_FD"});
            $res .= $buf if defined($buf);  
            $ssl_empty_read++ if ! length($buf);
            $waiting-- if $ssl_empty_read == 2;
        } else {
            my $cnt = sysread($sfd, $buf, $blocksz);
            $waiting-- if ! defined($cnt);
            $waiting-- if ($cnt && $cnt < $blocksz);
                        
            if (! $cnt) { select(undef, undef, undef, 0.3) }
            
            $res .= $buf if $cnt;
        }
    }
    
    return($res);
}

1;
