#!/usr/bin/env perl
use v5.10;
use strict;
use warnings;

## perft.pl
# Calculates node depths for positions up to specified depth.
# Used for testing move-generation routines.
use Time::HiRes qw/ clock /;

use Chess::State;

# Some sample perft tests
my @positions = (
  'r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq -',
  '8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - -',
  'r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1',
  'rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8',
  'r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10'
);


##############################################################################
## COUNTERS
my @count;
## Recursive move-and-count routine
sub rec_perft {
  my $state = shift;
  my $max_depth = shift;
  my $depth = 1 + (shift || 0);

  # check moves, increment counters
  foreach my $move ($state->get_pseudo_moves) {
    my $new_state = $state->force_move($move);

    if (defined $new_state) {
      $count[$depth]{nodes} ++;
      if (defined $move->[Chess::Move::TO_PIECE]) {
        $count[$depth]{captures} ++
      }

      if ($max_depth > $depth) {
        # still room for more, make the move and count the results.
        rec_perft($new_state, $max_depth, $depth);
      }
    }
  }
}

##############################################################################
## Global max depth
my $max_depth = $ARGV[0] || die "Must specify a perft depth";

# setup board
my $state;
if (defined $ARGV[1]) {
  $state = Chess::State->new($positions[$ARGV[1]]);
} else {
  $state = Chess::State->new;
}

# call perft routine
my $start_time = clock;
rec_perft($state,$max_depth);
my $end_time = clock;

# print results
say "Results (Elapsed " . ($end_time - $start_time) . " seconds)";
for (my $i = 0; $i < scalar @count; $i ++)
{
  say "======================================================================";
  say "	Depth $i:";
  say "		nodes: " . ($count[$i]{nodes} || 0);
  say "		captures: " . ($count[$i]{captures} || 0);
  say "		ep: " . ($count[$i]{ep} || 0);
  say "		castles: " . ($count[$i]{castles} || 0);
  say "		promotions: " . ($count[$i]{promotions} || 0);
  say "		checks: " . ($count[$i]{checks} || 0);
  say "		checkmates: " . ($count[$i]{checkmates} || 0);
}
