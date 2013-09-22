use strict;
use warnings;

use GraphViz::Data::Structure;

my $data_structure = {
    a => [ 1, 2, 3 ],
    b => [
        { X => 1, Y => 2 },
        {
            X => [ 1, 2, 3 ],
            Y => [ 4, 5, 6 ],
            Z => [ 7, 8, 9 ]
        },
    ],
};

my $gvds =
  GraphViz::Data::Structure->new( $data_structure, Orientation => 'vertical' );
print $gvds->graph()->as_png("gvds.png");


