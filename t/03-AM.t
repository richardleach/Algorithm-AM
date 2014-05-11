# Test correct classification.
# Mostly uses the example from chapter 3 of the green book

use strict;
use warnings;
use Algorithm::AM;
use Algorithm::AM::Batch;
use Test::More 0.88;
plan tests => 14;
use Test::NoWarnings;
use Test::Exception;
use t::TestAM qw(chapter_3_train chapter_3_test);

use FindBin qw($Bin);
use Path::Tiny;

test_input_checking();
test_accessors();


my $train = chapter_3_train();
my $test = chapter_3_test()->get_item(0);
my $am = Algorithm::AM->new(
    train => $train,
);
my ($result) = $am->classify($test);
test_quadratic_classification($result);
test_analogical_set($result);
test_gang_effects($result);
test_linear_classification();
test_nulls();
test_given();

# test that methods die with bad input
sub test_input_checking {
    throws_ok {
        Algorithm::AM->new();
    } qr/Missing required parameter 'train'/,
    'dies when no training set provided';

    throws_ok {
        Algorithm::AM->new(
            train => 'stuff',
        );
    } qr/Parameter train should be an Algorithm::AM::DataSet/,
    'dies with bad training set';

    throws_ok {
        Algorithm::AM->new(
            train => Algorithm::AM::DataSet->new(cardinality => 3),
            foo => 'bar'
        );
    } qr/Unknown option foo/,
    'dies with bad argument';

    throws_ok {
        my $am = Algorithm::AM->new(
            train => Algorithm::AM::DataSet->new(cardinality => 3),
        );
        $am->classify(
            Algorithm::AM::DataSet::Item->new(
                features => ['a']
            )
        );
    } qr/Training set and test item do not have the same cardinality \(3 and 1\)/,
    'dies with mismatched train/test cardinalities';

    return;
}

# test that constructor sets state properly
sub test_accessors {
    subtest 'AM constructor saves data set' => sub {
        plan tests => 2;
        my $am = Algorithm::AM->new(
            train => Algorithm::AM::DataSet->new(cardinality => 3),
        );
        isa_ok($am->training_set, 'Algorithm::AM::DataSet',
            'training_set returns correct object type');

        is($am->training_set->cardinality, 3,
            'training set saved');
    };
}

# test classification results using quadratic counting
sub test_quadratic_classification {
    my ($result) = @_;
    subtest 'quadratic calculation' => sub {
        plan tests => 3;
        is($result->total_pointers, 13, 'total pointers')
            or note $result->total_pointers;
        is($result->count_method, 'squared',
            'counting configured to quadratic');
        is_deeply($result->scores, {'e' => 4, 'r' => 9},
            'outcome scores') or
            note explain $result->scores;
    };
    return;
}

# test classification results using linear counting
sub test_linear_classification {
    subtest 'linear calculation' => sub {
        plan tests => 3;
        my $am = Algorithm::AM->new(
            train => $train,
        );
        my ($result) = $am->classify($test, linear => 1);
        is($result->total_pointers, 7, 'total pointers')
            or note $result->total_pointers;;
        is($result->count_method, 'linear',
            'counting configured to quadratic');
        is_deeply($result->scores, {'e' => 2, 'r' => 5}, 'outcome scores')
            or note explain $result->scores;
    };
    return;
}

# test with null variables, using both exclude_nulls
# and include_nulls
# TODO: test for the correct number of active variables
sub test_nulls {
    my $test = Algorithm::AM::DataSet::Item->new(
        features => ['', '1', '2'],
        class => 'r',
    );
    my $am = Algorithm::AM->new(
        train => $train,
    );

    subtest 'exclude nulls' => sub {
        plan tests => 3;
        my ($result) = $am->classify($test, exclude_nulls => 1);
        is($result->total_pointers, 10, 'total pointers')
            or note $result->total_pointers;
        ok($result->exclude_nulls, 'exclude nulls is true');
        is_deeply($result->scores, {'e' => 3, 'r' => 7},
            'outcome scores')
            or note explain $result->scores;
    };

    subtest 'include nulls' => sub {
        plan tests => 3;
        my ($result) = $am->classify($test, exclude_nulls => 0);
        is($result->total_pointers, 5, 'total pointers')
            or note $result->total_pointers;
        ok(!$result->exclude_nulls, 'exclude nulls is false');
        is_deeply($result->scores, {'r' => 5}, 'outcome scores')
            or note explain $result->scores;
    };

    return;
}

