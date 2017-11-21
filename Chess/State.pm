package Chess::State;
use strict;
use warnings;
use v5.010;

=pod

=head1 NAME

Chess::State - an object that stores board state for a chess game

=head1 SYNOPSIS

    use Chess::State;

    my $state = Chess::State->new;
    $state->pp;

=head1 DESCRIPTION

This is a class that stores chess state.

Internally, board state is kept as an 8x8 array of pieces.

=head2 Members

=over 12

=item C<turn>

Return true if it's Black's turn, false otherwise.

=back

=head2 Methods

=over 12

=item C<new>

Returns a new Chess::State object.

An optional FEN string can be passed as a parameter.  If omitted,
the standard Chess starting position is used.

=item C<set_fen>

Replaces the internal state of a Chess::State object with that
from the provided FEN string.

=item C<get_fen>

Exports the current state as a FEN string.

=item C<get_moves>

Returns an array containing legal Chess::Move objects.

=item C<is_playable>

Returns 1 if there are legal moves available, 0 otherwise.

=item C<make_move>

Given a single parameter (Chess::Move object), it will make the
move, and return a new State object with the updated board.

=item C<pp>

Pretty-prints a board and available moves.

This is mainly a debugging function.

=back

=head1 LICENSE

This is released under the Artistic License. See L<perlartistic>.

=head1 AUTHOR

Greg Kennedy - L<https://greg-kennedy.com/>

=head1 SEE ALSO

L<https://en.wikipedia.org/wiki/Chess_Engine>

=cut

use Carp qw(confess);
# min and max
use List::Util qw[min max];

# move class
use Chess::Move;

##########################################################
# SOME CONSTANTS
use constant {
  WHITE => 0,
  BLACK => 1,

  CASTLE_KING => 0,
  CASTLE_QUEEN => 1,

  COLOR_BIT => 0x20,
  TYPE_MASK => 0xDF,
}; 

##########################################################
# BOARD STATE CLASS
sub new {
  my $class = shift;

  my $initialFEN = shift;

  # empty object with defaults
  my %self;

  if (!defined $initialFEN) {
    # initialize self to starting FEN
    $initialFEN = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
  }

  # Apply initial FEN to set board position / state
  set_fen(\%self, $initialFEN);

  # Bless this class and return
  return bless \%self, $class;
}

# DEBUG - Pretty-print a Board and available moves.
sub pp {
  my $self = shift;

  # header
  say $self->get_fen;
  # check for check
  say ($self->is_check ? "IN CHECK" : "(not in check)");
  # board image
  say '+-+-+-+-+-+-+-+-+';
  for my $rank (0 .. 7) {
    for my $file (0 .. 7) {
      my $piece = $self->{board}[7 - $rank][$file];
      printf("|%1c", ($piece ? $piece : ord(($file + ($rank % 2)) % 2 ? '.' : ' ')));
    }
    printf("|%d\n", 8 - $rank);
    say "+-+-+-+-+-+-+-+-+";
  }
  say " a b c d e f g h";

  # list all possible moves
  foreach my $move ($self->get_moves) {
    my $str = $move->to_string();
    my $from = substr($str, 0, 2);
    my $to = substr($str, 2, 2);

    print " " . chr($move->[Chess::Move::FROM_PIECE]) . " $from -> $to";
    if (defined $move->[Chess::Move::PROMOTION_PIECE]) { print " [" . chr($move->[Chess::Move::PROMOTION_PIECE]) . "] "; }
    if (defined $move->[Chess::Move::TO_PIECE]) { print " x " . chr($move->[Chess::Move::TO_PIECE]); }
    print "\n";
  }
}

sub is_playable {
  return (scalar $_[0]->get_moves > 0);
}
sub is_check {
  return check($_[0]->{board}, $_[0]->{turn});
}

##############################################################################
# ENGINE INTERFACE
#  An engine would use these functions

# Returns all generated moves, but without testing for move-into-check legality
sub get_pseudo_moves {
  my $self = shift;
  if (!defined $self->{pseudo_moves}) {
    $self->{pseudo_moves} = generate_moves($self->{board}, $self->{turn});
  }
  return @{$self->{pseudo_moves}};
}

