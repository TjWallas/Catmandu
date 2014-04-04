package Catmandu::Fix::Parser;

use Catmandu::Sane;
use Catmandu::Util qw(:is require_package read_file);
use Catmandu::Fix::Filter;
use Moo;

sub _build_fix_instance {
    my ($pkg, $ns, $args) = @_;
    my $class = require_package($pkg, $ns);
    $class->new(map {
        if (exists $_->{qq_string})  {
            $_->{qq_string};
        } elsif (exists $_->{q_string}) {
            $_->{q_string};
        } elsif (exists $_->{key}) {
            $_->{key};
        } else {
            $_->{int};
        }
    } @$args);
}

sub _parser {
    state $parser = do {
        use Regexp::Grammars;
        qr/
            <fixes>

            <rule: fixes>        <[expr]>*
                                 <MATCH= (?{ $MATCH{expr} })>

            <rule: expr>         <if_block>
                                 (?{ my $fix = $MATCH{if_block}{fix};
                                     my $instance = _build_fix_instance($fix->{name}, 'Catmandu::Fix::Condition', $fix->{args} || []);
                                     if ($MATCH{if_block}{fixes}) {
                                         push @{$instance->fixes},
                                            map { $_->{instance} } @{$MATCH{if_block}{fixes}};
                                     }
                                     if ($MATCH{if_block}{else_block} && $MATCH{if_block}{else_block}{fixes}) {
                                         push @{$instance->else_fixes},
                                            map { $_->{instance} } @{$MATCH{if_block}{else_block}{fixes}};
                                     }
                                     $MATCH{instance} = $instance;
                                 })
                                 |
                                 <unless_block>
                                 (?{ my $fix = $MATCH{unless_block}{fix};
                                     my $instance = _build_fix_instance($fix->{name}, 'Catmandu::Fix::Condition', $fix->{args} || []);
                                     if ($MATCH{unless_block}{fixes}) {
                                         push @{$instance->else_fixes},
                                            map { $_->{instance} } @{$MATCH{unless_block}{fixes}};
                                     }
                                     $MATCH{instance} = $instance;
                                 })
                                 |
                                 <select>
                                 (?{ my $fix = $MATCH{select}{fix};
                                     my $instance = _build_fix_instance($fix->{name}, 'Catmandu::Fix::Condition', $fix->{args} || []);
                                     push @{$instance->else_fixes}, Catmandu::Fix::Filter->new;
                                     $MATCH{instance} = $instance;
                                 })
                                 |
                                 <reject>
                                 (?{ my $fix = $MATCH{reject}{fix};
                                     my $instance = _build_fix_instance($fix->{name}, 'Catmandu::Fix::Condition', $fix->{args} || []);
                                     push @{$instance->fixes}, Catmandu::Fix::Filter->new;
                                     $MATCH{instance} = $instance;
                                 })
                                 |
                                 <fix>
                                 (?{ my $fix = $MATCH{fix};
                                     my $instance = _build_fix_instance($fix->{name}, 'Catmandu::Fix', $fix->{args} || []);
                                     $MATCH{instance} = $instance;
                                 })

            <rule: if_block>     if <fix> <fixes> <else_block>? end

            <rule: else_block>   else <fixes>

            <rule: unless_block> unless <fix> <fixes> end

            <rule: select>       select \( <fix> \)
            <rule: reject>       reject \( <fix> \)

            <rule: fix>          <name> \( \)
                                 |
                                 <name> \( <args> \)

            <rule: args>         <[arg]>+ % <_sep>
                                 <MATCH= (?{ $MATCH{arg} })>

            <rule: arg>          <qq_string>
                                 |
                                 <q_string>
                                 |
                                 <key>
                                 |
                                 <int>
                                 |
                                 <fatal: Expected string, key or int>

            <token: name>        [a-z][a-z0-9_]*

            <token: qq_string>   "((?:[^\\"]|\\.)*)"
                                 <MATCH= (?{ $CAPTURE })>

            <token: q_string>    '((?:[^\\']|\\.)*)'
                                 <MATCH= (?{ $CAPTURE })>

            <token: key>         -?([a-z][a-z0-9_]*)
                                 <MATCH= (?{ $CAPTURE })>

            <token: int>         (-?\d+)
                                 <MATCH= (?{ eval $CAPTURE })>

            <token: _sep>        (?:\s|,|;|:|=>)+

            <token: ws>          (?:<_sep>)*
        /xms;
    };
}

sub parse {
    my ($self, @sources) = @_;
    @sources = map { ref $_ ? @$_ : $_ } @sources;
    my $fixes = [];
    my $parser = $self->_parser;

    for my $source (@sources) {
        if (is_able($source, 'fix')) {
            push @$fixes, $source;
        } elsif (is_string($source)) {
            if ($source !~ /[\r\n\t\v\*]/ && -f $source) {
                $source = read_file($source);
            }
            $source =~ $parser || do {
                my @errors = @!;
                Catmandu::BadArg->throw(join("\n", "cannot parse fix:", @errors));
            };
            if (my $parsed = $/{fixes}) {
                push @$fixes, map { $_->{instance} } @$parsed;
            }
        }
    }

    $fixes;
}

1;
