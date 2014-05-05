use strict;
use warnings;
use Test::More 0.88;
plan tests => 4;
use Test::LongString;
use Algorithm::AM;
use t::TestAM 'chapter_3_project';

test_config_info();

my $am = Algorithm::AM->new(chapter_3_project());
my ($result) = $am->classify();
test_statistical_summary($result);
test_aset_summary($result);
test_gang_summary($result);

# test that the configuration information is correctly printed by
# the config_info method after setting internal state through
# the constructor.
sub test_config_info {
    subtest 'configuration info string' => sub {
        plan tests => 2;
        my $result = Algorithm::AM::Result->new(
            excluded_data => [0,1,2],
            given_excluded => 1,
            num_variables => 3,
            test_item => [qw(a b c)],
            test_spec => 'comment',
            test_outcome => 2,
            exclude_nulls => 1,
            count_method => 'linear',
            datacap => 50,
            test_in_data => 1,
        );
        my $info = ${$result->config_info};
        my $expected = <<'END_INFO';
+----------------------------+----------------+
| Option                     | Setting        |
+----------------------------+----------------+
| Given context              | a b c, comment |
| Nulls                      | exclude        |
| Gang                       | linear         |
| Test item in data          | yes            |
| Test item excluded         | yes            |
| Total excluded items       |  4             |
| Number of data items       | 50             |
| Number of active variables |  3             |
+----------------------------+----------------+
END_INFO
        is_string_nows($info, $expected,
            'given/nulls excluded, linear, item in data') or note $info;
        $result = Algorithm::AM::Result->new(
            excluded_data => [],
            given_excluded => 0,
            num_variables => 3,
            test_item => [qw(a b c)],
            test_spec => 'comment',
            test_outcome => 2,
            exclude_nulls => 0,
            probability => .5,
            count_method => 'squared',
            datacap => 40,
            test_in_data => 0,
        );

        $info = ${$result->config_info};
        $expected = <<'END_INFO';
+----------------------------+----------------+
| Option                     | Setting        |
+----------------------------+----------------+
| Given context              | a b c, comment |
| Nulls                      | include        |
| Gang                       | squared        |
| Test item in data          | no             |
| Test item excluded         | no             |
| Total excluded items       |  0             |
| Number of data items       | 40             |
| Number of active variables |  3             |
| Data Inclusion Probability |  0.5           |
+----------------------------+----------------+
END_INFO
        is_string_nows($info, $expected,
            'given/nulls included, linear, item not in data, probability')
            or note $info;
    };
    return;
}

# test the statistical_summary method; mock the result method
# and see if the printout uses the returned info correctly.
sub test_statistical_summary{
    my ($result) = @_;
    subtest 'statistical summary' => sub {
        plan tests => 3;
        my $stats = ${$result->statistical_summary};
        my $expected = <<'END_STATS';
Statistical Summary
+---------+----------+------------+
| Outcome | Pointers | Percentage |
+---------+----------+------------+
| e       |  4       |  30.769%   |
| r       |  9       |  69.231%   |
+---------+----------+------------+
| Total   | 13       |            |
+---------+----------+------------+
Expected outcome: r
Correct outcome predicted.
END_STATS

        is_string_nows($stats, $expected, 'statistical summary')
            or note $stats;

        # check that statistical_summary correctly prints out the
        # incorrect and tie results.
        {
            no warnings 'redefine';
            local *Algorithm::AM::Result::result = sub {
                return 'incorrect';
            };
            $stats = ${$result->statistical_summary};
            $expected = <<'END_STATS';
Statistical Summary
+---------+----------+------------+
| Outcome | Pointers | Percentage |
+---------+----------+------------+
| e       |  4       |  30.769%   |
| r       |  9       |  69.231%   |
+---------+----------+------------+
| Total   | 13       |            |
+---------+----------+------------+
Expected outcome: r
Incorrect outcome predicted.
END_STATS
            is_string_nows($stats, $expected,
                'statistical summary (incorrect outcome)') or
                note $stats;

        }
        {
            no warnings 'redefine';
            local *Algorithm::AM::Result::result = sub {
                return 'tie';
            };
            $stats = ${$result->statistical_summary};
            $expected = <<'END_STATS';
Statistical Summary
+---------+----------+------------+
| Outcome | Pointers | Percentage |
+---------+----------+------------+
| e       |  4       |  30.769%   |
| r       |  9       |  69.231%   |
+---------+----------+------------+
| Total   | 13       |            |
+---------+----------+------------+
Expected outcome: r
Outcome is a tie.
END_STATS
            is_string_nows($stats, $expected,
                'statistical summary (tie)') or
                note $stats;
        }
    };
    return;
}

