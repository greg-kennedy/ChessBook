package Chess::Move;
use strict;
use warnings;

=pod

=head1 NAME

Chess::Move - an object that represents a chess move.

=head1 SYNOPSIS

    use Chess::Move;
    my $move = Move->new("e2e4");

    my $cloned_move = Move->new($move);
    $cloned_move->[Move::FROM_PIECE] = 'P';

    print $cloned_move->to_string . "\n";

    if ($move->equals($cloned_move)) { print "Moves are equal!\n"; }

=head1 DESCRIPTION

This is a class that can store chess moves.

It is implemented as an array with specially positioned fields,
which are named constants.

The minimum needed to specify a move is the first four elements:
from rank/file, and to rank/file.  If the move is a pawn promotion, it must
additionally specify a piece to promote to.

=head2 Methods

=over 12

=item C<new>

Returns a new Chess::Move object.  It requires one of the following:

* String designating a move, in geometric notation (e.g. "d2d4")
* Array containing a move (generally, another Chess::Move object)
* Reference to either of the above

Moves are subject to a quick validity check, which ensures they do
not violate overarching rules of chess (e.g. "can't move from/to same
square", "can't promote outside the back rank", etc)

=item C<to_string>

Returns a string description of a Chess::Move object.

=item C<equals>

Equality test for Chess::Move objects.  Two objects are equal if they
match on the from/to squares, promotion piece, and also do not conflict
on from/to piece types.

=back

=head1 LICENSE

This is released under the Artistic License. See L<perlartistic>.

=head1 AUTHOR

Greg Kennedy - L<https://greg-kennedy.com/>

=head1 SEE ALSO

L<https://en.wikipedia.org/wiki/Chess_Engine>

=cut

# min and max
use List::Util qw(min);
use Scalar::Util qw(reftype);

use Carp qw(confess);

# field parameters
use constant {
  FROM_RANK => 0,
  FROM_FILE => 1,
  TO_RANK => 2,
  TO_FILE => 3,
  PROMOTION_PIECE => 4,
  FROM_PIECE => 5,
  TO_PIECE => 6,
};

sub new
{
  my $class = shift;

  my @self;

  if (scalar @_ == 0) {
    confess "new() called with 0 parameters";
  } elsif (scalar @_ == 1) {
    # passed in one more parameter - maybe a reference to another move, or a string of encoded move
    my $type = reftype $_[0];
    if (! defined $type) {
      @self = _from_string($_[0]);
    } elsif ($type eq 'SCALAR') {
      @self = _from_string(${$_[0]});
    } elsif ($type eq 'ARRAY') {
      @self = @{$_[0]};
    } else {
      confess "Can't create a Move object given parameter $_[0]";
    }
  } else {
    # Passed a raw array
    @self = @_;
  }

  # Cleanup array: replace all empty-string with undef, then shorten to minimal length
  for (my $i = PROMOTION_PIECE; $i < scalar @self; $i ++) {
    $self[$i] ||= undef;
  }
  pop @self while (! defined $self[$#self]);

  # Sanity check
  my $count = scalar @self;
  confess "Illegal move: " . to_string(\@self) if (
    # incorrect number of fields in array
    $count <= TO_FILE ||
    $count > TO_PIECE + 1 ||
    # move out of bounds
    $self[FROM_RANK] < 0 || $self[FROM_RANK] > 7 ||
    $self[FROM_FILE] < 0 || $self[FROM_FILE] > 7 ||
    $self[TO_RANK] < 0 || $self[TO_RANK] > 7 ||
    $self[TO_FILE] < 0 || $self[TO_FILE] > 7 ||
    # from-to same square
    ($self[FROM_RANK] == $self[TO_RANK] && $self[FROM_FILE] == $self[TO_FILE]) ||

    # promotion piece: must be bnrq, and at a back row
    ($count > PROMOTION_PIECE && defined $self[PROMOTION_PIECE] && (
      (chr($self[PROMOTION_PIECE]) !~ m/^[BNRQbnrq]$/) ||
      ($self[TO_RANK] != 0 && $self[TO_RANK] != 7)
    )) ||

    # from-piece: must be valid piece
    ($count > FROM_PIECE && defined $self[FROM_PIECE] && (
      (chr($self[FROM_PIECE]) !~ m/^[BKNPRQbknprq]$/)
    )) ||

    # to-piece: must be valid piece
    ($count > TO_PIECE && defined $self[TO_PIECE] && (
      (chr($self[TO_PIECE]) !~ m/^[BKNPRQbknprq]$/)
    ))
  );

  # Bless this class and return
  return bless \@self, $class;
}

# Convert coordinate move to (from_rank, from_file, to_rank, to_file, promotion_piece)
sub _from_string
{
  my ($from_file, $from_rank, $to_file, $to_rank, $piece) = split //, $_[0], 5;

  return (
    ord($from_rank) - ord('1'),
    ord($from_file) - ord('a'),
    ord($to_rank) - ord('1'),
    ord($to_file) - ord('a'),
    defined $piece && $piece ne '' ? ord($piece) : undef
  );
}

# Convert (from_rank, from_file, to_rank, to_file, promotion_piece) to stringified version
sub to_string
{
  return
    chr($_[0]->[FROM_FILE] + ord('a')) .
    chr($_[0]->[FROM_RANK] + ord('1')) .
    chr($_[0]->[TO_FILE] + ord('a')) .
    chr($_[0]->[TO_RANK] + ord('1')) .
    (defined $_[0]->[PROMOTION_PIECE] ? chr($_[0]->[PROMOTION_PIECE]) : '');
}

# Check equality.  "Equality" is when from/to squares are same, promotion piece same,
#  and no-conflict on from_piece / to_piece.
sub equals
{
  for (my $i = FROM_RANK; $i <= TO_FILE; $i ++)
  {
    return 0 if ($_[0]->[$i] != $_[1]->[$i]);
  }

  for (my $i = PROMOTION_PIECE; $i <= min(scalar @{$_[0]}, scalar @{$_[1]}); $i ++)
  {
    return 0 if (defined $_[0]->[$i] && defined $_[1]->[$i] && $_[0]->[$i] ne $_[1]->[$i]);
  }

  return 1;
}

1;
