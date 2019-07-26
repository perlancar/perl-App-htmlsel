package App::htmlsel;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

use App::CSelUtils;
use Scalar::Util qw(blessed refaddr);

our %SPEC;

$SPEC{htmlsel} = {
    v => 1.1,
    summary => 'Select HTML::Element nodes using CSel syntax',
    args => {
        %App::CSelUtils::foosel_common_args,
        %App::CSelUtils::foosel_tree_action_args,
    },
};
sub htmlsel {
    my %args = @_;

    my $expr = $args{expr};
    my $actions = $args{actions};

    # parse first so we can bail early on error without having to read the input
    require Data::CSel;
    Data::CSel::parse_csel($expr)
          or return [400, "Invalid CSel expression '$expr'"];

    require HTML::TreeBuilder;
    my $tree;
    if ($args{file} eq '-') {
        binmode STDIN, ":encoding(utf8)";
        $tree = HTML::TreeBuilder->new->parse_content(join "", <>);
    } else {
        #require File::Slurper;
        $tree = HTML::TreeBuilder->new->parse_file($args{file});
    }

    my $patch_handle;
  PATCH: {
        require Module::Patch;
        $patch_handle = Module::Patch::patch_package(
            'HTML::Element', [
                {
                    action   => 'add',
                    sub_name => 'children',
                    code     => sub {
                        my @children =
                            grep { blessed($_) && $_->isa('HTML::Element') }
                            @{ $_[0]{_content} };
                        #use DD; dd \@children;
                        @children;
                    },
                },
                {
                    action   => 'add',
                    sub_name => 'class',
                    code     => sub {
                        $_[0]{class};
                    },
                },
                {
                    action   => 'add',
                    sub_name => 'preview',
                    code     => sub {
                        my $res = $_[0]->as_HTML;
                        $res =~ s/\A\s+//s;
                        $res = substr($res, 0, 22)."..." if length($res) > 25;
                        $res =~ s/\n/ /g;
                        $res;
                    },
                },
            ],
        );
    }

    my @matches = Data::CSel::csel(
        {class_prefixes=>['HTML']}, $expr, $tree);

     # skip root node itself to avoid duplication
    @matches = grep { refaddr($_) ne refaddr($tree) } @matches
        unless @matches <= 1;

    for my $action (@$actions) {
        if ($action eq 'print' || $action eq 'print_as_string') {
            $action = 'print_method:as_HTML';
        } elsif ($action eq 'dump') {
            #$action = 'dump:tag.class.id';
            $action = 'dump:preview';
       }
    }

    App::CSelUtils::do_actions_on_nodes(
        nodes   => \@matches,
        actions => $args{actions},
    );
}

1;
#ABSTRACT:

=head1 SYNOPSIS


=head1 SEE ALSO
