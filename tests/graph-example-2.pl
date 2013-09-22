use strict;
use warnings;

use GraphViz::Data::Grapher;

my $structure = {
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

my $graph = GraphViz::Data::Grapher->new($structure);
print $graph->as_png("gvdg.png");


