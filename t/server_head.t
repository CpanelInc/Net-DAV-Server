#!/usr/bin/perl

use Test::More tests => 5;
use Carp;

use strict;
use warnings;

use HTTP::Request;
use HTTP::Response;

use Net::DAV::Server ();
use Net::DAV::LockManager::Simple ();

{
    package Mock::Filesys;
    sub new {
        return bless {
            '/'                 => [ 'd', 1, ],
            '/index.html'       => [ 'f', 1, ],
            '/foo'              => [ 'd', 1, ],
            '/foo/index.html'   => [ 'f', 1, ],
            '/foo/test.html'    => [ 'f', 1, ],
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
}

{
    my $label = 'Missing';
    my $dav = Net::DAV::Server->new( -filesys => Mock::Filesys->new(), -dbobj => Net::DAV::LockManager::Simple->new() );
    my $req = HTTP::Request->new( HEAD => '/bar.html' );
    $req->authorization_basic( 'fred', 'fredmobile' );

    my $resp = $dav->run( $req, HTTP::Response->new() );
    is( $resp->code, 404, "$label: file not found." );
}

{
    my $label = 'File';
    my $dav = Net::DAV::Server->new( -filesys => Mock::Filesys->new(), -dbobj => Net::DAV::LockManager::Simple->new() );
    my $req = HTTP::Request->new( HEAD => '/index.html' );
    $req->authorization_basic( 'fred', 'fredmobile' );

    my $resp = $dav->run( $req, HTTP::Response->new() );
    is( $resp->code, 200, "$label: found" );
    like( $resp->header( 'last_modified' ), qr/^\w+, \d+ \w+ \d+ [\d:]+ GMT/, "$label: modified time" );
}

{
    my $label = 'Non-readable File';
    my $dav = Net::DAV::Server->new( -filesys => Mock::Filesys->new(), -dbobj => Net::DAV::LockManager::Simple->new() );
    my $req = HTTP::Request->new( HEAD => '/foo/private.txt' );
    $req->authorization_basic( 'fred', 'fredmobile' );

    my $resp = $dav->run( $req, HTTP::Response->new() );
    is( $resp->code, 404, "$label: not found." );
}

{
    my $label = 'Directory';
    my $dav = Net::DAV::Server->new( -filesys => Mock::Filesys->new(), -dbobj => Net::DAV::LockManager::Simple->new() );
    my $req = HTTP::Request->new( HEAD => '/foo' );
    $req->authorization_basic( 'fred', 'fredmobile' );

    my $resp = $dav->run( $req, HTTP::Response->new() );
    is( $resp->code, 200, "$label: found." );
}


