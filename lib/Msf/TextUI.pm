package Msf::TextUI;
use strict;
use base 'Msf::UI';
use Msf::ColPrint;

sub new {
  my $class = shift;
  my $self = $class->SUPER::new(@_);
  return($self);
}

sub WordWrap {
  my $self = shift;
  my $text = shift;
  my $indent = @_ ? shift : 4;
  my $size = @_ ? shift : 60;
  my $indent = " " x $indent;
  $text =~ s/(?:^|\G\n?)(?:(.{1,$size})(?:\s|\n|$)|(\S{$size})|\n)/$1$2\n/sg;
  $text =~ s/\n/\n$indent/g;
  return($text);
}

sub DumpExploits {
  my $self = shift;
  my $indent = shift;
  my $exploits = shift;
  my $count = 0;
  my $col = Msf::ColPrint->new($indent, 2);
  foreach my $key (sort(keys(%{$exploits}))) {
    $col->AddRow($key, $exploits->{$key}->Name);
  }
  return($col->GetOutput);
}

sub DumpPayloads {
  my $self = shift;
  my $indent = shift;
  my $payloads = shift;
  my $col = Msf::ColPrint->new(2, 4);
  foreach my $key (sort(keys(%{$payloads}))) {
    $col->AddRow($key,
        $payloads->{$key}->Description);
  }
  return($col->GetOutput);
}

sub DumpOptions {
  my $self = shift;
  my $indent = shift;
  my $col = Msf::ColPrint->new($indent, 4);
  while(@_) {
    my $type = shift;
    my $selfect = shift;
    my $options = $selfect->UserOpts || { };
    $col->AddRow($type . ':', 'Name', 'Default', 'Description');
    $col->AddRow('__hr__', '__hr__', '__hr__', '__hr__');
    foreach my $opt (keys(%{$options}))
    {
        $col->AddRow($options->{$opt}->[0] ? "required" : "optional",
            $opt, $selfect->GetVar($opt), $options->{$opt}->[2]);
    }
    $col->AddRow;
  }
  return($col->GetOutput);
}

sub DumpAdvancedOptions {
  my $self = shift;
  my $indent = shift;
  $indent = " " x $indent;
  my $output;
  while(@_) {
    my $type = shift;
    my $selfect = shift;
    my $options = $selfect->Advanced || { };
    $output .= "${indent}$type:\n${indent}" . ('-' x (length($type) + 1)) . "\n";
    foreach my $opt (keys(%{$options})) {
      $output .= "${indent}Name:     $opt\n${indent}Default:  " . $selfect->GetVar($opt) . "\n";
      $output .= "\n${indent}" . $self->WordWrap($options->{$opt}->[1], 2, 60);
      $output .= "\n\n";
    }
    $output .= "\n" if(@_);
  }
  return($output);
}

sub DumpExploitSummary {
  my $self = shift;
  my $exploit = shift;
  my $output;
  $output .=   '      Name: ' . $exploit->Name . "\n";
  $output .=   '   Version: ' . $exploit->Version . "\n";
  $output .=   ' Target OS: ' . join(", ", @{$exploit->OS}) . "\n";
  $output .=   'Privileged: ' . ($exploit->Priv ? "Yes" : "No") . "\n";
  $output .=   "\n";
  
  $output .=   "Provided By:\n";
  $output .=   "    " . $exploit->Author . "\n\n";
  
  $output .=   "Available Targets:\n";
  foreach ($exploit->Targets) { $output .= "    " . $_ . "\n" }
  
  $output .= "\n";
  $output .= "Available Options:\n";

  print $self->DumpOptions(4, 'Exploit', $exploit);

  if ($exploit->Payload) {
    $output .= "\n";
    $output .= "Payload Information:\n";
    $output .= "     Size: " . $exploit->Payload->{'Size'} . "\n";
    $output .= "    Avoid: " . scalar(split(//, $exploit->Payload->{'BadChars'})) . " characters\n";
  }

  my $desc = $self->WordWrap($exploit->Description, 4, 60);
  $output .= "\n";
  $output .= "Description:\n    $desc\n";
  
  $output .= "References:\n";
  foreach (@{$exploit->Refs}) { $output .= "    " . $_ . "\n" }
  return($output);
}

1;
