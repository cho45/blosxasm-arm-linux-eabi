
.PHONY: all clean test

all: blosxasm.cgi

test: blosxasm.cgi
	perl test.t

clean:
	rm blosxasm.o blosxasm.cgi

server:
	cpanm Plack::App::CGIBin CGI::Emulate::PSGI CGI::Compile
	plackup -MPlack::App::CGIBin -e 'Plack::App::CGIBin->new(root => ".", exec_cb => sub { 1 })->to_app'

blosxasm.cgi: blosxasm.o
	ld -o blosxasm.cgi -e _start blosxasm.o
	strip blosxasm.cgi

blosxasm.o: blosxasm.s
	as -o blosxasm.o blosxasm.s

