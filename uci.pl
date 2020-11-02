#!/usr/bin/env perl
use strict;
use warnings;

##############################################################################
# UCI interface to the chess engine
#  Useful for testing or playing against
##############################################################################

## LOCAL MODULES
# make local dir accessible for use statements
use FindBin qw( $RealBin );
use lib $RealBin;

use Chess::State;
use Chess::Engine;

my $debug = 0;

my $state = Chess::State->new();

while (my $input = <STDIN>)
{
  $input =~ s/[\r\n]+$//;

  if ($input eq 'uci') {
    print "id name PerlChess\n";
    print "id author Greg Kennedy\n";
    print "uciok\n";
  } elsif ($input =~ m/^debug (on|off)$/) {
    if ($1 eq 'on') {
      $debug = 1;
    } else {
      $debug = 0;
    }
  } elsif ($input eq 'isready') {
    print "readyok\n";
#  } elsif ($input =~ m/^setoption name (.+) (?:value (.+))$/) {
#    
  } elsif ($input eq 'ucinewgame') {
    $state = Chess::State->new();
  } elsif ($input =~ m/^position (.+?)(?: moves (.+))?$/) {
    my $position = $1;
    my $moves = $2 || '';

    # set position
    if ($position eq 'startpos') { 
      $position = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
    }
    $state->set_fen($position);

    # apply any moves
    foreach my $move (split / /, $moves)
    {
      $state = $state->force_move(Chess::Move->new($move));
    }
  } elsif ($input =~ m/^go/) {
    my $engine = Chess::Engine->new(\$state, $state->{turn} ? 1 : 0, 3);

    print "bestmove " . $engine->think->to_string . "\n";
  } elsif ($input eq 'quit') {
    exit;
  } else {
    print "unknown command '$input'\n";
  }
}
