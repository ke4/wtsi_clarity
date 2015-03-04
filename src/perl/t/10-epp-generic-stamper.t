use strict;
use warnings;
use Test::More tests => 158;
use Test::Exception;
use File::Temp qw/tempdir/;
use File::Slurp;

local $ENV{'WTSI_CLARITY_HOME'}= q[t/data/config];

use_ok('wtsi_clarity::epp::generic::stamper');
my $base_uri =  'http://testserver.com:1234/here' ;

{
  my $s = wtsi_clarity::epp::generic::stamper->new(process_url => 'some', step_url => 'some');
  isa_ok($s, 'wtsi_clarity::epp::generic::stamper');
}

{
  local $ENV{'WTSICLARITY_WEBCACHE_DIR'} = 't/data/epp/generic/stamper/stamp';
  #local $ENV{'SAVE2WTSICLARITY_WEBCACHE'} = 1;
  my $s = wtsi_clarity::epp::generic::stamper->new(
              process_url => 'http://testserver.com:1234/here/processes/24-98502',
              step_url => 'some');
  lives_ok { $s->_analytes } 'got all info from clarity';
  my @containers = keys %{$s->_analytes};
  is (scalar @containers, 1, 'one input container');
  is (scalar keys %{$s->_analytes->{$containers[0]}}, 6, 'five input analytes and a container doc');

  is ($s->container_type_name->[0], 'ABgene 0800', 'container name retrieved correctly');
  is ($s->_validate_container_type, 0, 'container type validation flag unset');
  is ($s->_container_type->[0],
     '<type uri="http://testserver.com:1234/here/containertypes/105" name="ABgene 0800"/>',
     'container type value');

  delete $s->_analytes->{$containers[0]}->{'doc'};
  my @wells = sort map { $s->_analytes->{$containers[0]}->{$_}->{'well'} } (keys %{$s->_analytes->{$containers[0]}});
  is (join(q[ ], @wells), 'B:11 D:11 E:11 G:9 H:9', 'sorted wells');

}

{
  local $ENV{'WTSICLARITY_WEBCACHE_DIR'} = 't/data/epp/generic/stamper/stamp';
  my $s = wtsi_clarity::epp::generic::stamper->new(
    process_url => $base_uri . '/processes/24-98502',
    step_url    => 'some'
  );
  lives_ok { $s->_analytes } 'got all info from clarity';

  my @container_urls = keys %{$s->_analytes};
  my $climsid = '27-4536';
  my $curi = 'http://c.com/containers/' . $climsid;
  $s->_analytes->{$container_urls[0]}->{'output_container'}->{'limsid'} = $climsid;
  $s->_analytes->{$container_urls[0]}->{'output_container'}->{'uri'} = $curi;

  my $doc;
  my $stamping_method_ref = \&wtsi_clarity::epp::generic::stamper::_direct_stamp;
  my $well_calc_ref = \&wtsi_clarity::epp::generic::stamper::_direct_well_calculation;
  lives_ok { $doc = $s->_create_placements_doc } 'placement doc created';
  lives_ok { $s->_stamping($doc, $stamping_method_ref, $well_calc_ref) } 'individual placements created';
}

{
  local $ENV{'WTSICLARITY_WEBCACHE_DIR'} = 't/data/epp/generic/stamper/stamp_with_control';
  my $s = wtsi_clarity::epp::generic::stamper->new(
              process_url => $base_uri . '/processes/24-99904',
              step_url => 'some');
  lives_ok { $s->_analytes } 'got all info from clarity (no container type name)';
  my @containers = keys %{$s->_analytes};
  is (scalar @containers, 2, 'one input container, control tube is included');
}

{
  local $ENV{'WTSICLARITY_WEBCACHE_DIR'} = 't/data/epp/generic/stamper/stamp_with_control';
  #local $ENV{'SAVE2WTSICLARITY_WEBCACHE'} = 1;
  my $s = wtsi_clarity::epp::generic::stamper->new(
              process_url => $base_uri . '/processes/24-99904',
              step_url => 'some',
              container_type_name => ['ABgene 0800'],
              controls => 0);
  lives_ok { $s->_analytes } q{got all info from clarity ('ABgene 0800')};
  my @containers = keys %{$s->_analytes};
  is (scalar @containers, 1, 'one input container, control tube is skipped');
  ok ($s->_validate_container_type, 'validate container flag is true');
  is ($s->_container_type->[0],
      '<type uri="' . $base_uri . '/containertypes/105" name="ABgene 0800"/>',
      'container type derived correctly from name');
}

