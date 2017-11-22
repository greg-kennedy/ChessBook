all:
	./main.pl novel
	cat novel.md | tr -d '[:punct:][:digit:]' | wc -w

clean:
	rm -f novel.md

perft:
	./perft.pl 4

test:
	./test.pl
