#!/usr/bin/env perl
use v5.10;
use strict;
use warnings;

use Chess::Move;
use Chess::State;

##########################################################################3
#use List::Util qw[min max];

# chooses a random sentence from an array
sub pick { return $_[int(rand(@_))]; }
sub chance { return rand(1) < $_[0]; }
# Text output functions
sub square{
  return sprintf('%c%c', $_[1] + ord 'a', $_[0] + ord '1');
}
sub owner {
  return ($_[0] & 0x20 ? 'her' : 'his');
}
sub pro {
  return ($_[0] & 0x20 ? 'she' : 'he');
}
sub name {
  return ($_[0] & 0x20 ? 'Maude' : 'Harold');
}
sub color {
  return ($_[0] & 0x20 ? 'Black' : 'White');
}
sub piece {
  my $t = $_[0] & 0xDF;
  if ($t == ord 'B') {
    return 'Bishop';
  } elsif ($t == ord 'K') {
    return 'King';
  } elsif ($t == ord 'N') {
    return 'Knight';
  } elsif ($t == ord 'P') {
    return 'Pawn';
  } elsif ($t == ord 'Q') {
    return 'Queen';
  } elsif ($t == ord 'R') {
    return 'Rook';
  }

  die "Unknown piece type $t...";
}

sub color_piece {
  return color($_[0]) . ' ' . piece($_[0]);
}
sub owner_piece {
  return owner($_[0]) . ' ' . piece($_[0]);
}

# Simple evaluation function
#  Count point values for each piece on board
# Values are from the POV of White, so need invert
#  if playing Black
my %piece_values = (
  ord 'k' => -55900,
  ord 'p' => -100,
  ord 'b' => -350,
  ord 'n' => -350,
  ord 'r' => -500,
  ord 'q' => -900,
  ord 'K' => 55900,
  ord 'P' => 100,
  ord 'B' => 350,
  ord 'N' => 350,
  ord 'R' => 500,
  ord 'Q' => 900,
  0 => 0
);

# Recursive "think" that uses only board state, not self.
sub recurse {
  my $fh = shift;
  my $state = shift;

  my $alpha = shift;
  my $beta = shift;

  my $depth = shift;
  my $max_depth = shift;

  # Dead end if we didn't make any valid moves
  if (scalar $state->get_moves == 0) {
    # We in check?
    if ($state->is_check) {
      print $fh 'That would be Checkmate for ' . pick(name($state->{turn}), color($state->{turn})) . ".\n\n";
      if ($state->{turn}) {
        # checkmate, current player lost
        return $piece_values{ord 'k'};
      } else {
        return $piece_values{ord 'K'};
      }
    } else {
      # stalemate, hard 0
      print $fh "That would end the game in a Stalemate.\n\n";
      return 0;
    }
  }

  # Reached maximum depth, return the value at this point
  if ($depth > $max_depth) {
    my $value = 0;
 
    for my $rank (0 .. 7) {
      for my $file (0 .. 7) {
        $value += $piece_values{$state->{board}[$rank][$file]};
      }
    }

    return $value;
  }

  # Some intermediate state.
  #  Figure out the best move for this player.

  # Some moves are available, so try them.
  # Get all available moves
  my $best_move;
  my $best_value;
  if ($state->{turn}) {
    # maxi node
    $best_value = -100000;
  } else {
    # mini node
    $best_value = 100000;
  }

  foreach my $move ($state->get_moves) {
    if (defined $best_move) {
      print $fh pick('','',pick('Also','Or','Additionally','Possibly','In addition','Plus','And') . ', ');
    }
    print $fh pick(name($state->{turn}), ucfirst(pro($state->{turn}))) . ' ' .
      pick('might','could','may') . ' ' .
      pick('react','respond','reply','answer','counter','refute') . ' ' .
      pick('by playing','by moving','with','using') . ' ' .
      owner_piece($move->[Chess::Move::FROM_PIECE]) . ' ' .
      pick('from','at') . ' ' .
      square($move->[Chess::Move::FROM_RANK], $move->[Chess::Move::FROM_FILE]) .
      " to " . square($move->[Chess::Move::TO_RANK], $move->[Chess::Move::TO_FILE]);

    if (defined $move->[Chess::Move::TO_PIECE]) {
      print $fh ', ' . pick('taking','capturing') . ' ' . pick(owner_piece($move->[Chess::Move::TO_PIECE]), 'the ' . color_piece($move->[Chess::Move::TO_PIECE]));
    }
    if ($state->make_move($move)->is_check) { print $fh ' and putting ' . pick(name($state->{turn} ^ 0x20), color($state->{turn} ^ 0x20)) . ' in Check'; }
    print $fh ".\n";

    if ($depth < $max_depth) {
      print $fh ("\n" . ("#" x ($depth + 2)) . ' ' . color($state->{turn}) . ' ' . $move->to_string . "\n");
    }

    my $sub_best_value = recurse($fh, $state->make_move($move), $alpha, $beta, $depth + 1, $max_depth);

    # Replace best move with this one, depending on who is making the move
    #  True alpha-beta would be <= but we will leave equals for dramatic effect.
    if ($state->{turn}) {
      # maxi node
      if ($sub_best_value > $beta || (($sub_best_value == $beta) && chance(0.5))) {
        print $fh "This " . pick('line','path','route','sequence') . ' was ' . pick('disastrous','not as good','bad','worse','unsound') . ' for ' . pick(name($state->{turn}),color($state->{turn})) . ", so it was " . pick('abandoned','ignored','disregarded') . ".\n\n";
        return $beta;
      }
      if ($sub_best_value > $alpha) {
        $best_move = $move;
        $alpha = $sub_best_value;

        $best_value = $sub_best_value;
      }
    } else {
      # mini node
      #  True alpha-beta would be <= but we will leave equals for dramatic effect.
      if ($sub_best_value < $alpha || (($sub_best_value == $alpha) && chance(0.5))) {
        print $fh "This " . pick('line','path','route','sequence') . ' was ' . pick('disastrous','not as good','bad','worse','unsound') . ' for ' . pick(name($state->{turn}),color($state->{turn})) . ", so it was " . pick('abandoned','ignored','disregarded') . ".\n\n";
        return $alpha;
      }
      if ($sub_best_value < $beta) {
        $best_move = $move;
        $beta = $sub_best_value;

        $best_value = $sub_best_value;
      }
    }
  }


  print $fh pick('Of','Out of','Among') . ' these ' . pick('options','choices','candidates','moves') . ', ' .
    'the best move for ' . name($state->{turn}) . ' was ' . $best_move->to_string . ".\n\n";

  return $best_value;
}

