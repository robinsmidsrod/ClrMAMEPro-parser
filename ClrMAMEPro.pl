#!/usr/bin/env perl
#
# Copyright Robin Smidsrød <robin@smidsrod.no> 2011
# Licensed under the GPLv3
#

use strict;
use warnings;

use Getopt::Long;

package main;

my $hide_bios;
my $hide_roms;
my $hide_disks;
my $hide_sha1;
my $hide_size;
my $hide_description;
my $only_missing_roms;
my $only_missing_disks;
my $show_help;
GetOptions(
    "hide-bios"  => \$hide_bios,
    "hide-roms"  => \$hide_roms,
    "hide-disks" => \$hide_disks,
    "hide-sha1"  => \$hide_sha1,
    "hide-size"  => \$hide_size,
    "hide-description" => \$hide_description,
    "only-missing-roms" => \$only_missing_roms,
    "only-missing-disks" => \$only_missing_disks,
    "help"               => \$show_help,
);

my $datfilename = shift;
$show_help = $datfilename ? $show_help : 1;

$hide_bios = ( $only_missing_roms or $only_missing_disks ) ? 1 : $hide_bios;
$hide_roms = $only_missing_disks ? 1 : $hide_roms;
$hide_disks = $only_missing_roms ? 1 : $hide_disks;

if ( $show_help ) {
    print STDERR <<"EOM";
$0 [<options>] <fixdatfile>

Options:
    --help	         Show usage information and exit

    --only-missing-roms  Only show sets missing roms
    --only-missing-disks Only show sets missing CHDs

    --hide-bios          Do not display BIOS set
    --hide-roms          Do not display missing roms
    --hide-disks         Do not display missing CHDs

    --hide-description   Do not display set description
    --hide-sha1          Do not display rom/CHD sha1 checksum
    --hide-size          Do not display rom size

EOM
    exit;
}

my $fixdatfile = ClrMAMEPro::FixDatFile->new( file => $datfilename );
foreach my $game ( @{ $fixdatfile->games } ) {
    my $game_name = $game->name;

    unless ( $hide_description ) {
        $game_name .= ": " . $game->description;
        $game_name .= " (" . $game->year;
        $game_name .= ", " . $game->manufacturer;
        $game_name .= ")";
        # Show parent name if clone
        if ( $game->romof ) {
            $game_name .= " [" . $game->romof . "]";
        }
    }

    if ( $only_missing_roms ) {
        print $game_name, "\n" if @{ $game->roms };
    }
    elsif ( $only_missing_disks ) {
        print $game_name, "\n" if @{ $game->disks };
    }
    else {
        print $game_name, "\n";
    }

    unless ( $hide_bios ) {
        foreach my $bios_set ( @{ $game->bios_sets } ) {
            print "  bios set: "
                . $bios_set->name
                . " (" . $bios_set->description . ")"
                . ( $bios_set->is_default ? ' [default]' : '' )
                . "\n";
        }
    }

    unless ( $hide_roms ) {
        foreach my $rom ( @{ $game->roms } ) {
            print "  missing rom: "
                . $rom->name
                . ( $hide_size ? "" : " [size: " . $rom->size . "]" )
                . ( $hide_sha1 ? "" : " [sha1:" . $rom->sha1 . "]" )
                . "\n";
        }
    }

    unless ( $hide_disks ) {
        foreach my $disk ( @{ $game->disks } ) {
            print "  missing chd: "
                . $disk->name . '.chd'
                . ( $hide_sha1 ? "" : " [sha1:" . $disk->sha1 . "]" )
                . "\n";
        }
    }

}

exit;

BEGIN {
    package ClrMAMEPro::FixDatFile;
    use Moose;
    with 'XML::Rabbit::RootNode';

    has 'games' => (
        isa         => 'ArrayRef[ClrMAMEPro::Game]',
        traits      => ['XPathObjectList'],
        xpath_query => '//datafile/game',
    );

    no Moose;
    __PACKAGE__->meta->make_immutable();

    package ClrMAMEPro::Game;
    use Moose;
    with 'XML::Rabbit::Node';

    has 'name' => (
        isa         => 'Str',
        traits      => ['XPathValue'],
        xpath_query => './@name',
    );

    has 'sourcefile' => (
        isa         => 'Str',
        traits      => ['XPathValue'],
        xpath_query => './@sourcefile',
    );

    has 'romof' => (
        isa         => 'Str',
        traits      => ['XPathValue'],
        xpath_query => './@romof',
    );

    has 'description' => (
        isa         => 'Str',
        traits      => ['XPathValue'],
        xpath_query => './description',
    );

    has 'year' => (
        isa         => 'Str',
        traits      => ['XPathValue'],
        xpath_query => './year',
    );

    has 'manufacturer' => (
        isa         => 'Str',
        traits      => ['XPathValue'],
        xpath_query => './manufacturer',
    );

    has 'bios_sets' => (
        isa => 'ArrayRef[ClrMAMEPro::BIOSSet]',
        traits => ['XPathObjectList'],
        xpath_query => './biosset',
    );

    has 'roms' => (
        isa => 'ArrayRef[ClrMAMEPro::ROM]',
        traits => ['XPathObjectList'],
        xpath_query => './rom',
    );

    has 'disks' => (
        isa => 'ArrayRef[ClrMAMEPro::Disk]',
        traits => ['XPathObjectList'],
        xpath_query => './disk',
    );

    no Moose;
    __PACKAGE__->meta->make_immutable();

    package ClrMAMEPro::BIOSSet;
    use Moose;
    with 'XML::Rabbit::Node';

    has 'name' => (
        isa         => 'Str',
        traits      => ['XPathValue'],
        xpath_query => './@name',
    );

    has 'description' => (
        isa         => 'Str',
        traits      => ['XPathValue'],
        xpath_query => './@description',
    );

    has '_default' => (
        isa         => 'Maybe[Str]',
        traits      => ['XPathValue'],
        xpath_query => './@default',
    );

    has 'is_default' => (
        is          => 'ro',
        isa         => 'Bool',
        lazy_build  => 1
    );
    
    sub _build_is_default {
        my ($self) = @_;
        return ( $self->_default || '' ) eq 'yes' ? 1 : 0;
    }

    package ClrMAMEPro::ROM;
    use Moose;
    with 'XML::Rabbit::Node';

    has 'name' => (
        isa         => 'Str',
        traits      => ['XPathValue'],
        xpath_query => './@name',
    );

    has 'size' => (
        isa         => 'Int',
        traits      => ['XPathValue'],
        xpath_query => './@size',
    );

    has 'sha1' => (
        isa         => 'Str',
        traits      => ['XPathValue'],
        xpath_query => './@sha1',
    );

    has 'crc' => (
        isa         => 'Str',
        traits      => ['XPathValue'],
        xpath_query => './@crc',
    );

    no Moose;
    __PACKAGE__->meta->make_immutable();

    package ClrMAMEPro::Disk;
    use Moose;
    with 'XML::Rabbit::Node';

    has 'name' => (
        isa         => 'Str',
        traits      => ['XPathValue'],
        xpath_query => './@name',
    );

    has 'sha1' => (
        isa         => 'Str',
        traits      => ['XPathValue'],
        xpath_query => './@sha1',
    );

    has 'region' => (
        isa         => 'Str',
        traits      => ['XPathValue'],
        xpath_query => './@region',
    );

    no Moose;
    __PACKAGE__->meta->make_immutable();

}

1;
