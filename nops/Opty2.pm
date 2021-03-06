
##
# This file is part of the Metasploit Framework and may be redistributed
# according to the licenses defined in the Authors field below. In the
# case of an unknown or missing license, this file defaults to the same
# license as the core Framework (dual GPLv2 and Artistic). The latest
# version of the Framework can always be obtained from metasploit.com.
##

package Msf::Nop::Opty2;
use strict;
use base 'Msf::Nop::OptyNop2';
use Pex::x86;

my $info = {
  'Name'    => 'Optyx uber nop generator',
  'Version' => '$Revision$',
  'Authors' => [ 'spoonm <ninjatools [at] hush.com>', ],
  'Arch'    => [ 'x86' ],
  'Desc'    => 'Variable instruction length nop generator',
  'Refs'    => [ ],
};

my $advanced = {
  'RandomNops' => [0, 'Use random nop equivalent instructions, otherwise default to 0x90'],

};

sub new {
  my $class = shift; 
  return($class->SUPER::new({'Info' => $info, 'Advanced' => $advanced}, @_));
}

sub Nops {
  my $self = shift;
  my $length = shift;

  my $exploit = $self->GetVar('_Exploit');
  my $random  = $self->GetVar('RandomNops');
  my $badChars = $exploit->PayloadBadChars;

  my $badRegs = [ ];
  foreach my $breg (@{$exploit->NopSaveRegs}) {
    push(@{$badRegs}, Pex::x86::RegNameToNumber($breg));
  }
  $self->_BadRegs($badRegs);
  $self->_BadChars($badChars);

  return($self->_GenerateSled($length));
}

sub _BadRegs {
  my $self = shift;
  $self->{'_BadRegs'} = shift if(@_);
  return($self->{'_BadRegs'});
}
sub _BadChars {
  my $self = shift;
  $self->{'_BadChars'} = shift if(@_);
  return($self->{'_BadChars'});
}

1;
