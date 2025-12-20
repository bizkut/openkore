# aiPlayer::GameKnowledge - Embedded Game Knowledge
#
# Contains class-weapon compatibility, basic strategies, etc.

package aiPlayer::GameKnowledge;

use strict;
use warnings;

sub new {
    my ($class) = @_;
    
    my $self = {
        classWeapons => getClassWeapons(),
        monsterElements => {},  # Could be populated from tables
    };
    
    bless $self, $class;
    return $self;
}

# Get recommended weapons for each class
sub getClassWeapons {
    return {
        'Novice' => ['Dagger', 'Knife'],
        'Swordman' => ['Sword', 'Two-Handed Sword', 'Spear'],
        'Mage' => ['Rod', 'Staff', 'Wand'],
        'Archer' => ['Bow', 'Crossbow'],
        'Acolyte' => ['Mace', 'Staff', 'Book'],
        'Merchant' => ['Axe', 'Sword', 'Mace'],
        'Thief' => ['Dagger', 'Katar'],
        
        'Knight' => ['Sword', 'Two-Handed Sword', 'Spear', 'Lance'],
        'Crusader' => ['Sword', 'Spear', 'Mace'],
        'Priest' => ['Mace', 'Staff', 'Book'],
        'Monk' => ['Knuckle', 'Mace'],
        'Wizard' => ['Rod', 'Staff'],
        'Sage' => ['Rod', 'Staff', 'Book'],
        'Hunter' => ['Bow'],
        'Bard' => ['Instrument', 'Bow'],
        'Dancer' => ['Whip', 'Bow'],
        'Assassin' => ['Katar', 'Dagger'],
        'Rogue' => ['Dagger', 'Sword', 'Bow'],
        'Blacksmith' => ['Axe', 'Mace'],
        'Alchemist' => ['Axe', 'Mace', 'Dagger'],
        
        'Lord Knight' => ['Sword', 'Two-Handed Sword', 'Spear'],
        'Paladin' => ['Sword', 'Spear', 'Mace'],
        'High Priest' => ['Mace', 'Staff', 'Book'],
        'Champion' => ['Knuckle', 'Mace'],
        'High Wizard' => ['Rod', 'Staff'],
        'Professor' => ['Rod', 'Staff', 'Book'],
        'Sniper' => ['Bow'],
        'Clown' => ['Instrument', 'Bow'],
        'Gypsy' => ['Whip', 'Bow'],
        'Assassin Cross' => ['Katar', 'Dagger'],
        'Stalker' => ['Dagger', 'Sword', 'Bow'],
        'Whitesmith' => ['Axe', 'Mace'],
        'Creator' => ['Axe', 'Mace', 'Dagger'],
    };
}

# Check if weapon is suitable for class
sub isWeaponSuitable {
    my ($self, $className, $weaponType) = @_;
    
    my $weapons = $self->{classWeapons}{$className};
    return 1 unless $weapons;  # Unknown class, allow anything
    
    foreach my $w (@$weapons) {
        return 1 if lc($weaponType) =~ /\Q$w\E/i;
    }
    
    return 0;
}

# Get leveling recommendations
sub getLevelingSpots {
    return {
        '1-10' => [
            { map => 'prt_fild01', monsters => ['Poring', 'Fabre', 'Lunatic'] },
            { map => 'prt_fild02', monsters => ['Poring', 'Drops'] },
        ],
        '10-20' => [
            { map => 'prt_fild03', monsters => ['Rocker', 'Willow'] },
            { map => 'moc_fild02', monsters => ['Peco Peco', 'Muka'] },
        ],
        '20-30' => [
            { map => 'moc_fild07', monsters => ['Hode'] },
            { map => 'pay_fild04', monsters => ['Poporing', 'Elder Willow'] },
        ],
        '30-40' => [
            { map => 'pay_dun00', monsters => ['Zombie', 'Familiar'] },
            { map => 'orcsdun01', monsters => ['Orc Zombie', 'Orc Skeleton'] },
        ],
        '40-50' => [
            { map => 'orcsdun02', monsters => ['Orc Archer', 'Orc Warrior'] },
            { map => 'gef_fild06', monsters => ['Golem', 'Nightmare'] },
        ],
        '50-60' => [
            { map => 'gef_fild10', monsters => ['Orc Hero', 'High Orc'] },
            { map => 'pay_dun03', monsters => ['Sohee', 'Munak'] },
        ],
        '60-70' => [
            { map => 'alde_dun02', monsters => ['Bathory', 'Marionette'] },
            { map => 'gld_dun01', monsters => ['Raydric', 'Khalitzburg'] },
        ],
    };
}

# Get primary stats for class
sub getClassStats {
    return {
        'Swordman' => { primary => ['STR', 'VIT'], secondary => ['DEX', 'AGI'] },
        'Knight' => { primary => ['STR', 'VIT'], secondary => ['DEX', 'AGI'] },
        'Crusader' => { primary => ['STR', 'VIT', 'INT'], secondary => ['DEX'] },
        'Mage' => { primary => ['INT', 'DEX'], secondary => ['VIT'] },
        'Wizard' => { primary => ['INT', 'DEX'], secondary => ['VIT'] },
        'Archer' => { primary => ['DEX', 'AGI'], secondary => ['LUK', 'VIT'] },
        'Hunter' => { primary => ['DEX', 'AGI'], secondary => ['LUK', 'VIT'] },
        'Acolyte' => { primary => ['INT', 'VIT'], secondary => ['DEX'] },
        'Priest' => { primary => ['INT', 'VIT'], secondary => ['DEX'] },
        'Monk' => { primary => ['STR', 'AGI', 'DEX'], secondary => ['VIT'] },
        'Thief' => { primary => ['AGI', 'STR'], secondary => ['DEX', 'LUK'] },
        'Assassin' => { primary => ['AGI', 'STR'], secondary => ['DEX', 'LUK'] },
        'Merchant' => { primary => ['STR', 'VIT'], secondary => ['DEX'] },
        'Blacksmith' => { primary => ['STR', 'DEX'], secondary => ['VIT'] },
    };
}

1;
