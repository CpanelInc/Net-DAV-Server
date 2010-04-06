#!/usr/bin/perl

use Test::More tests => 2;
use Carp;

use strict;
use warnings;

use Net::DAV::LockManager ();

my $mgr = Net::DAV::LockManager->new();
isa_ok( $mgr, 'Net::DAV::LockManager' );
can_ok( $mgr, qw/can_modify lock unlock refresh_lock/ );