{
  local $ENV{'WTSICLARITY_WEBCACHE_DIR'} = 't/data/epp/generic/stamper/stamp_with_control';
  my $s = wtsi_clarity::epp::generic::stamper->new(
              process_url => $base_uri . '/processes/24-99904',
              step_url => 'some',
              container_type_name => ['ABgene 0765', 'ABgene 0800'],
              controls => 0);

  lives_ok { $s->_analytes } q{got all info from clarity ('ABgene 0765', 'ABgene 0800')};
  my @containers = keys %{$s->_analytes};
  is (scalar @containers, 1, 'one input container, control tube is skipped');
  is (scalar(map { $_ =~ /\Ahttp/ } keys %{$s->_analytes->{$containers[0]}}), 4, 'control will not be stamped');

  ok ($s->_validate_container_type, 'validate container flag is true');
  is (scalar @{$s->_container_type}, 2, 'two container types retrieved');
  is ($s->_container_type->[0],
      '<type uri="' . $base_uri . '/containertypes/106" name="ABgene 0765"/>',
      'first container type derived correctly from name');
  is ($s->_container_type->[1],
      '<type uri="' . $base_uri . '/containertypes/105" name="ABgene 0800"/>',
      'second container type derived correctly from name');

}

{
  my $dir = tempdir(CLEANUP => 1);
  `cp -R t/data/epp/generic/stamper/stamp_with_control $dir`;
   #remove tube container from test data
  `rm $dir/stamp_with_control/GET/containers.27-7555`;
  my $control = "$dir/stamp_with_control/GET/artifacts.151C-801PA1?state=359614";
  my $control_xml = read_file $control;
  $control_xml =~ s/27-7555/27-7103/g;  #place control on the input plate
  $control_xml =~ s/1:1/H:12/g;         #in well H:12
  open my $fh, '>', $control or die "cannot open filehandle to write to $control";
  print $fh $control_xml or die "cannot write to $control";
  close $fh;

  local $ENV{'WTSICLARITY_WEBCACHE_DIR'} = "$dir/stamp_with_control";
  my $s = wtsi_clarity::epp::generic::stamper->new(
              process_url => $base_uri . '/processes/24-99904',
              step_url => 'some',
              controls => 1);
  lives_ok { $s->_analytes } 'got all info from clarity';
  my @containers = keys %{$s->_analytes};
  is (scalar @containers, 1, 'one input container');
  is (scalar(map { $_ =~ /\Ahttp/ } keys %{$s->_analytes->{$containers[0]}}), 5,
    'control will be stamped when controls flag is true');
}

{
  my $dir = tempdir(CLEANUP => 1);
  `cp -R t/data/epp/generic/stamper/stamp_with_control $dir`;
   #remove tube container from test data
  `rm $dir/stamp_with_control/GET/containers.27-7555`;
  my $control = "$dir/stamp_with_control/GET/artifacts.151C-801PA1?state=359614";
  my $control_xml = read_file $control;
  $control_xml =~ s/27-7555/27-7103/g;  #place control on the input plate
  $control_xml =~ s/1:1/H:12/g;         #in well H:12
  open my $fh, '>', $control or die "cannot open filehandle to write to $control";
  print $fh $control_xml or die "cannot write to $control";
  close $fh;

  local $ENV{'WTSICLARITY_WEBCACHE_DIR'} = "$dir/stamp_with_control";
  my $s = wtsi_clarity::epp::generic::stamper->new(
              process_url => $base_uri . '/processes/24-99904',
              step_url => 'some',
              shadow_plate => 1);
  lives_ok { $s->_analytes } 'got all info from clarity';
  my @containers = keys %{$s->_analytes};
  is (scalar @containers, 1, 'one input container');
  is (scalar(map { $_ =~ /\Ahttp/ } keys %{$s->_analytes->{$containers[0]}}), 5,
    'control will be stamped when it is a shadow plate');
}

