#!/usr/bin/perl

use Test::More tests => 9;
use Carp;

use strict;
use warnings;

use Net::DAV::LockManager ();
use Net::DAV::UUID ();

# Exploits an implementation detail
my $mock_token = 'opaquelocktoken:' . Net::DAV::UUID::generate( '/tmp/file', 'fred' );

{
    my $mgr = Net::DAV::LockManager->new();

    ok( !defined $mgr->refresh_lock({ 'path' => '/tmp/file', 'owner' => 'fred', 'token' => $mock_token }),
        'Can not refresh a non-existent lock' );
}

# Fail to refresh
{
    my $mgr = Net::DAV::LockManager->new();
    my $lck = $mgr->lock({ 'path' => '/tmp/file', 'owner' => 'fred' });

    ok( !defined $mgr->refresh_lock({ 'path' => '/tmp/file', 'owner' => 'fred', 'token' => $mock_token }),
        'Can not refresh with bad token' );

    ok( !defined $mgr->refresh_lock({ 'path' => '/tmp/file', 'owner' => 'bianca', 'token' => $lck->{'token'} }),
        'Can not refresh with wrong owner' );
}

{
    my $mgr = Net::DAV::LockManager->new();
    my $lck = $mgr->lock({ 'path' => '/tmp/file', 'owner' => 'fred' });
    my $token = $lck->{'token'};

    my $lck2 = $mgr->refresh_lock({ 'path' => '/tmp/file', 'owner' => 'fred', 'token' => $token, 'timeout' => 10 });
    ok( defined $lck2, 'refresh_lock succeeded with correct parms' );
    is( $lck2->{'token'}, $token, 'Refreshed lock has same token' );
    ok( $lck2->{'expiry'}-time <= 10, 'Refreshed lock has new timeout' );
}

{
    my $mgr = Net::DAV::LockManager->new();
    my $lck = $mgr->lock({ 'path' => '/tmp/file', 'owner' => 'fred' });
    my $token = $lck->{'token'};

    my $lck2 = $mgr->refresh_lock({ 'path' => '/tmp/file', 'owner' => 'fred', 'token' => $token });
    ok( defined $lck2, 'refresh_lock succeeded with default timeout' );
    is( $lck2->{'token'}, $token, 'Refreshed lock has same token' );
    my $timeout = $lck2->{'expiry'} - time;
    if ( 15*60 - $timeout > 3 ) {
        diag( "\tGot:      $timeout\n",
              "\tExpected: ",15*60, "\n" );
        fail( 'Refreshed timeout is default value' );
    }
    else {
        pass( 'Refreshed timeout is default value' );
    }
}