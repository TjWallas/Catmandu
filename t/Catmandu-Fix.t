use Test::More tests => 6;

BEGIN { use_ok 'Catmandu::Fix'; }
require_ok 'Catmandu::Fix';

package T::Fix;

use Moose;

extends 'Catmandu::Fix';

augment apply_fix => sub {
    my ($self, $obj) = @_;
    my $given_name = delete $obj->{authors}->[0]->{given_name};
    my $last_name = delete $obj->{authors}->[0]->{last_name};
    $obj->{authors}->[0]->{name} = "$given_name $last_name";
    pop @{$obj->{authors}->[0]->{theory}};
    $obj;
};

package main;

my $fixer = Catmandu::Fix->new;

isa_ok $fixer, 'Catmandu::Fix';

my $obj = {
    authors => [
        { given_name => "Albert" ,
          last_name => "Einstein",
          theory => [qw(relativity quantum heat evolution)] },
    ],
};

my $fixed_obj = {
    authors => [
        { name => "Albert Einstein",
          theory => [qw(relativity quantum heat)] },
    ],
};

my $cloned_obj = $fixer->fix($obj);
is_deeply $cloned_obj, $obj, "non augmented fix returns a clone";

$fixer = T::Fix->new;

my $augmented_obj = $fixer->fix($obj);
is_deeply $obj, $cloned_obj, "fix doesn't affect original object";
is_deeply $augmented_obj, $fixed_obj, "fix returns an augmented object";

done_testing;