# Given a Chess::Move, return a new board.
#  This function does not verify legality, but it will check threats afterwards.
#  Returns undef if moving into check.
sub force_move {
  my $self = shift;

  # Assume the move is good.
  my $move = shift;

  # Piece was not a promotion, so use the existing one from_ position
  my $piece = $move->[Chess::Move::PROMOTION_PIECE] || $move->[Chess::Move::FROM_PIECE];

  # Construct a new board by duplicating the old
  my @board;
  for my $rank (0 .. 7) {
    push @board, [ @{$self->{board}[$rank]} ];
  }

  # Issue the move
  $board[$move->[Chess::Move::FROM_RANK]][$move->[Chess::Move::FROM_FILE]] = 0;
  $board[$move->[Chess::Move::TO_RANK]][$move->[Chess::Move::TO_FILE]] = $piece;

  # Test for legality.
  return undef if check(\@board, $self->{turn});

  # A new State object, holds the updated board... and flip the turn.
  my %new_state;

  $new_state{board} = \@board;
  $new_state{turn} = $self->{turn} ^ COLOR_BIT;

  # TODO
  $new_state{castle} = [ @{$self->{castle}} ];
  # TODO
  $new_state{ep} = (defined $self->{ep} ? [ @{$self->{ep}} ] : undef);

  if (($move->[Chess::Move::FROM_PIECE] & TYPE_MASK) == ord 'P' || defined $move->[Chess::Move::TO_PIECE])
  {
    # reset halfmove to 0 if we moved a pawn or made a capture
    $new_state{halfmove} = 0;
  } else {
    # increment halfmove
    $new_state{halfmove} = $self->{halfmove} + 1;
  }

  $new_state{move} = $self->{move};
  if ($self->{turn}) {
    # increment overall move counter if it's white's turn again
    $new_state{move} ++;
  }

  # Bless this class and return
  return bless \%new_state, ref $self;
}

##############################################################################
# HUMAN INTERFACE
#  Some helper functions for allowing a human to play

# This generates pseudolegal moves, then filters the list by attempting each
sub get_moves {
  my $self = shift;
  if (!defined $self->{move_list}) {
    #say "move_list not defined, calling and testing.";
    $self->{move_list} = [ grep { defined ($self->force_move($_)) } $self->get_pseudo_moves ]
  }
  return @{$self->{move_list}};
}

# Given a Chess::Move, return a new board.
#  This function will check that the move is in the list of legal moves first.
sub make_move {
  my $self = shift;

  # Ensure move was in the list of legal moves.
  my $user_move = shift;

  # retrieve list of possible moves
  my $move;
  foreach ($self->get_moves) {
    if ($user_move->equals($_)) {
      $move = $_;
      last;
    }
  }
  confess "Illegal move " . $user_move->to_string unless defined $move;

  return $self->force_move($move);
}

##############################################################################
# MOVE GENERATION
##############################################################################

# Determine if a piece is owned by owner
sub _is_my_piece {
  return (($_[0] & COLOR_BIT) == $_[1]);
  #return (($_[0] ^ $_[1]) & COLOR_BIT);
}

