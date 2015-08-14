CC=/usr/intel/pkgs/gcc/4.6.2/bin/g++
CFLAGS= -O3 -lboost_iostreams -lboost_regex -lz -I/p/gat/tools/boost/1.43.0/include -L/p/gat/tools/boost/1.43.0/gcc4.3/lib64

all: StatParser

StatParser: StatParser.cpp ExprParser.cpp
	$(CC) $(CFLAGS) $+ -o $@

clean:
	rm -f StatParser
