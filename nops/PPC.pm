package Msf::Nop::PPC;
use strict;
use base 'Msf::Nop';
use Pex::Utils;

my $info = {
  'Name'    => 'PPC Nop Generator',
  'Version' => '1.0',
  'Authors' => [ 'H D Moore <hdm [at] metasploit.com> [Artistic License]', ],
  'Arch'    => [ 'ppc' ],
  'Desc'    =>  'Pex Nop Generator',
  'Refs'    => [ ],
};

my $advanced = { };

sub new {
  my $class = shift; 
  return($class->SUPER::new({'Info' => $info, 'Advanced' => $advanced}, @_));
}

sub Nops {
  my $self = shift;
  my $length = shift;

  my $exploit = $self->GetVar('_Exploit');
  my $random  = $self->GetLocal('RandomNops');
  my $badRegs = $exploit->NopBadRegs;
  my $badChars = $exploit->PayloadBadChars;

  return(pack('N',0x60606060) x ($length / 4));
  
}

1;