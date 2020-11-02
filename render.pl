#!/usr/bin/env perl
use strict;
use warnings;

## LOCAL MODULES
# make local dir accessible for use statements
use FindBin qw( $RealBin );
use lib $RealBin;

use Chess::State;
use GD;

sub load {
  my $img = GD::Image->newFromPng($_[0],1) or die "Failed to load image '$_[0]': $!";
  $img->alphaBlending(1);
  return $img;
}

# Load the images
my %piece;

for my $i ('b_p','w_p','b_k','w_k','b_n','w_n','b_q','w_q','b_r','w_r','b_b','w_b') {
  $piece{$i} = load("./img/$i.png");
}
my $empty_board = load('./img/board.png');

# Render a state
sub render {
  my $board = shift;

  # duplicate the empty board
  my $image = $empty_board->clone;
  $image->alphaBlending(1);

  for my $rank (0 .. 7) {
    for my $file (0 .. 7) {
      my $p = $board->[$rank][$file];
      next if (! $p);

      my $key = ($p & 0x20 ? 'b' : 'w') . '_' . chr($p | 0x20);
      # blit proper piece to this location
      my $n = $piece{$key};
      # calculate ranges
      my $dstX = (($file + 1) * 64) - ($n->width / 2);
      my $dstY = (((7 - $rank) + 1) * 64) - ($n->height / 2);
      $image->copy($n,$dstX,$dstY,0,0,$n->width,$n->height);
    }
  }

  return $image->png;
}

## USAGE
die "Specify a FEN string on command line" unless scalar @ARGV == 1;

# Create input state from command line
my $state = new Chess::State($ARGV[0]);

#my $fname = $state->get_fen;
binmode STDOUT;
print render($state->{board});
