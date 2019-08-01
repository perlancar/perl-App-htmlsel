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
        require File::Slurper;
        my $content = File::Slurper::read_text($args{file});
        $tree = HTML::TreeBuilder->new->parse_content($content);
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
            ],
        );
    }

    my @matches = Data::CSel::csel(
        {class_prefixes=>['HTML']}, $expr, $tree);

     # skip root node itself to avoid duplication
    @matches = grep { refaddr($_) ne refaddr($tree) } @matches
        unless @matches <= 1;

    for my $action (@$actions) {
        if ($action eq 'print') {
            #$action = 'print_func_or_meth:meth:value.func:App::jsonsel::_encode_json';
            $action = 'print_method:as_HTML';
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
