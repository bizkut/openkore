# aiPlayer::ContextBuilder - Game State Context Builder
#
# Collects game state to send to the LLM for decision making

package aiPlayer::ContextBuilder;

use strict;
use warnings;
use Globals qw($char $field $monstersList $npcsList $playersList $questList);
use Utils qw(distance calcPosition);
use AI;

sub new {
    my ($class, $gameKnowledge) = @_;
    
    my $self = {
        gameKnowledge => $gameKnowledge,
    };
    
    bless $self, $class;
    return $self;
}

# Build complete game context
sub buildContext {
    my ($self) = @_;
    
    my $context = {
        character => $self->getCharacterInfo(),
        nearby_monsters => $self->getNearbyMonsters(),
        nearby_npcs => $self->getNearbyNPCs(),
        nearby_players => $self->getNearbyPlayers(),
        quests => $self->getActiveQuests(),
        inventory => $self->getInventorySummary(),
        current_action => AI::action() || 'idle',
    };
    
    return $context;
}

# Get character information
sub getCharacterInfo {
    my ($self) = @_;
    
    return {} unless $char;
    
    my $hp_max = $char->{hp_max} || 1;
    my $sp_max = $char->{sp_max} || 1;
    my $weight_max = $char->{weight_max} || 1;
    
    return {
        name => $char->{name} || 'Unknown',
        class => $self->getClassName($char->{jobID}),
        level => $char->{lv} || 1,
        job_level => $char->{lv_job} || 1,
        hp => $char->{hp} || 0,
        hp_max => $hp_max,
        hp_percent => int(($char->{hp} || 0) / $hp_max * 100),
        sp => $char->{sp} || 0,
        sp_max => $sp_max,
        sp_percent => int(($char->{sp} || 0) / $sp_max * 100),
        map => $field ? $field->baseName : 'unknown',
        x => $char->{pos_to}{x} || 0,
        y => $char->{pos_to}{y} || 0,
        weight => $char->{weight} || 0,
        weight_max => $weight_max,
        weight_percent => int(($char->{weight} || 0) / $weight_max * 100),
        sitting => $char->{sitting} || 0,
        dead => $char->{dead} || 0,
    };
}

# Get class name from job ID
sub getClassName {
    my ($self, $jobID) = @_;
    
    my %classes = (
        0 => 'Novice',
        1 => 'Swordman', 2 => 'Mage', 3 => 'Archer',
        4 => 'Acolyte', 5 => 'Merchant', 6 => 'Thief',
        7 => 'Knight', 8 => 'Priest', 9 => 'Wizard',
        10 => 'Blacksmith', 11 => 'Hunter', 12 => 'Assassin',
        13 => 'Knight (Peco)', 14 => 'Crusader', 15 => 'Monk',
        16 => 'Sage', 17 => 'Rogue', 18 => 'Alchemist',
        19 => 'Bard', 20 => 'Dancer', 21 => 'Crusader (Peco)',
        23 => 'Super Novice',
        4001 => 'High Novice', 4002 => 'High Swordman',
        4008 => 'Lord Knight', 4009 => 'High Priest',
        4010 => 'High Wizard', 4011 => 'Whitesmith',
        4012 => 'Sniper', 4013 => 'Assassin Cross',
        4015 => 'Paladin', 4016 => 'Champion',
        4017 => 'Professor', 4018 => 'Stalker',
        4019 => 'Creator', 4020 => 'Clown',
        4021 => 'Gypsy',
    );
    
    return $classes{$jobID} || 'Unknown';
}

# Get nearby monsters
sub getNearbyMonsters {
    my ($self) = @_;
    
    my @monsters;
    return \@monsters unless $char && $monstersList;
    
    my $charPos = calcPosition($char);
    
    for my $monster (@$monstersList) {
        next unless $monster;
        next if $monster->{dead};
        
        my $monsterPos = calcPosition($monster);
        my $dist = distance($charPos, $monsterPos);
        
        # Only include monsters within reasonable range
        next if $dist > 20;
        
        push @monsters, {
            id => $monster->{binID},
            name => $monster->{name} || 'Unknown',
            level => $monster->{level} || 0,
            hp_percent => $monster->{hp} && $monster->{hp_max} 
                ? int($monster->{hp} / $monster->{hp_max} * 100) 
                : 100,
            distance => int($dist),
            x => $monsterPos->{x},
            y => $monsterPos->{y},
            aggressive => ($monster->{dmgToYou} || 0) > 0 ? 1 : 0,
        };
    }
    
    # Sort by distance
    @monsters = sort { $a->{distance} <=> $b->{distance} } @monsters;
    
    # Limit to 5 nearest
    @monsters = @monsters[0..4] if @monsters > 5;
    
    return \@monsters;
}

# Get nearby NPCs
sub getNearbyNPCs {
    my ($self) = @_;
    
    my @npcs;
    return \@npcs unless $char && $npcsList;
    
    my $charPos = calcPosition($char);
    
    for my $npc (@$npcsList) {
        next unless $npc;
        
        my $npcPos = { x => $npc->{pos}{x}, y => $npc->{pos}{y} };
        my $dist = distance($charPos, $npcPos);
        
        next if $dist > 15;
        
        push @npcs, {
            id => $npc->{binID},
            name => $npc->{name} || 'NPC',
            distance => int($dist),
            x => $npcPos->{x},
            y => $npcPos->{y},
        };
    }
    
    @npcs = sort { $a->{distance} <=> $b->{distance} } @npcs;
    @npcs = @npcs[0..3] if @npcs > 3;
    
    return \@npcs;
}

# Get nearby players
sub getNearbyPlayers {
    my ($self) = @_;
    
    my @players;
    return \@players unless $char && $playersList;
    
    my $charPos = calcPosition($char);
    
    for my $player (@$playersList) {
        next unless $player;
        
        my $playerPos = calcPosition($player);
        my $dist = distance($charPos, $playerPos);
        
        next if $dist > 15;
        
        push @players, {
            name => $player->{name} || 'Unknown',
            distance => int($dist),
        };
    }
    
    @players = @players[0..3] if @players > 3;
    
    return \@players;
}

# Get active quests
sub getActiveQuests {
    my ($self) = @_;
    
    my @quests;
    return \@quests unless defined $questList;
    
    foreach my $questID (keys %$questList) {
        my $quest = $questList->{$questID};
        next unless $quest && $quest->{active};
        
        my $questInfo = {
            id => $questID,
            name => $quest->{title} || "Quest $questID",
            type => 'general',
        };
        
        # Check for kill objectives
        if ($quest->{missions} && @{$quest->{missions}}) {
            foreach my $mission (@{$quest->{missions}}) {
                if ($mission->{mobID}) {
                    $questInfo->{type} = 'kill';
                    $questInfo->{target} = $mission->{mobName} || "Monster";
                    $questInfo->{current} = $mission->{count} || 0;
                    $questInfo->{required} = $mission->{goal} || 0;
                }
            }
        }
        
        push @quests, $questInfo;
    }
    
    return \@quests;
}

# Get inventory summary
sub getInventorySummary {
    my ($self) = @_;
    
    my $summary = {
        potions => 0,
        total_items => 0,
    };
    
    return $summary unless $char && $char->inventory;
    
    for my $item (@{$char->inventory->getItems()}) {
        next unless $item;
        $summary->{total_items}++;
        
        # Count healing items
        if ($item->{name} =~ /Potion|Herb|Juice|Honey/i) {
            $summary->{potions} += $item->{amount} || 1;
        }
    }
    
    return $summary;
}

1;