# Given a board and a turn, determine if the piece is attacked.
# Return 1 if the current player is in check.
sub check {
  my ($board, $turn) = @_;

  # Locate the current player's King on the board.
  for my $rank (0 .. 7) {
    for my $file (0 .. 7) {
      my $piece = $board->[$rank][$file];
      if ($piece && (($piece & TYPE_MASK) == ord 'K') && _is_my_piece($piece, $turn)) {
        # Found the King.
        my $p;
        my $t;
        # check surrounding squares (pawn, king, rook, queen, bishop attack)
        if ($file > 0) {
          if ($rank > 0) {
            $p = $board->[$rank - 1][$file - 1]; $t = $p & TYPE_MASK;
            return 1 if ($p && ! _is_my_piece($p, $turn) && ($t == ord 'K' || $t == ord 'Q' || $t == ord 'B' || $p == ord 'p'));
          }
          $p = $board->[$rank][$file - 1]; $t = $p & TYPE_MASK;
          return 1 if ($p && ! _is_my_piece($p, $turn) && ($t == ord 'K' || $t == ord 'Q' || $t == ord 'R'));
          if ($rank < 7) {
            $p = $board->[$rank + 1][$file - 1]; $t = $p & TYPE_MASK;
            return 1 if ($p && ! _is_my_piece($p, $turn) && ($t == ord 'K' || $t == ord 'Q' || $t == ord 'B' || $p == ord 'p'));
          }
        }
        if ($rank > 0) {
          $p = $board->[$rank - 1][$file]; $t = $p & TYPE_MASK;
          return 1 if (($p && ! _is_my_piece($p, $turn)) && ($t == ord 'K' || $t == ord 'Q' || $t == ord 'R'));
        }
        if ($rank < 7) {
          $p = $board->[$rank + 1][$file]; $t = $p & TYPE_MASK;
          return 1 if (($p && ! _is_my_piece($p, $turn)) && ($t == ord 'K' || $t == ord 'Q' || $t == ord 'R'));
        }
        if ($file < 7) {
          if ($rank > 0) {
            $p = $board->[$rank - 1][$file + 1]; $t = $p & TYPE_MASK;
            return 1 if (($p && ! _is_my_piece($p, $turn)) && ($t == ord 'K' || $t == ord 'Q' || $t == ord 'B' || $p == ord 'P'));
          }
          $p = $board->[$rank][$file + 1]; $t = $p & TYPE_MASK;
          return 1 if (($p && ! _is_my_piece($p, $turn)) && ($t == ord 'K' || $t == ord 'Q' || $t == ord 'R'));
          if ($rank < 7) {
            $p = $board->[$rank + 1][$file + 1]; $t = $p & TYPE_MASK;
            return 1 if (($p && ! _is_my_piece($p, $turn)) && ($t == ord 'K' || $t == ord 'Q' || $t == ord 'B' || $p == ord 'P'));
          }
        }
      
        # check knight attacks from here
        foreach my $target ( [-1, -2], [1, -2], [-2, -1], [2, -1], [-2, 1], [2, 1], [-1, 2], [1, 2] )
        {
          my $target_rank = $rank + $target->[0];
          my $target_file = $file + $target->[1];
          if ($target_rank >= 0 && $target_rank <= 7 && $target_file >= 0 && $target_file <= 7) {
            $p = $board->[$target_rank][$target_file]; $t = $p & TYPE_MASK;
            return 1 if (($p && ! _is_my_piece($p, $turn)) && ($t == ord 'N'));
          }
        }
      
        # more distant attacks
        # check if attack by rook or queen
        my $target_rank;
        my $target_file;
      
        # inc. rank
        for (my $target_rank = $rank + 1; $target_rank < 8; $target_rank ++) {
          next unless ($p = $board->[$target_rank][$file]); $t = $p & TYPE_MASK;
          return 1 if (($p && ! _is_my_piece($p, $turn)) && ($t == ord 'Q' || $t == ord 'R'));
          last;
        }
        # dec. rank
        for (my $target_rank = $rank - 1; $target_rank >= 0; $target_rank --) {
          next unless ($p = $board->[$target_rank][$file]); $t = $p & TYPE_MASK;
          return 1 if (($p && ! _is_my_piece($p, $turn)) && ($t == ord 'Q' || $t == ord 'R'));
          last;
        }
        # inc. file
        for (my $target_file = $file + 1; $target_file < 8; $target_file ++) {
          next unless ($p = $board->[$rank][$target_file]); $t = $p & TYPE_MASK;
          return 1 if (($p && ! _is_my_piece($p, $turn)) && ($t == ord 'Q' || $t == ord 'R'));
          last;
        }
        # dec. file
        for (my $target_file = $file - 1; $target_file >= 0; $target_file --) {
          next unless ($p = $board->[$rank][$target_file]); $t = $p & TYPE_MASK;
          return 1 if (($p && ! _is_my_piece($p, $turn)) && ($t == ord 'Q' || $t == ord 'R'));
          last;
        }
      
        # bishop and queen
        # back and left
        $target_rank = $rank + 1; $target_file = $file + 1;
        while ( $target_rank < 8 && $target_file < 8 ) {
          $p = $board->[$target_rank][$target_file];
          $target_rank ++; $target_file ++;
          next unless $p;
      
          $t = $p & TYPE_MASK;
          return 1 if (($p && ! _is_my_piece($p, $turn)) && ($t == ord 'Q' || $t == ord 'B'));
          last;
        }
      
        # back and right
        $target_rank = $rank + 1; $target_file = $file - 1;
        while ( $target_rank < 8 && $target_file >= 0 ) {
          $p = $board->[$target_rank][$target_file];
          $target_rank ++; $target_file --;
          next unless $p;
      
          $t = $p & TYPE_MASK;
          return 1 if (($p && ! _is_my_piece($p, $turn)) && ($t == ord 'Q' || $t == ord 'B'));
          last;
        }
      
        # fore and right
        $target_rank = $rank - 1; $target_file = $file + 1;
        while ( $target_rank >= 0 && $target_file < 8 ) {
          $p = $board->[$target_rank][$target_file];
          $target_rank --; $target_file ++;
          next unless $p;
      
          $t = $p & TYPE_MASK;
          return 1 if (($p && ! _is_my_piece($p, $turn)) && ($t == ord 'Q' || $t == ord 'B'));
          last;
        }
      
        # fore and left
        $target_rank = $rank - 1; $target_file = $file - 1;
        while ( $target_rank >= 0 && $target_file >= 0 ) {
          $p = $board->[$target_rank][$target_file];
          $target_rank --; $target_file --;
          next unless $p;
      
          $t = $p & TYPE_MASK;
          return 1 if (($p && ! _is_my_piece($p, $turn)) && ($t == ord 'Q' || $t == ord 'B'));
          last;
        }
      
        # square is safe...
        return 0;
      }
    }
  }

}

