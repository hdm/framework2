#!/usr/bin/perl
###############

##
#         Name: Socket.pm
#       Author: spoonm <ninjatools [at] hush.com>
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
our @EXPORT;
our @EXPORT_OK;

my $SSL_SUPPORT;

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
}


sub new {
  my $class = shift;
  my $self = bless({ }, $class);

  my $hash = shift;
  $self->SetOptions($hash);
  $self->SetConnectTimeout(30) if(!exists($hash->{'ConnectTimeout'}));
  $self->SetRecvTimeout(10) if(!exists($hash->{'RecvTimeout'}));
  $self->SetRecvTimeoutLoop(.5) if(!exists($hash->{'RecvTimeoutLoop'}));
  $self->Init;
  return($self);
}

sub Init {
  my $self = shift;
  return;
}

sub SetOptions {
  my $self = shift;
  my $hash = shift;

  if(exists($hash->{'UseSSL'})) {
    my $use = $hash->{'UseSSL'};
    if($SSL_SUPPORT == 0 && $use) {
      $self->SetError('UseSSL option is set, but Net::SSLeay has not been installed.');
      return;
    }
    $self->UseSSL($use);
  }
  
  if(exists($hash->{'Timeout'})) {
    $self->SetTimeout($hash->{'Timeout'});
  }
  
  if(exists($hash->{'SpoofIP'})) {
    $self->SetSpoofIP($hash->{'SpoofIP'});
  }  
  
  return;
}

sub UseSSL {
  my $self = shift;
  $self->{'UseSSL'} = shift if(@_);
  return($self->{'UseSSL'});
}

sub GetProxies {
  my $self = shift;
  return($self->{'Proxies'});
}

sub AddProxy {
  my $self = shift;
  my ($type, $addr, $port) = @_;

  if (! defined($type) || ! defined($addr) || ! defined($port))
  {
    $self->SetError('Invalid proxy value specified');
    return;
  }

  if ($type eq 'http')
  {
    push @{$self->{'Proxies'}}, [ $type, $addr, $port ];
    return(1);
  }
  
  if ($type eq 'socks4')
  {
    push @{$self->{'Proxies'}}, [ $type, $addr, $port ];
    return(1);
  }
  
  $self->SetError('Invalid proxy type specified');
  return;
}

sub SetSpoofIP {
    my $self = shift;
    $self->{'SpoofIP'} = shift;
}

sub GetSpoofIP {
    my $self = shift;
    return($self->{'SpoofIP'});
}

sub SetConnectTimeout {
  my $self = shift;
  my $timeout = shift;
  $self->{'ConnectTimeout'} = $timeout;
}
sub GetConnectTimeout {
  my $self = shift;
  return($self->{'ConnectTimeout'});
}

sub SetRecvTimeout {
  my $self = shift;
  my $timeout = shift;
  $self->{'RecvTimeout'} = $timeout;
}
sub GetRecvTimeout {
  my $self = shift;
  return($self->{'RecvTimeout'});
}

sub SetRecvTimeoutLoop {
  my $self = shift;
  my $timeout = shift;
  $self->{'RecvTimeoutLoop'} = $timeout;
}
sub GetRecvTimeoutLoop {
  my $self = shift;
  return($self->{'RecvTimeoutLoop'});
}

sub SetError {
  my $self = shift;
  my $error = shift;
  $self->{'Error'} = $error;
}

sub GetError {
  my $self = shift;
  return($self->{'Error'});
}

sub GetSocket {
  my $self = shift;
  return($self->{'Socket'});
}

sub SetBuffer {
  my $self = shift;
  my $buffer = shift;
  $self->{'Buffer'} = $buffer;
}
sub AddBuffer {
  my $self = shift;
  my $buffer = shift;
  $self->{'Buffer'} .= $buffer;
}
sub GetBuffer {
  my $self = shift;
  my $size = @_ ? shift : 999999999;

  return(substr($self->{'Buffer'}, 0, $size));
}

sub RemoveBuffer {
  my $self = shift;
  my $size = @_ ? shift : 999999999;

  return(substr($self->{'Buffer'}, 0, $size, ''));
}

sub SocketError {
  my $self = shift;
  my $ignoreConn = shift;

  my $reason;
  if(!$self->GetSocket) {
    $reason = 'no socket';
  }
  elsif(!$ignoreConn && !$self->GetSocket->connected) {
    $reason = 'not connected';
  }

  if($reason) {
    $self->SetError('Invalid socket: ' . $reason);
    return(1);
  }

  return(0);
}