# test the analogical set summary
sub test_aset_summary {
    my ($result) = @_;
    my $set = ${$result->analogical_set_summary};
    my $expected = <<'END_SET';
Analogical Set
Total Frequency = 13
+---------+---------------------+----------+------------+
| Outcome | Exemplar            | Pointers | Percentage |
+---------+---------------------+----------+------------+
| e       | myFirstCommentHere  | 4        |  30.769%   |
| r       | myThirdCommentHere  | 2        |  15.385%   |
| r       | myFourthCommentHere | 3        |  23.077%   |
| r       | myFifthCommentHere  | 4        |  30.769%   |
+---------+---------------------+----------+------------+
END_SET
    is_string_nows($set, $expected, 'analogical set printout') or
        note $set;
    return;
}

# Test the gang summary, with and without individual items included
sub test_gang_summary {
    my ($result) = @_;
    subtest 'gang printing' => sub {
        plan tests => 2;
        my $gang = ${$result->gang_summary(0)};
        is_string_nows($gang,
            <<'END_GANG', 'gang summary without items') or note $gang;
+------------+----------+-----------+---------+-------+
| Percentage | Pointers | Num Items | Outcome |       |
| Context    |          |           |         | 3 1 2 |
+------------+----------+-----------+---------+-------+
*******************************************************
|  61.538%   | 8        |           |         | 3 1 * |
+------------+----------+-----------+---------+-------+
|  30.769%   | 4        | 1         | e       |       |
|  30.769%   | 4        | 1         | r       |       |
*******************************************************
|  23.077%   | 3        |           |         | * 1 2 |
+------------+----------+-----------+---------+-------+
|  23.077%   | 3        | 1         | r       |       |
*******************************************************
|  15.385%   | 2        |           |         | * * 2 |
+------------+----------+-----------+---------+-------+
|  15.385%   | 2        | 1         | r       |       |
+------------+----------+-----------+---------+-------+
END_GANG
        $gang = ${$result->gang_summary(1)};
        is_string_nows($gang,
            <<'END_GANG', 'gang summary with items') or note $gang;
+------------+----------+-----------+---------+-------+---------------------+
| Percentage | Pointers | Num Items | Outcome |       | Item Comment        |
| Context    |          |           |         | 3 1 2 |                     |
+------------+----------+-----------+---------+-------+---------------------+
*****************************************************************************
|  61.538%   | 8        |           |         | 3 1 * |                     |
+------------+----------+-----------+---------+-------+---------------------+
|  30.769%   | 4        | 1         | e       |       |                     |
|            |          |           |         | 3 1 0 | myFirstCommentHere  |
|  30.769%   | 4        | 1         | r       |       |                     |
|            |          |           |         | 3 1 1 | myFifthCommentHere  |
*****************************************************************************
|  23.077%   | 3        |           |         | * 1 2 |                     |
+------------+----------+-----------+---------+-------+---------------------+
|  23.077%   | 3        | 1         | r       |       |                     |
|            |          |           |         | 2 1 2 | myFourthCommentHere |
*****************************************************************************
|  15.385%   | 2        |           |         | * * 2 |                     |
+------------+----------+-----------+---------+-------+---------------------+
|  15.385%   | 2        | 1         | r       |       |                     |
|            |          |           |         | 0 3 2 | myThirdCommentHere  |
+------------+----------+-----------+---------+-------+---------------------+
END_GANG
    };
    return;
}
