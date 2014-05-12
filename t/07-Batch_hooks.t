# hooks and their arguments
use strict;
use warnings;
use feature qw(state);
use Test::More 0.88;
use Test::NoWarnings;
use t::TestAM qw(chapter_3_train chapter_3_test);

use Algorithm::AM::Batch;

# Tests are run by the hooks passed into the classify() method.
# Each hook contains one test with several subtests. Each is called
# this many times:
my %hook_calls = (
	beginhook => 1,
	begintesthook => 2,
	beginrepeathook => 4,
	endrepeathook => 4,
	datahook => 20,
	endtesthook => 2,
	endhook => 1,
);
my $total_calls = 0;
$total_calls += $_ for values %hook_calls;
# +1 for test_data_hook
# +1 for Test::NoWarnings
# +3 for test_defaults, run twice
plan tests => $total_calls + 1 + 1 + 3*2;

# store number of tests run by each method so we
# can plan subtests
my %tests_per_sub = (
	test_beginning_vars => 5,
	test_item_vars => 4,
	test_iter_vars => 1,
	test_datahook_vars => 2,
	test_end_iter_vars => 2,
	test_end_vars => 4
);
# store methods for choosing to what run in make_hook
my %test_subs = (
	test_beginning_vars => \&test_beginning_vars,
	test_item_vars => \&test_item_vars,
	test_iter_vars => \&test_iter_vars,
	test_datahook_vars => \&test_datahook_vars,
	test_end_iter_vars => \&test_end_iter_vars,
	test_end_vars => \&test_end_vars
);

my $train = chapter_3_train();
my $test = chapter_3_test();
$test->add_item(
	features => [qw(3 1 3)],
	comment => 'second test item',
	class => 'e',
);

my $batch = Algorithm::AM::Batch->new(
	training_set => $train,
	repeat => 2,
	probability => 1,
	max_training_items => 10,
	beginhook => make_hook(
		'beginhook',
		'test_beginning_vars'
	),
	begintesthook => make_hook(
		'begintesthook',
		'test_beginning_vars',
		'test_item_vars'),
	beginrepeathook => make_hook(
		'beginrepeathook',
		'test_beginning_vars',
		'test_item_vars',
		'test_iter_vars'),
	datahook => make_hook(
		'datahook',
		'test_beginning_vars',
		'test_item_vars',
		'test_iter_vars',
		'test_datahook_vars'),
	endrepeathook => make_hook(
		'endrepeathook',
		'test_beginning_vars',
		'test_item_vars',
		'test_iter_vars',
		'test_end_iter_vars'),
	endtesthook => make_hook(
		'endtesthook',
		'test_beginning_vars',
		'test_item_vars',
		'test_end_iter_vars'),
	endhook => make_hook(
		'endhook',
		'test_beginning_vars',
		'test_end_vars'
	),
);

# test that defaults are set before and after classification
test_defaults($batch);

# most tests are run in classification hooks
$batch->classify_all($test);

test_defaults($batch);

# test item exclusion via data hook
test_data_hook();

# make a hook which runs the given test subs in a single subtest.
# Pass on the arguments passed to the hook at classification time.
sub make_hook {
	my ($name, @subs) = @_;
	return sub {
		my (@args) = @_;
		subtest $name => sub {
			my $plan = 0;
			$plan += $tests_per_sub{$_} for @subs;
			plan tests => $plan;
			$test_subs{$_}->(@args) for @subs;
		};
		# true return value is needed by datahook to signal
		# that data should be considered during classification
		return 1;
	};
}

#check vars available from beginning to end of classification
sub test_beginning_vars {
	my ($batch) = @_;
	isa_ok($batch, 'Algorithm::AM::Batch');
	is($batch->training_set->size, 5,
		'training set');
	is($batch->test_set->size, 2, 'test set');
	is($batch->probability, 1,
		'probability is 1 by default');
	is($batch->max_training_items, 10,
		'training data capped at 10 items');
	return;
}

# Check variables provided before each test
# There are two items, 312 and 313, marked with
# different specs and outcomes. Check each one.
sub test_item_vars {
	my ($batch, $test_item) = @_;

	isa_ok($test_item, 'Algorithm::AM::DataSet::Item');

	ok($test_item->class eq 'r' || $test_item->class eq 'e',
		'test outcome');
	if($test_item->class eq 'e'){
		like(
			$test_item->comment,
			qr/second test item$/,
			'test spec'
		);
		is_deeply($test_item->features, [3,1,3], 'test variables')
			or note explain $test_item->features;
	}else{
		like(
			$test_item->comment,
			qr/test item spec$/,
			'test spec'
		);
		is_deeply($test_item->features, [3,1,2], 'test variables')
			or note explain $test_item->features;
	}
	return;
}

# Test variables available for each iteration
sub test_iter_vars {
	my ($batch, $test_item) = @_;
	ok(
		$batch->pass == 1 || $batch->pass == 2,
		'pass- only do 2 passes of the data');
	return;
}

sub test_datahook_vars {
	my ($batch, $test_item, $train_item) = @_;
	isa_ok($train_item, 'Algorithm::AM::DataSet::Item');
	ok($train_item->comment =~ /my.*CommentHere/,
		'item is from training set');
}

# Test variables provided after an iteration is finished
sub test_end_iter_vars {
	my ($batch, $test_item, $result) = @_;

	if($test_item->class eq 'e'){
		is_deeply($result->scores, {e => '4', r => '4'},
			'outcome scores');
	}else{
		is_deeply($result->scores, {e => '4', r => '9'},
			'outcomes scores');
	}
	is_deeply($batch->excluded_items, [], 'no items excluded');
	return;
}

# Test variables provided after all iterations are finished
sub test_end_vars {
	my ($batch, @results) = @_;

	is_deeply($results[0]->scores, {e => '4', r => '9'},
		'scores for first result');
	is_deeply($results[1]->scores, {e => '4', r => '9'},
		'scores for second result');
	is_deeply($results[2]->scores, {e => '4', r => '4'},
		'scores for third result');
	is_deeply($results[3]->scores, {e => '4', r => '4'},
		'scores for fourth result');
	return;
}

sub test_defaults {
	my ($batch) = @_;
	is($batch->excluded_items, undef,
		'excluded_items is undef outside of hooks');
	is($batch->pass, undef, 'pass is undef outside of hooks');
	is($batch->test_set, undef, 'test_set is undef outcome of hooks');
	return;
}

# test that datahook excludes items via false return value
sub test_data_hook {
	my $batch = Algorithm::AM::Batch->new(
		training_set => chapter_3_train(),
		datahook 	=> sub {
			# false return value indicates that item should be excluded
			return 0;
		},
		endrepeathook => sub {
			my ($batch) = @_;
			is_deeply($batch->excluded_items, [0, 1, 2, 3, 4],
			 	'datahook can exluced items');
		},
	);
	$batch->classify_all(chapter_3_test());
	return;
}