{
  local $ENV{'WTSICLARITY_WEBCACHE_DIR'} = 't/data/epp/generic/stamper/stamp';
  my $s = wtsi_clarity::epp::generic::stamper->new(
            process_url => $base_uri . '/processes/24-16122',
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
  my $stamping_method_ref = \&wtsi_clarity::epp::generic::stamper::_stamp_with_copy;
  my $well_calc_ref = \&wtsi_clarity::epp::generic::stamper::_direct_well_calculation;

  lives_ok { $doc = $s->_create_placements_doc } 'Can create placements doc';
  lives_ok { $output_placements = $s->_stamping($doc, $stamping_method_ref, $well_calc_ref) } 'Can create placements';
}

{

  my $s = wtsi_clarity::epp::generic::stamper->new(
            process_url => 'http://testserver.com:1234/here/processes/24-16122',
            step_url => 'some',
            copy_on_target => 0
          );

  my ($well1, $well2) = $s->calculate_destination_wells('A:1');
  is($well1, 'A:1', 'The first well is A:1');
  is($well2, 'B:1', 'The second well is B:1');

  my ($well3, $well4) = $s->calculate_destination_wells('B:1');
  is($well3, 'C:1', 'The first well is C:1');
  is($well4, 'D:1', 'The second well is D:1');

  my ($well5, $well6) = $s->calculate_destination_wells('A:2');
  is($well5, 'A:3', 'The first well is A:3');
  is($well6, 'B:3', 'The second well is B:3');

  my ($well7, $well8) = $s->calculate_destination_wells('E:1');
  is($well7, 'I:1', 'The first well is I:1');
  is($well8, 'J:1', 'The second well is J:1');

  my ($well9, $well10) = $s->calculate_destination_wells('H:1');
  is($well9, 'O:1', 'The first well is O:1');
  is($well10, 'P:1', 'The second well is P:1');

  throws_ok { $s->calculate_destination_wells('I:1') } qr/Source plate must be a 96 well plate/,
    'Only accepts 96 well plates';
}

{
  local $ENV{'WTSICLARITY_WEBCACHE_DIR'} = 't/data/epp/generic/stamper/stamp_shadow';
  use Mojo::Collection 'c';

  my $expected = { '27-2001' => 'barcode-00001-0002'};
  my $s = wtsi_clarity::epp::generic::stamper->new(
            process_url => 'http://testserver.com:1234/here/processes/24-16122',
            step_url => 'some',
            shadow_plate => 1
          );

  $s->_create_containers();
  my $doc = $s->_create_placements_doc;
  my $stamping_method_ref = \&wtsi_clarity::epp::generic::stamper::_direct_stamp;
  my $well_calc_ref = \&wtsi_clarity::epp::generic::stamper::_direct_well_calculation;
  $doc = $s->_stamping($doc, $stamping_method_ref, $well_calc_ref);

  $s->_update_plate_name_with_previous_name();
  my $res = $s->_output_container_details;

  my $details = c->new($res->findnodes( qq{/con:details/con:container} )->get_nodelist())
    ->reduce(sub {
      my $id = $b->findvalue( qq{\@limsid} );
      my $barcode = $b->findvalue( qq{name/text()} );
      $a->{$id} = $barcode;
      $a;
    }, {});

  is_deeply($details, $expected, qq{_update_plate_name_with_previous_name should update the _output_container_details with the correct name.});
}

# Group artifacts on output plate by input plate
{
  local $ENV{'WTSICLARITY_WEBCACHE_DIR'} = 't/data/epp/generic/stamper/group';

  my $analytes = {
    'input_container_1' => {
      'output_containers' => [
        { uri => 'Con 1', limsid => 1, }
      ],
      'analyte1' => { well => 'A:1', target_analyte_uri => ['target01'] }
    },
    'input_container_2' => {
      'output_containers' => [
        { uri => 'Con 1', limsid => 1, }
      ],
      'analyte3' => { well => 'D:1', target_analyte_uri => ['target03'] },
      'analyte4' => { well => 'E:1', target_analyte_uri => ['target04'] },
      'analyte5' => { well => 'F:1', target_analyte_uri => ['target05'] },
      'analyte6' => { well => 'G:1', target_analyte_uri => ['target06'] },
    },
    'input_container_3' => {
      'output_containers' => [
        { uri => 'Con 1', limsid => 1, }
      ],
      'analyte7' => { well => 'G:1', target_analyte_uri => ['target07'] },
      'analyte8' => { well => 'E:4', target_analyte_uri => ['target08'] },
      'analyte9' => { well => 'G:3', target_analyte_uri => ['target09'] },
      'analyte10' => { well => 'C:5', target_analyte_uri => ['target10'] },
    }
  };

  my $s = wtsi_clarity::epp::generic::stamper->new(
    process_url => 'http://testserver.com:1234/here/processes/24-25701',
    step_url => 'http://testserver.com:1234/here/steps/24-25350',
    group => 1,
    _analytes => $analytes,
  );

  my $doc = $s->_create_placements_doc;

  my $stamping_method_ref = \&wtsi_clarity::epp::generic::stamper::_group_inputs_by_container_stamp;
  $doc = $s->_stamping($doc, $stamping_method_ref);

  my @wells = ('A:1', 'B:1', 'C:1', 'D:1', 'E:1', 'F:1', 'G:1', 'H:1', 'A:2');

  foreach my $placement ($doc->findnodes('/stp:placements/output-placements/output-placement')->get_nodelist()) {
    is($placement->findvalue('./location/value'), shift @wells, 'Puts in correct well');
  }

}

# Stamp artifacts by the proceed list
{
  local $ENV{'WTSICLARITY_WEBCACHE_DIR'} = 't/data/epp/generic/stamper/group';

  my $analytes = {
    'input_container_1' => {
      'output_containers' => [
        { uri => 'Con 1', limsid => 1, }
      ],
      'analyte1' => { well => 'A:1', target_analyte_uri => ['target01'] },
      'analyte2' => { well => 'B:1', target_analyte_uri => ['target02'] },
      'analyte3' => { well => 'C:1', target_analyte_uri => ['target03'] },
      'analyte4' => { well => 'D:1', target_analyte_uri => ['target04'] },
      'analyte5' => { well => 'E:1', target_analyte_uri => ['target05'] },
      'analyte6' => { well => 'F:1', target_analyte_uri => ['target06'] },
      'analyte7' => { well => 'G:1', target_analyte_uri => ['target07'] },
      'analyte8' => { well => 'H:1', target_analyte_uri => ['target08'] },
      'analyte9' => { well => 'A:2', target_analyte_uri => ['target09'] },
      'analyte10' => { well => 'B:2', target_analyte_uri => ['target10'] },
      'analyte11' => { well => 'C:2', target_analyte_uri => ['target11'] },
      'analyte12' => { well => 'D:2', target_analyte_uri => ['target12'] },
      'analyte13' => { well => 'E:2', target_analyte_uri => ['target13'] },
      'analyte14' => { well => 'F:2', target_analyte_uri => ['target14'] },
      'analyte15' => { well => 'G:2', target_analyte_uri => ['target15'] },
      'analyte16' => { well => 'H:2', target_analyte_uri => ['target16'] },
      'analyte17' => { well => 'A:3', target_analyte_uri => ['target17'] },
      'analyte18' => { well => 'B:3', target_analyte_uri => ['target18'] },
      'analyte19' => { well => 'C:3', target_analyte_uri => ['target19'] },
      'analyte20' => { well => 'D:3', target_analyte_uri => ['target20'] },
      'analyte21' => { well => 'E:3', target_analyte_uri => ['target21'] },
      'analyte22' => { well => 'F:3', target_analyte_uri => ['target22'] },
      'analyte23' => { well => 'G:3', target_analyte_uri => ['target23'] },
      'analyte24' => { well => 'H:3', target_analyte_uri => ['target24'] },
      'analyte25' => { well => 'A:4', target_analyte_uri => ['target25'] },
      'analyte26' => { well => 'B:4', target_analyte_uri => ['target26'] },
      'analyte27' => { well => 'C:4', target_analyte_uri => ['target27'] },
      'analyte28' => { well => 'D:4', target_analyte_uri => ['target28'] },
      'analyte29' => { well => 'E:4', target_analyte_uri => ['target29'] },
      'analyte30' => { well => 'F:4', target_analyte_uri => ['target30'] },
      'analyte31' => { well => 'G:4', target_analyte_uri => ['target31'] },
      'analyte32' => { well => 'H:4', target_analyte_uri => ['target32'] },
      'analyte33' => { well => 'A:5', target_analyte_uri => ['target33'] },
      'analyte34' => { well => 'B:5', target_analyte_uri => ['target34'] },
      'analyte35' => { well => 'C:5', target_analyte_uri => ['target35'] },
      'analyte36' => { well => 'D:5', target_analyte_uri => ['target36'] },
      'analyte37' => { well => 'E:5', target_analyte_uri => ['target37'] },
      'analyte38' => { well => 'F:5', target_analyte_uri => ['target38'] },
      'analyte39' => { well => 'G:5', target_analyte_uri => ['target39'] },
      'analyte40' => { well => 'H:5', target_analyte_uri => ['target40'] },
      'analyte41' => { well => 'A:6', target_analyte_uri => ['target41'] },
      'analyte42' => { well => 'B:6', target_analyte_uri => ['target42'] },
      'analyte43' => { well => 'C:6', target_analyte_uri => ['target43'] },
      'analyte44' => { well => 'D:6', target_analyte_uri => ['target44'] },
      'analyte45' => { well => 'E:6', target_analyte_uri => ['target45'] },
      'analyte46' => { well => 'F:6', target_analyte_uri => ['target46'] },
      'analyte47' => { well => 'G:6', target_analyte_uri => ['target47'] },
      'analyte48' => { well => 'H:6', target_analyte_uri => ['target48'] },
      'analyte49' => { well => 'A:7', target_analyte_uri => ['target49'] },
      'analyte50' => { well => 'B:7', target_analyte_uri => ['target50'] },
      'analyte51' => { well => 'C:7', target_analyte_uri => ['target51'] },
      'analyte52' => { well => 'D:7', target_analyte_uri => ['target52'] },
      'analyte53' => { well => 'E:7', target_analyte_uri => ['target53'] },
      'analyte54' => { well => 'F:7', target_analyte_uri => ['target54'] },
      'analyte55' => { well => 'G:7', target_analyte_uri => ['target55'] },
      'analyte56' => { well => 'H:7', target_analyte_uri => ['target56'] },
      'analyte57' => { well => 'A:8', target_analyte_uri => ['target57'] },
      'analyte58' => { well => 'B:8', target_analyte_uri => ['target58'] },
      'analyte59' => { well => 'C:8', target_analyte_uri => ['target59'] },
      'analyte60' => { well => 'D:8', target_analyte_uri => ['target60'] },
      'analyte61' => { well => 'E:8', target_analyte_uri => ['target61'] },
      'analyte62' => { well => 'F:8', target_analyte_uri => ['target62'] },
      'analyte63' => { well => 'G:8', target_analyte_uri => ['target63'] },
      'analyte64' => { well => 'H:8', target_analyte_uri => ['target64'] },
      'analyte65' => { well => 'A:9', target_analyte_uri => ['target65'] },
      'analyte66' => { well => 'B:9', target_analyte_uri => ['target66'] },
      'analyte67' => { well => 'C:9', target_analyte_uri => ['target67'] },
      'analyte68' => { well => 'D:9', target_analyte_uri => ['target68'] },
      'analyte69' => { well => 'E:9', target_analyte_uri => ['target69'] },
      'analyte70' => { well => 'F:9', target_analyte_uri => ['target70'] },
      'analyte71' => { well => 'G:9', target_analyte_uri => ['target71'] },
      'analyte72' => { well => 'H:9', target_analyte_uri => ['target72'] },
      'analyte73' => { well => 'A:10', target_analyte_uri => ['target73'] },
      'analyte74' => { well => 'B:10', target_analyte_uri => ['target74'] },
      'analyte75' => { well => 'C:10', target_analyte_uri => ['target75'] },
      'analyte76' => { well => 'D:10', target_analyte_uri => ['target76'] },
      'analyte77' => { well => 'E:10', target_analyte_uri => ['target77'] },
      'analyte78' => { well => 'F:10', target_analyte_uri => ['target78'] },
      'analyte79' => { well => 'G:10', target_analyte_uri => ['target79'] },
      'analyte80' => { well => 'H:10', target_analyte_uri => ['target80'] },
      'analyte81' => { well => 'A:11', target_analyte_uri => ['target81'] },
      'analyte82' => { well => 'B:11', target_analyte_uri => ['target82'] },
      'analyte83' => { well => 'C:11', target_analyte_uri => ['target83'] },
      'analyte84' => { well => 'D:11', target_analyte_uri => ['target84'] },
      'analyte85' => { well => 'E:11', target_analyte_uri => ['target85'] },
      'analyte86' => { well => 'F:11', target_analyte_uri => ['target86'] },
      'analyte87' => { well => 'G:11', target_analyte_uri => ['target87'] },
      'analyte88' => { well => 'H:11', target_analyte_uri => ['target88'] },
      'analyte89' => { well => 'A:12', target_analyte_uri => ['target89'] },
      'analyte90' => { well => 'B:12', target_analyte_uri => ['target90'] },
      'analyte91' => { well => 'C:12', target_analyte_uri => ['target91'] },
      'analyte92' => { well => 'D:12', target_analyte_uri => ['target92'] },
      'analyte93' => { well => 'E:12', target_analyte_uri => ['target93'] },
      'analyte94' => { well => 'F:12', target_analyte_uri => ['target94'] },
      'analyte95' => { well => 'G:12', target_analyte_uri => ['target95'] },
      'analyte96' => { well => 'H:12', target_analyte_uri => ['target96'] },
    },
    'input_container_2' => {
      'output_containers' => [
        { uri => 'Con 2', limsid => 2, }
      ],
      'analyte103' => { well => 'D:1', target_analyte_uri => ['target103'] },
      'analyte104' => { well => 'E:1', target_analyte_uri => ['target104'] },
      'analyte105' => { well => 'F:1', target_analyte_uri => ['target105'] },
      'analyte106' => { well => 'G:1', target_analyte_uri => ['target106'] },
    },
    'input_container_3' => {
      'output_containers' => [
        { uri => 'Con 2', limsid => 2, }
      ],
      'analyte107' => { well => 'G:1', target_analyte_uri => ['target107'] },
      'analyte108' => { well => 'E:4', target_analyte_uri => ['target108'] },
      'analyte109' => { well => 'G:3', target_analyte_uri => ['target109'] },
      'analyte110' => { well => 'C:5', target_analyte_uri => ['target110'] },
    }
  };

  my $s = wtsi_clarity::epp::generic::stamper->new(
    process_url => 'http://testserver.com:1234/here/processes/24-25701',
    step_url => 'http://testserver.com:1234/here/steps/24-25350',
    proceed_to_cherrypick => 1,
    _analytes => $analytes,
  );

  my $doc = $s->_create_placements_doc;

  my $stamping_method_ref = \&wtsi_clarity::epp::generic::stamper::_group_inputs_by_container_stamp;
  $doc = $s->_stamping($doc, $stamping_method_ref);

  my @wells = ( 'A:1', 'B:1', 'C:1', 'D:1', 'E:1', 'F:1', 'G:1', 'H:1',
                'A:2', 'B:2', 'C:2', 'D:2', 'E:2', 'F:2', 'G:2', 'H:2',
                'A:3', 'B:3', 'C:3', 'D:3', 'E:3', 'F:3', 'G:3', 'H:3',
                'A:4', 'B:4', 'C:4', 'D:4', 'E:4', 'F:4', 'G:4', 'H:4',
                'A:5', 'B:5', 'C:5', 'D:5', 'E:5', 'F:5', 'G:5', 'H:5',
                'A:6', 'B:6', 'C:6', 'D:6', 'E:6', 'F:6', 'G:6', 'H:6',
                'A:7', 'B:7', 'C:7', 'D:7', 'E:7', 'F:7', 'G:7', 'H:7',
                'A:8', 'B:8', 'C:8', 'D:8', 'E:8', 'F:8', 'G:8', 'H:8',
                'A:9', 'B:9', 'C:9', 'D:9', 'E:9', 'F:9', 'G:9', 'H:9',
                'A:10', 'B:10', 'C:10', 'D:10', 'E:10', 'F:10', 'G:10', 'H:10',
                'A:11', 'B:11', 'C:11', 'D:11', 'E:11', 'F:11', 'G:11', 'H:11',
                'A:12', 'B:12', 'C:12', 'D:12', 'E:12', 'F:12', 'G:12', 'H:12',
                'A:1', 'B:1', 'C:1', 'D:1', 'E:1', 'F:1', 'G:1', 'H:1'
  );

  foreach my $placement ($doc->findnodes('/stp:placements/output-placements/output-placement')->get_nodelist()) {
    is($placement->findvalue('./location/value'), shift @wells, 'Puts in correct well');
  }

}

1;
