#!/usr/bin/perl

use Test::More tests => 7;
use Carp;

use strict;
use warnings;

use IO::Scalar;

use HTTP::Request;
use HTTP::Response;

use Net::DAV::Server ();
use Net::DAV::LockManager::Simple ();

{
    package Mock::Filesys;
    sub new {
        return bless {
            '/'                 => [ 'd', 1, ],
            '/index.html'       => [ 'f', 1, "This is an index\nThis is only an index\n" ],
            '/foo'              => [ 'd', 1, ],
            '/foo/index.html'   => [ 'f', 1, "This is an index\nThis is also an index\n" ],
            '/foo/test.html'    => [ 'f', 1, "This is a test\nThis is only a test file\n" ],
            '/foo/private.txt'  => [ 'f', 0, ],
        };
    }
    sub test {
        my ($self, $op, $path) = @_;

        if ( $op eq 'e' ) {
            return exists $self->{$path};
        }
        elsif ( $op eq 'd' ) {
            return exists $self->{$path} && 'd' eq $self->{$path}->[0];
        }
        elsif ( $op eq 'f' ) {
            return exists $self->{$path} && 'f' eq $self->{$path}->[0];
        }
        elsif ( $op eq 'r' ) {
            return exists $self->{$path} && $self->{$path}->[1];
        }
        else {
            die "Operation $op not implemented.";
        }
    }
    sub modtime {
        my ($self, $file) = @_;
        return time;
    }
    sub open_read {
        my ($self, $file) = @_;
        return unless $self->test( 'f', $file ) && $self->test( 'r', $file );
        return IO::Scalar->new( \($self->{$file}->[2]) );
    }
    sub close_read {
        my ($self, $fh) = @_;
        close $fh;
        return;
    }
    sub list {
        my ($self, $dir) = @_;
        return unless $self->test( 'd', $dir );
        $dir .= '/' unless $dir =~ m{/$};
        my $off = length $dir;
        return map { substr( $_, $off ) } grep { /^\Q$dir\E./ } keys %{$self};
    }
}

{
    my $label = 'Missing';
    my $dav = Net::DAV::Server->new( -filesys => Mock::Filesys->new(), -dbobj => Net::DAV::LockManager::Simple->new() );
    my $req = HTTP::Request->new( GET => '/bar.html' );
    $req->authorization_basic( 'fred', 'fredmobile' );

    my $resp = $dav->run( $req, HTTP::Response->new() );
    is( $resp->code, 404, "$label: file not found." );
}

{
    my $label = 'File';
    my $dav = Net::DAV::Server->new( -filesys => Mock::Filesys->new(), -dbobj => Net::DAV::LockManager::Simple->new() );
    my $req = HTTP::Request->new( GET => '/index.html' );
    $req->authorization_basic( 'fred', 'fredmobile' );

    my $resp = $dav->run( $req, HTTP::Response->new() );
    is( $resp->code, 200, "$label: found" );
    like( $resp->header( 'last_modified' ), qr/^\w+, \d+ \w+ \d+ [\d:]+ GMT/, "$label: modified time" );
    is( $resp->content, "This is an index\nThis is only an index\n", "$label: correct content" );
}

{
    my $label = 'Non-readable File';
    my $dav = Net::DAV::Server->new( -filesys => Mock::Filesys->new(), -dbobj => Net::DAV::LockManager::Simple->new() );
    my $req = HTTP::Request->new( GET => '/foo/private.txt' );
    $req->authorization_basic( 'fred', 'fredmobile' );

    my $resp = $dav->run( $req, HTTP::Response->new() );
    is( $resp->code, 404, "$label: not found." );
}

{
    my $label = 'Directory';
    my $dav = Net::DAV::Server->new( -filesys => Mock::Filesys->new(), -dbobj => Net::DAV::LockManager::Simple->new() );
    my $req = HTTP::Request->new( GET => '/foo' );
    $req->authorization_basic( 'fred', 'fredmobile' );

    my $resp = $dav->run( $req, HTTP::Response->new() );
    is( $resp->code, 200, "$label: found." );

    my $cnt = grep { $resp->content =~ $_ }
              map { qr{<a href="\Q$_\E">\Q$_\E</a>} }
              ( 'index.html', 'test.html', 'private.txt' );
    is( $cnt, 3, "$label: All list entries found." );
}


