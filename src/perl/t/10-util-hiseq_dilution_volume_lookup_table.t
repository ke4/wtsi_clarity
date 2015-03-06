use strict;
use warnings;
use Test::More tests => 8;

use_ok('wtsi_clarity::util::hiseq_dilution_volume_lookup_table');
{
  my $s = wtsi_clarity::util::hiseq_dilution_volume_lookup_table->new();
  isa_ok($s, 'wtsi_clarity::util::hiseq_dilution_volume_lookup_table');
  my @inputs = map "TEST" . $_, 1..96;
  is($s->getVolume(3.3), 4.2, 'Returns the correct volume.');
  is($s->getVolume(4), 3.5, 'Returns the correct volume.');
  is($s->getVolume(6), 2.3, 'Returns the correct volume.');
  is($s->getVolume(7.5), 1.9, 'Returns the correct volume.');
  is($s->getVolume(7.6), '', 'Returns an empty string when not in range.');
  is($s->getVolume(3.0), '', 'Returns an empty string when not in range.');
}

1;
