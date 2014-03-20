#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

sub cgi {
	my (%env) = @_;
	local %ENV = (
		%ENV, %env
	);
	my $res = `./blosxasm.cgi`;
	unless ($? == 0) {
		die "cgi exit with $?";
	}
	$res;
}

subtest 'no PATH_INFO' => sub {
	my $res = cgi();
	like $res, qr/foo\.txt/;
	like $res, qr/bar\.txt/;
	like $res, qr/foobar\.txt/;
};

subtest 'empty PATH_INFO' => sub {
	my $res = cgi(PATH_INFO => '');
	like $res, qr/foo\.txt/;
	like $res, qr/bar\.txt/;
	like $res, qr/foobar\.txt/;
};

subtest 'PATH_INFO = /' => sub {
	my $res = cgi(PATH_INFO => '/');
	like $res, qr/foo\.txt/;
	like $res, qr/bar\.txt/;
	like $res, qr/foobar\.txt/;
};

subtest 'PATH_INFO = /foo.txt' => sub {
	my $res = cgi(PATH_INFO => '/foo.txt');
	like $res, qr/foo\.txt/;
	unlike $res, qr/bar\.txt/;
	unlike $res, qr/foobar\.txt/;
};

subtest 'PATH_INFO = /bar.txt' => sub {
	my $res = cgi(PATH_INFO => '/bar.txt');
	unlike $res, qr/foo\.txt/;
	like $res, qr/bar\.txt/;
	unlike $res, qr/foobar\.txt/;
};

done_testing;
