package Chess::Engine;
use strict;
use warnings;

=pod

=head1 NAME

Chess::Engine - an AI that plays chess.

=head1 SYNOPSIS

    use Chess::Engine;
    use Chess::State;

    my $state = Chess::State->new;
    my $engine = Chess::Engine->new(\$state, 1, 3);

    $move = $engine->think;
    $state = $state->make_move($move);

=head1 DESCRIPTION

This is a class that plays Chess.

It implements the Min-Max algorithm with Alpha Beta pruning, and does
depth-first of positions to determine moves.

The evaluator function is a simple piece-scoring routine.

The engine is attached to a "state" and can suggest best moves on behalf
of the player it is assigned as.  (In other words, it can play against
itself by creating two instances and attaching to the same state).

=head2 Methods

=over 12

=item C<new>

Returns a new Chess::Engine object.

Three parameters are needed:

* State - a reference to a Chess::State object, which is the game to be played
  by the engine.
* Player - Which color the AI should play.  0 for White (default), 1 for Black.
* Depth - Maximum depth (ply) to look ahead for positions.  Defaults to 3.

=item C<think>

Calls a recursive search function to find the best move, and returns it.

It doesn't make sense to call think when it's not the AI's turn.

=back

=head1 LICENSE

This is released under the Artistic License. See L<perlartistic>.

=head1 AUTHOR

Greg Kennedy - L<https://greg-kennedy.com/>

=head1 SEE ALSO

L<https://en.wikipedia.org/wiki/Chess_Engine>

=cut

use Chess::Move;
use Chess::State;

# Construct a new Engine object.
#  You MUST pass in a reference to a state.
# Optionally specify a color and a max-ply.
sub new {
  my $class = shift;

  # empty object with defaults
  my %self;
  $self{state} = shift || die "Cannot instantiate Chess::Engine without a Chess::State";
  $self{player} = (shift || 0 ? 0x20 : 0);
  $self{depth} = shift || 3;

  # Bless this class and return
  return bless \%self, $class;
}

# Simple evaluation function
#  Count point values for each piece on board
# Values are from the POV of White, so need invert
#  if playing Black
my %piece_values = (
  ord 'k' => -559,
  ord 'p' => -1,
  ord 'b' => -3,
  ord 'n' => -3,
  ord 'r' => -5,
  ord 'q' => -9,
  ord 'K' => 559,
  ord 'P' => 1,
  ord 'B' => 3,
  ord 'N' => 3,
  ord 'R' => 5,
  ord 'Q' => 9,
  0 => 0
);

# Recursive "think" that uses only board state, not self.
sub _rec_think {
  my $state = shift;
  my $player = shift;

  my $depth = shift;
  my $max_depth = shift;

  # Reached maximum depth, return the value at this point
  if ($depth > $max_depth) {
    my $value = 0;
 
    for my $rank (0 .. 7) {
      for my $file (0 .. 7) {
        $value += $piece_values{$state->{board}[$rank][$file]};
      }
    }

    if ($player) { $value = -$value }

#    print ("-" x $depth);
#    print "> Dep: $depth, Score: $value\n";

    return (undef, $value);
  }

  # Some intermediate state.
  #  Figure out the best move for this player.

  # Get all available moves
  my $best_move;
  my $best_value;

  foreach my $move ($state->get_pseudo_moves) {
    print ("-" x $depth);
    print "> Trying " . $move->to_string . "\n";

    my $new_state = $state->force_move($move);
    if (defined $new_state) {
      my ($sub_best_move, $sub_best_value) = _rec_think($new_state, $player, $depth + 1, $max_depth);

      # Replace best move with this one, depending on who is making the move
      if (! defined($best_value) ||
        (($state->{turn} == $player) && ($sub_best_value > $best_value)) ||
        (($state->{turn} != $player) && ($sub_best_value < $best_value))
      ) {
        $best_move = $move;
        $best_value = $sub_best_value;
      }
    }
  }

  # Dead end if we didn't make any valid moves
  if (!defined $best_value)
  {
    # We in check?
    print ("-" x $depth);
    print "> RESULT: ";
    if ($state->is_check) {
      if ($state->{turn}) {
        # checkmate, current player lost
        print "CHECKMATE for Black.\n";
        return (undef, $piece_values{ord 'k'});
      } else {
        print "CHECKMATE for White.\n";
        return (undef, $piece_values{ord 'K'});
      }
    } else {
      # stalemate, hard 0
      print "STALEMATE.\n";
      return (undef, 0);
    }
  }

  print ("-" x $depth);
  print "> RESULT: Best move for " . ($state->{turn} ? 'Black' : 'White') . " is " . $best_move->to_string . " (worth: " . $best_value . ")\n";

  return ($best_move, $best_value);
}

# Given a state,
#  return what I think is the best move.
# This is mainly a converience wrapper around rec_think.
sub think {
  my $self = shift;

  my ($move, $score) = _rec_think(${$self->{state}}, $self->{player}, 0, $self->{depth});
  return $move;
}

1;
