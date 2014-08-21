use strict;
use warnings;
use Test::More tests => 45;
use Test::Exception;
use File::Temp qw/tempdir/;
use File::Slurp;

use_ok('wtsi_clarity::epp::stamp');

{
  my $s = wtsi_clarity::epp::stamp->new(process_url => 'some', step_url => 'some');
  isa_ok($s, 'wtsi_clarity::epp::stamp');
}

{
  local $ENV{'WTSICLARITY_WEBCACHE_DIR'} = 't/data/stamp';
  #local $ENV{'SAVE2WTSICLARITY_WEBCACHE'} = 1;
  my $s = wtsi_clarity::epp::stamp->new(
              process_url => 'http://clarity-ap:8080/api/v2/processes/24-98502',
              step_url => 'some');
  lives_ok { $s->_analytes } 'got all info from clarity';
  my @containers = keys %{$s->_analytes};
  is (scalar @containers, 1, 'one input container');
  is (scalar keys %{$s->_analytes->{$containers[0]}}, 6, 'five input analytes and a container doc');

  is ($s->container_type_name->[0], 'ABgene 0800', 'container name retrieved correctly');
  is ($s->_validate_container_type, 0, 'container type validation flag unset');
  is ($s->_container_type->[0],
     '<type uri="http://clarity-ap.internal.sanger.ac.uk:8080/api/v2/containertypes/105" name="ABgene 0800"/>',
     'container type value');

  delete $s->_analytes->{$containers[0]}->{'doc'};
  my @wells = sort map { $s->_analytes->{$containers[0]}->{$_}->{'well'} } (keys %{$s->_analytes->{$containers[0]}});
  is (join(q[ ], @wells), 'B:11 D:11 E:11 G:9 H:9', 'sorted wells');

}

{
  SKIP: {
    if ( !$ENV{'LIVE_TEST'}) {
      skip 'set LIVE_TEST to true to run', 8;
    }

    local $ENV{'WTSICLARITY_WEBCACHE_DIR'} = 't/data/stamp';
    my $s = wtsi_clarity::epp::stamp->new(
      process_url => 'http://clarity-ap.internal.sanger.ac.uk:8080/api/v2/processes/24-98502',
      step_url    => 'some'
    );
    lives_ok { $s->_analytes } 'got all info from clarity';
    is ($s->container_type_name->[0], 'ABgene 0800', 'container name retrieved correctly');
    is ($s->_validate_container_type, 0, 'container type validation flag unset');
    is ($s->_container_type->[0],
       '<type uri="http://clarity-ap.internal.sanger.ac.uk:8080/api/v2/containertypes/105" name="ABgene 0800"/>',
       'container type value');

    local $ENV{'WTSICLARITY_WEBCACHE_DIR'} = q[];
    lives_ok { $s->_create_containers } 'containers created';
    my @container_urls = keys %{$s->_analytes};
    my $ocon = $s->_analytes->{$container_urls[0]}->{'output_containers'};
    ok ($ocon->[0], 'output container entry exists');
    like($ocon->[0]->{'limsid'}, qr/27-/, 'container limsid is set');
    like ($ocon->[0]->{'uri'}, qr/containers\/27-/, 'container uri is set');
  }
}

{
  local $ENV{'WTSICLARITY_WEBCACHE_DIR'} = 't/data/stamp';
  my $s = wtsi_clarity::epp::stamp->new(
    process_url => 'http://clarity-ap:8080/api/v2/processes/24-98502',
    step_url    => 'some'
  );
  lives_ok { $s->_analytes } 'got all info from clarity';

  my @container_urls = keys %{$s->_analytes};
  my $climsid = '27-4536';
  my $curi = 'http://c.com/containers/' . $climsid;
  $s->_analytes->{$container_urls[0]}->{'output_container'}->{'limsid'} = $climsid;
  $s->_analytes->{$container_urls[0]}->{'output_container'}->{'uri'} = $curi;

  my $doc;
  lives_ok { $doc = $s->_create_placements_doc } 'placement doc created';
  lives_ok { $s->_direct_stamp($doc) } 'individual placements created';
}

{
  local $ENV{'WTSICLARITY_WEBCACHE_DIR'} = 't/data/stamp_with_control';
  my $s = wtsi_clarity::epp::stamp->new(
              process_url => 'http://clarity-ap:8080/api/v2/processes/24-99904',
              step_url => 'some');
  lives_ok { $s->_analytes } 'got all info from clarity';
  my @containers = keys %{$s->_analytes};
  is (scalar @containers, 1, 'one input container, control tube is skipped');
}

