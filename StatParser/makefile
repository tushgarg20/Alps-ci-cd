CC=/usr/intel/pkgs/gcc/4.6.2/bin/g++
CFLAGS= -lboost_iostreams -lboost_regex -lz -I/p/gat/tools/boost/1.43.0/include -L/p/gat/tools/boost/1.43.0/gcc4.3/lib64

all:
	$(CC) $(CFLAGS) StatParser.cpp ExprParser.cpp -o StatParser

clean:
	rm -f StatParser