sub Close {
  my $self = shift;
  if($self->GetSocket) {
    if($self->UseSSL) {
      Net::SSLeay::Free($self->{'SSLFd'});
      Net::SSLeay::CTX_free($self->{'SSLCtx'});
    }
    $self->GetSocket->close;
  }
}

sub TcpConnectSocket {
  my $self = shift;
  my $host = shift;
  my $port = shift;
  my $localPort = shift;

  my $proxies = $self->GetProxies;
  if($localPort && $proxies) {
    $self->SetError('A local port was specified and proxies are enabled, they are mutually exclusive.');
    return;
  }

  my $sock;
  if($proxies) {
    $sock = $self->ConnectProxies($host, $port);
    return if(!$sock);
  } 
  else {
    my %config = (
      'PeerAddr'  => $host,
      'PeerPort'  => $port,
      'Proto'     => 'tcp',
      'ReuseAddr' => 1,
      'Timeout'   => $self->GetConnectTimeout,
    );
    $config{'LocalPort'} = $localPort if($localPort);
    $sock = IO::Socket::INET->new(%config);  
 
    if(!$sock || !$sock->connected) {
      $self->SetError('Connection failed: ' . $!);
      return;
    }
  }

  return($sock);
}

sub Tcp {
  my $self = shift;
  my $host = shift;
  my $port = shift;
  my $localPort = shift;

  return if($self->GetError);

  $self->{'Socket'} = undef;
  $self->SetError(undef);

  my $sock = $self->TcpConnectSocket($host, $port, $localPort);
  return if($self->GetError || !$sock);

  $self->{'Socket'} = $sock;


  if($self->UseSSL) {
    # Create SSL Context
    $self->{'SSLCtx'} = Net::SSLeay::CTX_new();
    # Configure session for maximum interoperability
    Net::SSLeay::CTX_set_options($self->{'SSLCtx'}, &Net::SSLeay::OP_ALL);
    # Create the SSL file descriptor
    $self->{'SSLFd'}  = Net::SSLeay::new($self->{'SSLCtx'});
    # Bind the SSL descriptor to the socket
    Net::SSLeay::set_fd($self->{'SSLFd'}, $sock->fileno);        
    # Negotiate connection
    my $sslConn = Net::SSLeay::connect($self->{'SSLFd'});

    if($sslConn <= 0) {
      $self->SetError('Error setting up ssl: ' . Net::SSLeay::print_errs());
      $self->close;
      return;
    }
  }

  # we have to wait until after the SSL negotiation before 
  # setting the socket to non-blocking mode

  $sock->blocking(0);
  $sock->autoflush(1);

  return($sock->fileno);
}

sub Udp {
  my $self = shift;
  my $host = shift;
  my $port = shift;
  my $localPort = shift;

  return if($self->GetError);

  my %config = (
    'PeerAddr'   => $host,
    'PeerPort'   => $port,
    'Proto'      => 'udp',
    'ReuseAddr'  => 1,
  );

  $config{'LocalPort'} = $localPort if($localPort);
  $config{'Broadcast'} = 1 if($host =~ /\.255$/);

  my $sock = IO::Socket::INET->new(%config);

  if(!$sock) {
    $self->SetError('Socket failed: ' . $!);
    return;
  }

  $sock->blocking(0);
  $sock->autoflush(1);

  # Disable SSL
  $self->UseSSL(0);
  $self->{'Socket'} = $sock;
  return($sock->fileno);
}

sub Send {
  my $self = shift;
  my $data = shift;
  my $delay = @_ ? shift : .1;

  return if($self->GetError);

  my $failed = 5;
  while(length($data)) {
    return if($self->SocketError);

    my $sent;
    if($self->UseSSL) {
      $sent = Net::SSLeay::ssl_write_all($self->{'SSLFd'}, $data);
    }
    else {
      $sent = $self->GetSocket->send($data);
    }

    last if($sent == length($data));

    $data = substr($data, $sent);
    if(!--$failed) {
      $self->SetError("Write retry limit reached.");
      return(0);
    }
    select(undef, undef, undef, $delay); # sleep
  }
  return(1);
}