{
  local $ENV{'WTSICLARITY_WEBCACHE_DIR'} = 't/data/stamp_with_control';
  #local $ENV{'SAVE2WTSICLARITY_WEBCACHE'} = 1;
  my $s = wtsi_clarity::epp::stamp->new(
              process_url => 'http://clarity-ap:8080/api/v2/processes/24-99904',
              step_url => 'some',
              container_type_name => ['ABgene 0800']);
  lives_ok { $s->_analytes } 'got all info from clarity';
  my @containers = keys %{$s->_analytes};
  is (scalar @containers, 1, 'one input container, control tube is skipped');
  ok ($s->_validate_container_type, 'validate container flag is true');
  is ($s->_container_type->[0],
      '<type uri="http://clarity-ap.internal.sanger.ac.uk:8080/api/v2/containertypes/105" name="ABgene 0800"/>',
      'container type derived correctly from name');
}

{
  local $ENV{'WTSICLARITY_WEBCACHE_DIR'} = 't/data/stamp_with_control';
  my $s = wtsi_clarity::epp::stamp->new(
              process_url => 'http://clarity-ap:8080/api/v2/processes/24-99904',
              step_url => 'some',
              container_type_name => ['ABgene 0765', 'ABgene 0800']);

  lives_ok { $s->_analytes } 'got all info from clarity';
  my @containers = keys %{$s->_analytes};
  is (scalar @containers, 1, 'one input container, control tube is skipped');
  is (scalar(map { $_ =~ /\Ahttp/ } keys %{$s->_analytes->{$containers[0]}}), 4, 'control will not be stamped');

  ok ($s->_validate_container_type, 'validate container flag is true');
  is (scalar @{$s->_container_type}, 2, 'two container types retrieved');
  is ($s->_container_type->[0],
      '<type uri="http://clarity-ap.internal.sanger.ac.uk:8080/api/v2/containertypes/106" name="ABgene 0765"/>',
      'first container type derived correctly from name');
  is ($s->_container_type->[1],
      '<type uri="http://clarity-ap.internal.sanger.ac.uk:8080/api/v2/containertypes/105" name="ABgene 0800"/>',
      'second container type derived correctly from name');

}

{
  my $dir = tempdir(CLEANUP => 1);
  `cp -R t/data/stamp_with_control $dir`;
   #remove tube container from test data
  `rm $dir/stamp_with_control/GET/containers/27-7555`;
  my $control = "$dir/stamp_with_control/GET/artifacts/151C-801PA1?state=359614";
  my $control_xml = read_file $control;
  $control_xml =~ s/27-7555/27-7103/g;  #place control on the input plate
  $control_xml =~ s/1:1/H:12/g;         #in well H:12
  open my $fh, '>', $control or die "cannot open filehandle to write to $control";
  print $fh $control_xml or die "cannot write to $control";
  close $fh;

  local $ENV{'WTSICLARITY_WEBCACHE_DIR'} = "$dir/stamp_with_control";
  my $s = wtsi_clarity::epp::stamp->new(
              process_url => 'http://clarity-ap:8080/api/v2/processes/24-99904',
              step_url => 'some');
  lives_ok { $s->_analytes } 'got all info from clarity';
  my @containers = keys %{$s->_analytes};
  is (scalar @containers, 1, 'one input container');
  is (scalar(map { $_ =~ /\Ahttp/ } keys %{$s->_analytes->{$containers[0]}}), 5,
    'control will be stamped');
}

{
  local $ENV{'WTSICLARITY_WEBCACHE_DIR'} = 't/data/stamp';
  my $s = wtsi_clarity::epp::stamp->new(
            process_url => 'http://clarity-ap:8080/api/v2/processes/24-16122',
            step_url => 'some',
          );

  my $climsid = '27-4536';
  my $curi = 'http://c.com/containers/' . $climsid;
  my $h = {
    'limsid' => $climsid,
    'uri'    => $curi,
  };
  foreach my $analyte (keys %{$s->_analytes}) {
    push @{$s->_analytes->{$analyte}->{'output_containers'}}, $h;
  }

  my $doc;
  my $output_placements;
  lives_ok { $doc = $s->_create_placements_doc } 'Can create placements doc';
  lives_ok { $output_placements = $s->_stamp_with_copy($doc) } 'Can create placements';
}

{

  my $s = wtsi_clarity::epp::stamp->new(
            process_url => 'http://clarity-ap:8080/api/v2/processes/24-16122',
            step_url => 'some',
            copy_on_target => 0
          );

  my ($well1, $well2) = $s->_calculate_destination_wells('A:1');
  is($well1, 'A:1', 'The first well is A:1');
  is($well2, 'B:1', 'The second well is B:1');

  my ($well3, $well4) = $s->_calculate_destination_wells('B:1');
  is($well3, 'C:1', 'The first well is C:1');
  is($well4, 'D:1', 'The second well is D:1');

  my ($well5, $well6) = $s->_calculate_destination_wells('A:2');
  is($well5, 'A:3', 'The first well is A:3');
  is($well6, 'B:3', 'The second well is B:3');

  throws_ok { $s->_calculate_destination_wells('I:1') } qr/Source plate must be a 96 well plate/,
    'Only accepts 96 well plates';
}

1;