###########################################################################################

die "Error: usage $0 <basename>" unless scalar @ARGV == 1;

open (my $txt, '>', $ARGV[0] . '.md') or die "Couldn't open $ARGV[0].md: $!";

# Mate in 2, position taken from
#  Monika Socko vs Laura Unuk, Riga, 2017
my $state = Chess::State->new("8/p4R2/2r4p/2p3kN/8/1P6/r1n3PP/4R2K w - - 1 0");

### Book Preface / Boilerplate
print $txt "# White to Play and Win\n";
print $txt "A NaNoGenMo 2017 entry.\n\n";
print $txt "Written by the open-source \"ChessBook\" software (https://github.com/greg-kennedy/ChessBook), by **Greg Kennedy** (<kennedy.greg\@gmail.com>).\n\n";
print $txt "Generated on " . scalar(localtime()) . ".\n\n";

### Table of Contents
print $txt "## Contents\n";
print $txt "* [Introduction](#introduction)\n";

my @top_moves = $state->get_moves;
for my $move (@top_moves) {
  print $txt "* [White " . $move->to_string . "](#white-" . lc($move->to_string) . ")\n";
}
print $txt "* [Conclusion](#conclusion)\n\n";

### Introduction
print $txt "## Introduction\n";
print $txt name(0) . " and " . name(0x20) . " sat across from each other at a square table.  Between them was a chess board.\n\n";

# render the pic
my $fig1 = $state->get_fen;
`./render.pl "$fig1" > fig1.png`;
print $txt "![$fig1](./fig1.png \"$fig1\")\n**Initial Position**\n\n";

# Describe all pieces
foreach my $rank (0 .. 7) {
  foreach my $file (0 .. 7) {
    my $p = $state->{board}[$rank][$file];
    if ($p) {
      print $txt "There was a " . color_piece($p) . " at " . square($rank, $file) . ".\n";
    }
  }
}

# Final
print $txt "\n" . name(0) . " was playing White.  It was " . owner(0) . " turn.\n\n";

### Big loop for novel structure
my $best_move;
my $best_value = 100000;

my $alpha = -100000;
my $beta = 100000;

for my $move (@top_moves) {
  ### Try moves
  print $txt "## White " . $move->to_string . "\n";
  print $txt name(0) . " considered moving " . owner_piece($move->[Chess::Move::FROM_PIECE]) .
    " from " . square($move->[Chess::Move::FROM_RANK], $move->[Chess::Move::FROM_FILE]) .
    " to " . square($move->[Chess::Move::TO_RANK], $move->[Chess::Move::TO_FILE]);
  if (defined $move->[Chess::Move::TO_PIECE]) {
    print $txt ', ' . pick('taking','capturing') . ' ' . pick(owner_piece($move->[Chess::Move::TO_PIECE]), 'the ' . color_piece($move->[Chess::Move::TO_PIECE]));
  }
  if ($state->make_move($move)->is_check) { print $txt ' and putting ' . pick(name($state->{turn} ^ 0x20), color($state->{turn} ^ 0x20)) . ' in Check'; }
  print $txt ".\n";

  my $sub_best_value = recurse($txt, $state->make_move($move), $alpha, $beta, 1, 2);

  # This is a maximal node
  if ($sub_best_value < $best_value) {
    $best_move = $move;
    $best_value = $sub_best_value;
  }
}

### Ending
print $txt "## Conclusion\n";
print $txt name(0) . " moved " . owner_piece($best_move->[Chess::Move::FROM_PIECE]) .
    " from " . square($best_move->[Chess::Move::FROM_RANK], $best_move->[Chess::Move::FROM_FILE]) .
    " to " . square($best_move->[Chess::Move::TO_RANK], $best_move->[Chess::Move::TO_FILE]) . ".\n\n";

# render the pic
my $fig2 = $state->make_move($best_move)->get_fen;
`./render.pl "$fig2" > fig2.png`;
print $txt "![$fig2](./fig2.png \"$fig2\")\n**Final Position**";

close($txt);