# test case where test data is in given data
sub test_given {
    my $train = chapter_3_train();
    $train->add_item(
        features => [qw(3 1 2)],
        class => 'r',
        comment => 'same as the test exemplar'
    );
    my $am = Algorithm::AM->new(
        train => $train,
        exclude_given => 1
    );

    subtest 'exclude given' => sub {
        plan tests => 3;
        my ($result) = $am->classify($test);
        is($result->total_pointers, 13, 'total pointers')
            or note $result->total_pointers;
        ok($result->given_excluded, 'given item was excluded');
        is_deeply($result->scores, {'e' => 4, 'r' => 9}, 'outcome scores')
            or note explain $result->scores;
    };

    subtest 'include given' => sub {
        plan tests => 3;
        my ($result) = $am->classify($test, exclude_given => 0);
        is($result->total_pointers, 15, 'total pointers')
            or note $result->total_pointers;
        ok(!$result->given_excluded, 'given was not excluded');
        is_deeply($result->scores, {'r' => 15}, 'outcome scores')
            or note explain $result->scores;
    };
    return;
}

sub test_analogical_set {
    my ($result) = @_;
    subtest 'analogical set' => sub {
        plan tests => 5;
        my $set = $result->analogical_set();

        is_deeply($set, {0 => 4, 2 => 2, 3 => 3, 4 => 4},
            'data indices and pointer values') or note explain $set;
        # now confirm that the referenced data really are what we think
        is($train->get_item(0)->comment, 'myFirstCommentHere',
            'confirm first item')
            or note $train->get_item(0)->comment;
        is($train->get_item(2)->comment, 'myThirdCommentHere',
            'confirm third item')
            or note $train->get_item(2)->comment;
        is($train->get_item(3)->comment, 'myFourthCommentHere',
            'confirm fourth item')
            or note $train->get_item(3)->comment;
        is($train->get_item(4)->comment, 'myFifthCommentHere',
            'confirm fifth item')
            or note $train->get_item(4)->comment;
    };
    return;
}

sub test_gang_effects {
    my ($result) = @_;
    my $expected_effects = {
      '- - 2' => {
        'data' => {'r' => [2]},
        'effect' => '0.153846153846154',
        'homogenous' => 'r',
        'outcome' => {
          'r' => {
            'effect' => '0.153846153846154',
            'score' => '2'
          }
        },
        'score' => 2,
        'size' => 1,
        'vars' => ['','','2']
      },
      '- 1 2' => {
        'data' => {'r' => [3]},
        'effect' => '0.230769230769231',
        'homogenous' => 'r',
        'outcome' => {
          'r' => {
            'effect' => '0.230769230769231',
            'score' => '3'
          }
        },
        'score' => 3,
        'size' => 1,
        'vars' => ['','1','2']
      },
      '3 1 -' => {
        'data' => {'e' => [0], 'r' => [4]},
        'effect' => '0.615384615384615',
        'homogenous' => 0,
        'outcome' => {
          'e' => {
            'effect' => '0.307692307692308',
            'score' => 4
          },
          'r' => {
            'effect' => '0.307692307692308',
            'score' => 4
          }
        },
        'score' => 8,
        'size' => 2,
        'vars' => ['3','1', '']
      }
    };
    is_deeply($result->gang_effects, $expected_effects,
        'correct reported gang effects') or
        note explain $result->gang_effects;

    return;
}