# Queen is the sum of rook and bishop
#  So wrap their moves in functions
sub generate_rook_moves {
  my ($board, $rank, $file, $turn) = @_;

  my $from = $board->[$rank][$file];

  my @possible_moves;

  # inc. rank
  for (my $target_rank = $rank + 1; $target_rank < 8; $target_rank ++) {
    my $to = $board->[$target_rank][$file];
    if (! $to) { push @possible_moves, Chess::Move->new($rank, $file, $target_rank, $file, undef, $from) }
    else {
      if (! _is_my_piece($to, $turn)) { push @possible_moves, Chess::Move->new($rank, $file, $target_rank, $file, undef, $from, $to) }
      last;
    }
  }
  # dec. rank
  for (my $target_rank = $rank - 1; $target_rank >= 0; $target_rank --) {
    my $to = $board->[$target_rank][$file];
    if (! $to) { push @possible_moves, Chess::Move->new($rank, $file, $target_rank, $file, undef, $from) }
    else {
      if (! _is_my_piece($to, $turn)) { push @possible_moves, Chess::Move->new($rank, $file, $target_rank, $file, undef, $from, $to) }
      last;
    }
  }
  # inc. file
  for (my $target_file = $file + 1; $target_file < 8; $target_file ++) {
    my $to = $board->[$rank][$target_file];
    if (! $to) { push @possible_moves, Chess::Move->new($rank, $file, $rank, $target_file, undef, $from) }
    else {
      if (! _is_my_piece($to, $turn)) { push @possible_moves, Chess::Move->new($rank, $file, $rank, $target_file, undef, $from, $to) }
      last;
    }
  }
  # dec. file
  for (my $target_file = $file - 1; $target_file >= 0; $target_file --) {
    my $to = $board->[$rank][$target_file];
    if (! $to) { push @possible_moves, Chess::Move->new($rank, $file, $rank, $target_file, undef, $from) }
    else {
      if (! _is_my_piece($to, $turn)) { push @possible_moves, Chess::Move->new($rank, $file, $rank, $target_file, undef, $from, $to) }
      last;
    }
  }

  return @possible_moves;
}

