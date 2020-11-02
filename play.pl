#!/usr/bin/env perl
use strict;
use warnings;

## LOCAL MODULES
# make local dir accessible for use statements
use FindBin qw( $RealBin );
use lib $RealBin;

use Chess::Move;
use Chess::State;
use Chess::Engine;

# debug
use Data::Dumper;

# setup board
#  use default PGN
#my $state = Chess::State->new('8/3k1q2/8/8/8/3K4/1r3R2/8 w - -');
my $state = Chess::State->new('8/3k4/8/8/8/3K4/1R3R2/8 w - -');
#my $state = Chess::State->new;
# attach engine
#  plays black, maxdepth 3
my $engine = Chess::Engine->new(\$state, 1, 3);

while ($state->is_playable)
{
  # Pretty-print board
  $state->pp;

  my $move;
  if (! $state->{turn})
  {
    # Show prompt and get input from user
#    print $engine->think->to_string . "\n";
    print "> ";
    my $input = <STDIN>;
    chomp $input;
  
    # Attempt to create a move object
    $move = eval { Chess::Move->new($input) };
    if (! defined $move) {
      print "Error: " . $@ . "\n";
      redo;
    }
  
  } else {
    # Computer's turn!
    $move = eval { $engine->think };
    if (! defined $move) {
      print "Error: " . $@ . "\n";
      redo;
    }
    print "> " . $move->to_string . "\n";
  }

  # Attempt to apply the move.
  my $new_state = eval { $state->make_move($move) };
  if (! defined $new_state) {
    print "Error: " . $@ . "\n";
    redo;
  }

  $state = $new_state;
}
