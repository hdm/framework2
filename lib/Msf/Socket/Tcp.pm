#!/usr/bin/perl
###############

##
#         Name: Socket.pm
#       Author: spoonm <ninjatools [at] hush.com>
#      Version: $Revision$
#  Description: Socket wrapper around Pex::Socket.
#      License:
#
#      This file is part of the Metasploit Exploit Framework
#      and is subject to the same licenses and copyrights as
#      the rest of this package.
#
##

package Msf::Socket::Tcp;
$VERSION = 2.0;
use strict;
use base 'Msf::Socket::TcpBase', 'Pex::Socket::Tcp', 'Msf::Module';

sub _UnitTest {
  my $class = shift;
  $class->SUPER::_UnitTest;
}

1;