sub generate_bishop_moves {
  my ($board, $rank, $file, $turn) = @_;

  my ($target_rank, $target_file);

  my $from = $board->[$rank][$file];

  my @possible_moves;

  # fore and left
  $target_rank = $rank + 1; $target_file = $file + 1;
  while ($target_rank < 8 && $target_file < 8) {
    my $to = $board->[$target_rank][$target_file];
    if (! $to) { push @possible_moves, Chess::Move->new($rank, $file, $target_rank, $target_file, undef, $from) }
    else {
      if (! _is_my_piece($to, $turn)) { push @possible_moves, Chess::Move->new($rank, $file, $target_rank, $target_file, undef, $from, $to) }
      last;
    }
    $target_rank ++; $target_file ++;
  }

  # back and left
  $target_rank = $rank + 1; $target_file = $file - 1;
  while ($target_rank < 8 && $target_file >= 0) {
    my $to = $board->[$target_rank][$target_file];
    if (! $to) { push @possible_moves, Chess::Move->new($rank, $file, $target_rank, $target_file, undef, $from) }
    else {
      if (! _is_my_piece($to, $turn)) { push @possible_moves, Chess::Move->new($rank, $file, $target_rank, $target_file, undef, $from, $to) }
      last;
    }
    $target_rank ++; $target_file --;
  }

  # fore and right
  $target_rank = $rank - 1; $target_file = $file + 1;
  while ($target_rank >= 0 && $target_file < 8) {
    my $to = $board->[$target_rank][$target_file];
    if (! $to) { push @possible_moves, Chess::Move->new($rank, $file, $target_rank, $target_file, undef, $from) }
    else {
      if (! _is_my_piece($to, $turn)) { push @possible_moves, Chess::Move->new($rank, $file, $target_rank, $target_file, undef, $from, $to) }
      last;
    }
    $target_rank --; $target_file ++;
  }

  # back and right
  $target_rank = $rank - 1; $target_file = $file - 1;
  while ($target_rank >= 0 && $target_file >= 0) {
    my $to = $board->[$target_rank][$target_file];
    if (! $to) { push @possible_moves, Chess::Move->new($rank, $file, $target_rank, $target_file, undef, $from) }
    else {
      if (! _is_my_piece($to, $turn)) { push @possible_moves, Chess::Move->new($rank, $file, $target_rank, $target_file, undef, $from, $to) }
      last;
    }
    $target_rank --; $target_file --;
  }

  return @possible_moves;
}

