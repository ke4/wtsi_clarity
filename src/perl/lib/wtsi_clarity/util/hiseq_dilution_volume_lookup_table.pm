package wtsi_clarity::util::hiseq_dilution_volume_lookup_table;

use Moose;
use Readonly;
use Carp;

our $VERSION = '0.0';

Readonly::Hash  my %VOLUME_LOOKUP_TABLE  => {
                          3.3   =>  4.2,
                          3.4   =>  4.1,
                          3.5   =>  4,
                          3.6   =>  3.9,
                          3.7   =>  3.8,
                          3.8   =>  3.7,
                          3.9   =>  3.6,
                          4     =>  3.5,
                          4.1   =>  3.4,
                          4.2   =>  3.3,
                          4.3   =>  3.3,
                          4.4   =>  3.2,
                          4.5   =>  3.1,
                          4.6   =>  3,
                          4.7   =>  3,
                          4.8   =>  2.9,
                          4.9   =>  2.9,
                          5     =>  2.8,
                          5.1   =>  2.7,
                          5.2   =>  2.7,
                          5.3   =>  2.6,
                          5.4   =>  2.6,
                          5.5   =>  2.5,
                          5.6   =>  2.5,
                          5.7   =>  2.5,
                          5.8   =>  2.4,
                          5.9   =>  2.4,
                          6     =>  2.3,
                          6.1   =>  2.3,
                          6.2   =>  2.3,
                          6.3   =>  2.2,
                          6.4   =>  2.2,
                          6.5   =>  2.2,
                          6.6   =>  2.1,
                          6.7   =>  2.1,
                          6.8   =>  2,
                          6.9   =>  2,
                          7     =>  2,
                          7.1   =>  2,
                          7.2   =>  1.9,
                          7.3   =>  1.9,
                          7.4   =>  1.9,
                          7.5   =>  1.9,
};

sub getVolume {
  my ($self, $concentration) = @_;

  return $VOLUME_LOOKUP_TABLE{$concentration};
}

1;

__END__

=head1 NAME

  wtsi_clarity::util::filename

=head1 SYNOPSIS

  with 'wtsi_clarity::util::filename';

=head1 DESCRIPTION

  Utility to handle operations with a file.

=head1 SUBROUTINES/METHODS

=head2 with_uppercase_extension

  Converts a file extension to uppercase.
  
=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item Carp

=back

=head1 AUTHOR

Karoly Erdos E<lt>ke4@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2014 Genome Research Ltd.

This file is part of wtsi_clarity project.

wtsi_clarity is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

=cut
