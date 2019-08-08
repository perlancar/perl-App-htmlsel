package App::htmlsel;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

use App::CSelUtils;
use Scalar::Util qw(blessed);

our %SPEC;

$SPEC{htmlsel} = {
    v => 1.1,
    summary => 'Select HTML::Element nodes using CSel syntax',
    args => {
        %App::CSelUtils::foosel_args_common,
    },
};
sub htmlsel {
    App::CSelUtils::foosel(
        @_,
        code_read_tree => sub {
            my $args = shift;

            require HTML::TreeBuilder;
            my $content;
            if ($args->{file} eq '-') {
                binmode STDIN, ":encoding(utf8)";
                $content = join "", <STDIN>;
            } else {
                require File::Slurper;
                $content = File::Slurper::read_text($args->{file});
            }
            my $tree = HTML::TreeBuilder->new->parse_content($content);

          PATCH: {
                last if $App::htmlsel::patch_handle;
                require Module::Patch;
                $App::htmlsel::patch_handle = Module::Patch::patch_package(
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
                    ], # patch actions
                ); # patch_package()
            } # PATCH
            $tree;
        }, # code_read_tree

        csel_opts => {class_prefixes=>['HTML']},

        code_transform_node_actions => sub {
            my $args = shift;

            for my $action (@{$args->{node_actions}}) {
                if ($action eq 'print' || $action eq 'print_as_string') {
                    $action = 'print_method:as_HTML';
                } elsif ($action eq 'dump') {
                    #$action = 'dump:tag.class.id';
                    $action = 'dump:as_HTML';
                }
            }
        }, # code_transform_actions
    );
}

1;
#ABSTRACT:

=head1 SYNOPSIS


=head1 SEE ALSO
