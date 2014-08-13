package wtsi_clarity::util::sequencescape_request_role;

use Moose::Role;

use wtsi_clarity::util::request;

our $VERSION = '0.0';


has 'ss_request' => (
  isa => 'wtsi_clarity::util::request',
  is  => 'ro',
  required => 0,
  lazy_build => 1,
);
sub _build_ss_request {
  my $self = shift;

  return wtsi_clarity::util::request->new(
    'content_type'        => 'application/json',
    'additional_headers'  => $self->_get_additional_headers,
  );
}

=head2 _get_additional_headers

This additional header needed for communicating with Sequencescape's web service.

=cut

sub _get_additional_headers {
  my $self = shift;

  my $ss_client_id = $self->config->tag_plate_validation->{'ss_client_id'};

  return  { 'X-Sequencescape-Client-ID' => $ss_client_id,
            'Cookie'                    => 'api_key='
          }
}

1;

__END__

=head1 NAME

wtsi_clarity::util::sequencescape_request_role

=head1 SYNOPSIS

  with 'wtsi_clarity::util::sequencescape_request_role';

=head1 DESCRIPTION

  This role contains a special request object to use with Sequencescape related request.

=head1 SUBROUTINES/METHODS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item Readonly

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