sub Recv {
  my $self = shift;
  my $length = shift;
  my $timeout = @_ ? shift : $self->GetRecvTimeout;

  return if($self->GetError);
  return if($self->SocketError(1));

  # Try to get any data out of our own buffer first
  my $data = $self->RemoveBuffer($length);

  my $selector = IO::Select->new($self->GetSocket);

  my $sslEmptyRead = 5;

  # Special case -1 lengths, we will wait up to timeout to get
  # any data, and then we just read as much as we can, and return.
  if($length == -1) {
    my ($ready) = $selector->can_read($timeout);

    if(!$ready) {
      # $self->SetError("Timeout $timeout reached."); # could be data from buffer anyway
      return($data);
    }

    my $timeoutLoop = $self->GetRecvTimeoutLoop;
    while(1) {
      my ($ready) = $selector->can_read($timeoutLoop);
      last if(!$ready);

      my $tempData;

      if($self->UseSSL) {
        $tempData = $self->SSLRead;
        if(!length($tempData)) {
          $self->SetError('Dry ssl read.');
        }
      }
      else {
        $self->GetSocket->recv($tempData, 4096);
      }

      last if(!length($tempData));
      $data .= $tempData;   
    }
    return($data);
  }


  $length -= length($data);

  while($length) {
    my ($ready) = $selector->can_read($timeout);

    if(!$ready) {
      # $self->SetError("Timeout $timeout reached.");
      $self->SetError("Socket disconnected.") if(!$self->GetSocket->connected);
      return($data);
    }

    # We gotz data y0
    my $tempData;
    if($self->UseSSL) {
      # Using select() with SSL is tricky, even though the socket
      # may have data, the SSL session may not. There isn't really
      # a clean way around this, so we just try until we get two
      # empty reads in a row or we time out
      
      $tempData = $self->SSLRead;
      if(!length($tempData)) {
        if($timeout) {
          $self->SetError('Dry ssl read, out of tries');
          return($data);
        }
        next;
      }
    }
    else {
      $self->GetSocket->recv($tempData, $length);
      if(!length($tempData)) {
        $self->SetError('Socket is dead.');
        return($data);
      }
    }

    $data .= $tempData;
    if(length($tempData) > $length) {
      $self->AddBuffer(substr($tempData, $length));
      $tempData = substr($tempData, 0, $length);
    }
    $length -= length($tempData);
  }

  return($data);
}

# This should be called when we know the socket has data waiting for us.
# We try to ssl read, if there is data return, we return with it, otherwise
# we loop for several tries waiting for ssl data
sub SSLRead {
  my $self = shift;
  my $sslEmptyRead = 5;

  while(1) {
    my $data = Net::SSLeay::read($self->{'SSLFd'});
    if(!length($data)) {
      if(!--$sslEmptyRead) {
        return;
      }
      select(undef, undef, undef, .1);
    }
    else {
      return($data);
    }
  }
}

sub ConnectProxies {
    my $self = shift;
    my ($host, $port) = @_;
    my @proxies = @{$self->GetProxies};
    my ($base, $sock);

    $base = shift(@proxies);
    push @proxies, ['final', $host, $port];
    
    $sock = IO::Socket::INET->new (
        'PeerAddr'  => $base->[1],
        'PeerPort'  => $base->[2],
        'Proto'     => 'tcp',
        'ReuseAddr' => 1,
        'Timeout'   => $self->GetConnectTimeout,
    );
    if (! $sock || ! $sock->connected)
    {
        $self->SetError("Proxy server type $base->[0] at $base->[1] failed connection: $!");
        return;
    }
    
    my $proxyloop = 0;
    my $lastproxy = $base;
    foreach my $proxy (@proxies)  
    {
        $proxyloop++;
        
        if ($lastproxy->[0] eq 'http') {
            my $res = $sock->send("CONNECT ".$proxy->[1].":".$proxy->[2]." HTTP/1.0\r\n\r\n");
        }
        
        if ($lastproxy->[0] eq 'socks4') {
            $sock->send("\x04\x01".pack('n',$proxy->[2]).gethostbyname($proxy->[1])."\x00");
            $sock->recv(my $res, 8);
            if (! $res || ($res && ord(substr($res,1,1)) != 90)) {
                $self->SetError("Socks4 proxy at $lastproxy->[1]:$lastproxy->[2] failed to connect to ".join(":",@{$proxy}));
                $sock->close;
                return;
            }
        }
        
        # wait 0.25 second for each proxy already in chain
        select(undef, undef, undef, 0.25 * $proxyloop);
        
        if (! $sock->connected) {
            $self->SetError("Proxy type $lastproxy->[0] at $lastproxy->[1] closed connection");
            return;
        }
        
        last if $proxy->[0] eq 'final';
        $lastproxy = $proxy;
    }
    return $sock;
}
1;