# Given a board, return
#  all possible legal moves.
sub generate_moves {
  my ($board, $turn) = @_;

  # Begin with an empty list of potential moves.
  my @possible_moves;

  # Iterate through each piece on the board.
  for my $rank (0 .. 7) {
    for my $file (0 .. 7) {
      my $piece = $board->[$rank][$file];

      # Skip blank square and opponent pieces
      next unless $piece && _is_my_piece($piece, $turn);

      # Compute all possible moves.
      my $type = $piece & TYPE_MASK;
      if ($type == ord 'K') {
        # King can move to one of 8 directions, as long as
        #  it does not step out of bounds, and does not step on a friendly piece.
        for (my $target_rank = max(0, $rank-1); $target_rank <= min(7, $rank+1); $target_rank ++) {
          for (my $target_file = max(0, $file-1); $target_file <= min(7, $file+1); $target_file ++) {
            next if ($target_rank == $rank && $target_file == $file);
            my $p = $board->[$target_rank][$target_file];
            if (! $p || ! _is_my_piece($p, $turn)) {
              push @possible_moves, Chess::Move->new($rank, $file, $target_rank, $target_file, undef, $piece, $p);
            }
          }
        }
        # TODO: Castling
      } elsif ($type == ord 'R') {
        # Rook: call the subfunction
        push @possible_moves, generate_rook_moves($board, $rank, $file, $turn);
      } elsif ($type == ord 'B') {
        # Bishop: call the subfunction
        push @possible_moves, generate_bishop_moves($board, $rank, $file, $turn);
      } elsif ($type == ord 'Q') {
        # Queen: get moves for a bishop or a rook
        push @possible_moves,
          generate_rook_moves($board, $rank, $file, $turn),
          generate_bishop_moves($board, $rank, $file, $turn);
      } elsif ($type == ord 'N') {
        # Knight
        foreach my $target ([-1, -2], [1, -2], [-2, -1], [2, -1], [-2, 1], [2, 1], [-1, 2], [1, 2]) {
          my $target_rank = $rank + $target->[0];
          my $target_file = $file + $target->[1];
          if ($target_rank >= 0 && $target_rank <= 7 && $target_file >= 0 && $target_file <= 7) {
            my $p = $board->[$target_rank][$target_file];
            if (! $p || ! _is_my_piece($p, $turn)) {
              push @possible_moves, Chess::Move->new($rank, $file, $target_rank, $target_file, undef, $piece, $p);
            }
          }
        }
      } elsif ($type == ord 'P') {
        # Pawn
        #  Attempt a one-space-forward move (and note the piece color)
        my $step = ( $turn ? -1 : 1 );

        my $target_rank = $rank + $step;
        if (! $board->[$target_rank][$file]) {
          if ($target_rank == 7) {
            # end of board for white!  Promote.
            push @possible_moves,
              Chess::Move->new($rank, $file, $target_rank, $file, ord 'B', $piece),
              Chess::Move->new($rank, $file, $target_rank, $file, ord 'N', $piece),
              Chess::Move->new($rank, $file, $target_rank, $file, ord 'Q', $piece),
              Chess::Move->new($rank, $file, $target_rank, $file, ord 'R', $piece);
          } elsif ($target_rank == 0) {
            # end of board for black!  Promote.
            push @possible_moves,
              Chess::Move->new($rank, $file, $target_rank, $file, ord 'b', $piece),
              Chess::Move->new($rank, $file, $target_rank, $file, ord 'n', $piece),
              Chess::Move->new($rank, $file, $target_rank, $file, ord 'q', $piece),
              Chess::Move->new($rank, $file, $target_rank, $file, ord 'r', $piece);
          } else {
            push @possible_moves, Chess::Move->new($rank, $file, $target_rank, $file, undef, $piece);

            # Also, if we are on rank 2, we can try a double-push.
            if ((! $turn && $rank == 1) ||
                ($turn && $rank == 6))
            {
              if (! $board->[$target_rank + $step][$file]) {
                # TODO: log EP?
                push @possible_moves, Chess::Move->new($rank, $file, $target_rank + $step, $file, undef, $piece);
              }
            }
          }
        }

        # Try a capture instead.
        for my $target (-1, 1)
        {
          # TODO: EP
          my $target_file = $file + $target;

          next if ($target_file < 0 || $target_file > 7);

          # check ownership by opponent.
          my $p = $board->[$target_rank][$target_file];
          if ($p && ! _is_my_piece($p, $turn)) {
            if ($target_rank == 7) {
              # end of board for white!  Promote.
              push @possible_moves,
                Chess::Move->new($rank, $file, $target_rank, $target_file, ord 'B', $piece, $p),
                Chess::Move->new($rank, $file, $target_rank, $target_file, ord 'N', $piece, $p),
                Chess::Move->new($rank, $file, $target_rank, $target_file, ord 'Q', $piece, $p),
                Chess::Move->new($rank, $file, $target_rank, $target_file, ord 'R', $piece, $p);
            } elsif ($target_rank == 0) {
              # end of board for black!  Promote.
              push @possible_moves,
                Chess::Move->new($rank, $file, $target_rank, $target_file, ord 'b', $piece, $p),
                Chess::Move->new($rank, $file, $target_rank, $target_file, ord 'n', $piece, $p),
                Chess::Move->new($rank, $file, $target_rank, $target_file, ord 'q', $piece, $p),
                Chess::Move->new($rank, $file, $target_rank, $target_file, ord 'r', $piece, $p);
            } else {
              push @possible_moves, Chess::Move->new($rank, $file, $target_rank, $target_file, undef, $piece, $p);
            }
          }
        }
      }
    }
  }

  return \@possible_moves;
}


