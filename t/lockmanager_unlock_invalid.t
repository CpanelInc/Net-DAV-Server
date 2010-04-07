#!/usr/bin/perl

use Test::More tests => 19;
use Carp;

use strict;
use warnings;

use Net::DAV::LockManager ();
use Net::DAV::LockManager::Simple ();

{
    # Validate parameters
    my $db = Net::DAV::LockManager::Simple->new();
    my $mgr = Net::DAV::LockManager->new($db);
    did_die( sub { $mgr->unlock() },                          qr/hash reference/,           'No args' );
    did_die( sub { $mgr->unlock( 'fred' ) },                  qr/hash reference/,           'String arg' );
    did_die( sub { $mgr->unlock({}) },                        qr/Missing required/,         'No params' );
    did_die( sub { $mgr->unlock({ 'owner' => 'gwj', 'token' => '1234' }) },      qr/Missing required 'path'/,  'Missing path' );
    did_die( sub { $mgr->unlock({ 'path' => '/tmp/file', 'token' => '1234' }) }, qr/Missing required 'owner'/, 'Missing owner' );
    did_die( sub { $mgr->unlock({ 'path' => '/tmp/file', 'owner' => 'gwj' }) }, qr/Missing required 'token'/, 'Missing token' );
}

{
    # Path checking
    my $db = Net::DAV::LockManager::Simple->new();
    my $mgr = Net::DAV::LockManager->new($db);
    foreach my $path ( '', qw{/.. /fred/.. /../fred /fred/../bianca /fred/ fred/ fred} ) {
        did_die( sub { $mgr->unlock({ 'path' => $path, 'owner'=>'gwj', 'token' => '1234' }) }, qr/Not a clean path/, "$path: Not an allowed path" );
    }
}

{
    # Owner checking
    my $db = Net::DAV::LockManager::Simple->new();
    my $mgr = Net::DAV::LockManager->new($db);
    foreach my $owner ( '', qw{aa()bb /fred/ ab+cd 1fred} ) {
        did_die( sub { $mgr->unlock({ 'path' => '/fred/foo', 'owner'=>$owner, 'token' => '1234' }) }, qr/Not a valid owner/, "$owner Not an allowed owner" );
    }
}

sub did_die {
    my ($code, $regex, $label) = @_;
    if ( eval { $code->(); } ) {
        fail( "$label: no exception" );
        return;
    }
    like( $@, $regex, $label );
}
