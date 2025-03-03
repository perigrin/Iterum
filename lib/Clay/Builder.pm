use 5.40.0;
use warnings;
use experimental qw(class);
use Clay::Element;

# Helper class to simplify UI construction (similar to Clay macros)
class Clay::Builder::ElementBuilder {
    field $config :param   = {};
    field $element :reader = Clay::Element->new(%$config);
    field $context :param;
    field $parent_builder :param = undef;
    field $closed = 0;

    method begin() {
        return $self;
    }

    method measure(@args) { $element->measure(@args) }
    method layout(@args)  { $element->layout(@args) }
    method size(@args)    { $element->size(@args) }

    method generate_render_commands(@args) {
        $element->generate_render_commands(@args);
    }

    method child($config) {

        # Create a new builder for the child element
        my $child_builder = Clay::Builder::ElementBuilder->new(
            context        => $context,
            parent_builder => $self,
            config         => $config
        );

        # Add the child to this element
        $element->add_child( $child_builder->element );

        return $child_builder;
    }

    method text( $text, $config = { id => 'text-node' . ( state $i++ ) } ) {

        # Create a text element
        my $text_element = Clay::Element->new( %$config, text => $text );

        # Add as child to this element
        $element->add_child($text_element);

        return $self;
    }

    method end() {
        $closed = 1;

        # Return parent builder if there is one
        return $parent_builder if $parent_builder;

        # Otherwise, finalize the UI and return the root element
        return $element;
    }
}

1;