# Parse a FEN string and replace internal state with it
sub set_fen {
  my $self = shift;

  # Split FEN into the six components
  my ($placement, $turn, $castle, $ep, $clock, $move) = split /\s+/, $_[0], 6;

  # Begin with an empty board
  my @board;
  for my $rank (0 .. 7) {
    for my $file (0 .. 7) {
      $board[$rank][$file] = 0;
    }
  }

  # King location cache
  #my @kings = ( undef, undef );

  # Fill board with proper piece positions
  my @rows = split /\//, $placement, 8;
  for my $rank (0 .. 7) {
    my $file = 0;
    foreach my $code (split //, $rows[7 - $rank]) {
      # Is a piece value
      if ($code =~ m/^[BKNPQRbknpqr]$/)
      {
        # store everything as ords here
        $board[$rank][$file] = ord($code);
        # Log kings
        #if ($code eq 'K') { $kings[0] = [$rank, $file] }
        #elsif ($code eq 'k') { $kings[1] = [$rank, $file] }

        # Next square
        $file ++;
      } elsif ($code =~ m/^[1-8]$/) {
        # "Skip" (digit, just advance)
        $file += $code;
      } else {
        confess "Illegal character $code in FEN string";
      }
    }
  }

  #confess "This FEN is missing a white King" unless defined $kings[0];
  #confess "This FEN is missing a black King" unless defined $kings[1];

  # Set (overwrite) board
  $self->{board} = \@board;
  # Kings
  #$self->{kings} = \@kings;
  # Whose turn?
  $self->{turn} = (defined $turn && lc($turn) eq 'b' ? COLOR_BIT : 0);
  # Castle
  $self->{castle} = [ [0, 0], [0, 0] ];
  if (defined $castle) {
    foreach my $c (split //, $castle) {
      if ($c eq 'K') { $self->{castle}[0][0] = 1 }
      elsif ($c eq 'Q') { $self->{castle}[0][1] = 1 }
      elsif ($c eq 'k') { $self->{castle}[1][0] = 1 }
      elsif ($c eq 'q') { $self->{castle}[1][1] = 1 }
    }
  }
  # EP
  $ep = lc($ep // '-');
  if ($ep !~ m/^[a-h][1-8]$/) {
    $self->{ep} = undef;
  } else {
    my $file = ord(substr($ep, 0, 1)) - ord('a');
    my $rank = ord(substr($ep, 1, 1)) - ord('1');
    $self->{ep} = [$rank, $file];
  }
  # Halfmove clock
  $self->{halfmove} = $clock || 0;
  # Move number
  $self->{move} = $move || 1;
}

# Return a FEN string representing the current game state
sub get_fen {
  my $self = shift;

  # Returns the board-state in FEN notation
  my $placement = '';
  # Scan from back to front
  for (my $rank = 7; $rank >= 0; $rank --) {
    my $skip = 0;
    # Scan across file left-right
    for my $file (0 .. 7) {
      my $piece = $self->{board}[$rank][$file];
      if ($piece) {
        # Indicate a piece at this location.  If we had stepped over any, indicate spacing.
        if ($skip > 0) {
          $placement .= $skip;
          $skip = 0;
        }
        $placement .= chr($piece);
      } else {
        $skip ++;
      }
    }
    if ($skip > 0) {
      # Pad remaining squares
      $placement .= $skip;
    }
    if ($rank > 0) {
      # Rank delimiter
      $placement .= '/';
    }
  }

  # Castle
  my $castle = '';
  if ($self->{castle}[WHITE][CASTLE_KING]) { $castle .= 'K' }
  if ($self->{castle}[WHITE][CASTLE_QUEEN]) { $castle .= 'Q' }
  if ($self->{castle}[BLACK][CASTLE_KING]) { $castle .= 'k' }
  if ($self->{castle}[BLACK][CASTLE_QUEEN]) { $castle .= 'q' }
  if ($castle eq '') { $castle = '-' }

  # EP
  my $ep;
  if (defined $self->{ep}) {
    $ep = chr(ord('a') + $self->{ep}[1]) . chr(ord('1') + $self->{ep}[0]);
  } else {
    $ep = '-';
  }

  return join(' ',
    $placement,
    ($self->{turn} ? 'b' : 'w'),
    $castle,
    $ep,
    $self->{halfmove},
    $self->{move}
  );
}

1;
