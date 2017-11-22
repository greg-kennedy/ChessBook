# White to Play and Win
A NaNoGenMo 2017 entry by Greg Kennedy, 2017

## [Read the novel here.](./sample/novel.md)

## [View the code here.](./main.pl)

## About
This is a novel about Harold and Maude playing a game of Chess.  In the game, it is Harold's turn.  He is playing the White pieces.  Harold considers each possible move, how Maude might respond to each of his plays, and what he may follow up with.  The entire thought process is recorded.  Essentially, it is a very verbose replay of the Min-Max algorithm, up to 3 ply, and using a form of alpha-beta cutoff to reduce word count to something manageable.

## Other
There are other items in this repository that either helped in development, or were useful for testing.

* Chess/Engine.pm - This is a non-chatty version of the engine used in generating the novel.
* perft.pl - Testing the move-generation routine.  This tool tries each possible position, and counts the "branch" metrics.  It can be compared to known perft results to prove correctness of move generation.
* play.pl - Driver program allowing a human to play against the engine!

## License
Released under Perl Artistic 2.0, see LICENSE for full details.
