package Analogize;
# ABSTRACT: classify data with AM from the command line
use strict;
use warnings;
use 5.010;
use Carp;
use Algorithm::AM::Batch;
use Path::Tiny;
# 2.13 needed for aliases
use Getopt::Long 2.13 qw(GetOptionsFromArray);
use Pod::Usage;

run(@ARGV) unless caller;

sub run {
    my %args = (
        # defaults here...
    );
    GetOptionsFromArray(\@_, \%args,
        'format=s',
        'exemplars|train|data:s',
        'project:s',
        'test:s',
        'print:s',
        'help|?',
    ) or pod2usage(2);
    _validate_args(%args);

    my @print_methods;
    if($args{print}){
        @print_methods = split ',', $args{print};
    }

    my ($train, $test);
    if($args{exemplars}){
        $train = dataset_from_file(
            path => $args{exemplars},
            format => $args{format});
    }
    if($args{test}){
        $test = dataset_from_file(
            path => $args{test},
            format => $args{format});
    }
    if($args{project}){
        $train = dataset_from_file(
            path => path($args{project})->child('data'),
            format => $args{format});
        $test = dataset_from_file(
            path => path($args{project})->child('test'),
            format => $args{format});
    }
    # default to leave-one-out if no test set specified
    $test ||= $train;

    my $count = 0;
    my $batch = Algorithm::AM::Batch->new(
        training_set => $train,
        # print the result of each classification as they are provided
        end_test_hook => sub {
            my ($batch, $test_item, $result) = @_;
            ++$count if $result->result eq 'correct';
            say $test_item->comment . ":\t" . $result->result . "\n";
            say ${ $result->$_ } for @print_methods;
        }
    );
    $batch->classify_all($test);

    say "$count out of " . $test->size . " correct";
    return;
}

sub _validate_args {
    my %args = @_;
    if($args{help}){
        pod2usage(1);
    }
    my $errors = '';
    if(!$args{exemplars} and !$args{project}){
        $errors .= "Error: need either --exemplars or --project parameters\n";
    }elsif(($args{exemplars} or $args{test}) and $args{project}){
        $errors .= "Error: --project parameter cannot be used with --exempalrs or --test\n";
    }
    if(!defined $args{format}){
        $errors .= "Error: missing --format parameter\n";
    }elsif($args{format} !~ m/^(?:no)?commas$/){
        $errors .=
            "Error: --format parameter must be either 'commas' or 'nocommas'\n";
    }
    if($args{print}){
        my %allowed =
            map {$_ => 1} qw(
                config_info
                statistical_summary
                analogical_set_summary
                gang_summary
            );
        for my $param (split ',', $args{print}){
            if(!exists $allowed{$param}){
                $errors .= "Error: unknown print parameter '$param'\n";
            }
        }
    }
    if($errors){
        chomp $errors;
        pod2usage($errors);
    }
}

__END__

=head1 SYNOPSIS

analogize --format <format> [--exemplars <file>] [--test <file>]
[--project <dir>] [--print <info1,info2...>] [--help]

=head1 C<DESCRIPTION>

Classify data with analogical modeling from the command line.
Required arguments are B<format> and either B<exemplars> or
B<project>. You can use old AM::Parallel projects (a directory
containing C<data> and C<test> files) or specify individual data
and test files. By default, only the accuracy of the predicted
outcomes is printed. More detail may be printed using the B<print>
option.

=head1 OPTIONS

=item B<format>

specify either commas or nocommas format for exemplar and test data files

=item B<exemplars>, B<data> or B<train>

path to the file containing the examplar/training data

=item B<project>

path to AM::Parallel project (ignores 'outcome' file)

=item B<test>

path to the file containing the test data. If none is specified,
performs leave-one-out classification with the exemplar set

=item B<print>

comma-separated list of reports to print. Available options are:
config_info, statistical_summary, analogical_set_summary, and
gang_summary. See documentation in L<Algorithm::AM::Result> for details.

=item B<help> or B<?>

print help message

=back
