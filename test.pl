#!/usr/bin/env perl
use v5.10;
use strict;
use warnings;

use Chess::State;
use Chess::Move;

###########

my $move = Chess::Move->new('a1b1');
say $move->to_string;

###########

my $board = Chess::State->new; #('4r1k1/3n1ppp/4r3/3n3q/Q2P4/5P2/PP2BP1P/R1B1R1K1 b - - 0 1');
$board->pp;

my $board2 = $board->make_move( ($board->get_moves)[0] );
for (my $i = 0; $i < 2000; $i ++)
{
  $board2 = $board2->make_move( ($board2->get_moves)[0] );
  say $board2->get_fen;
}

say $board->get_fen;