# aiPlayer::ToolExecutor - Execute LLM Tool Calls
#
# Maps LLM tool calls to OpenKore commands and validates them

package aiPlayer::ToolExecutor;

use strict;
use warnings;
use Globals qw($char $field $monstersList $npcsList $accountID);
use Log qw(message warning error debug);
use AI;
use Misc qw(attack ai_talkNPC ai_useTeleport sit stand);
use Commands;
use JSON;

sub new {
    my ($class) = @_;
    
    my $self = {
        json => JSON->new->utf8,
    };
    
    bless $self, $class;
    return $self;
}

# Execute a tool call
sub execute {
    my ($self, $toolName, $argsJson) = @_;
    
    # Parse arguments
    my $args = {};
    if ($argsJson) {
        eval {
            $args = $self->{json}->decode($argsJson);
        };
        if ($@) {
            warning "[aiPlayer] Failed to parse tool args: $@\n";
            return 0;
        }
    }
    
    # Dispatch to appropriate handler
    my %handlers = (
        'attack_monster' => \&doAttackMonster,
        'move_to' => \&doMoveTo,
        'use_skill' => \&doUseSkill,
        'use_item' => \&doUseItem,
        'talk_to_npc' => \&doTalkToNpc,
        'sit' => \&doSit,
        'stand' => \&doStand,
        'teleport' => \&doTeleport,
        'wait' => \&doWait,
        # Autonomous leveling tools
        'go_to_map' => \&doGoToMap,
        'use_storage' => \&doUseStorage,
        'buy_items' => \&doBuyItems,
        'sell_items' => \&doSellItems,
        'use_kafra' => \&doUseKafra,
        'change_leveling_zone' => \&doChangeLevelingZone,
    );
    
    my $handler = $handlers{$toolName};
    if (!$handler) {
        warning "[aiPlayer] Unknown tool: $toolName\n";
        return 0;
    }
    
    return $handler->($self, $args);
}

# Attack a monster
sub doAttackMonster {
    my ($self, $args) = @_;
    
    my $monsterID = $args->{monster_id};
    return 0 unless defined $monsterID;
    
    # Find monster by binID
    my $monster;
    for my $m (@$monstersList) {
        if ($m && $m->{binID} == $monsterID) {
            $monster = $m;
            last;
        }
    }
    
    if (!$monster) {
        debug "[aiPlayer] Monster $monsterID not found\n", "aiPlayer";
        return 0;
    }
    
    # Safety check - don't attack if already attacking
    if (AI::is('attack')) {
        debug "[aiPlayer] Already attacking, skipping\n", "aiPlayer";
        return 0;
    }
    
    # Execute attack
    message "[aiPlayer] Attacking: $monster->{name}\n", "aiPlayer";
    attack($monster->{ID});
    
    return 1;
}

# Move to coordinates
sub doMoveTo {
    my ($self, $args) = @_;
    
    my $x = $args->{x};
    my $y = $args->{y};
    
    return 0 unless defined $x && defined $y;
    
    # Validate coordinates are walkable
    if ($field && !$field->isWalkable($x, $y)) {
        debug "[aiPlayer] Target ($x, $y) is not walkable\n", "aiPlayer";
        return 0;
    }
    
    message "[aiPlayer] Moving to ($x, $y)\n", "aiPlayer";
    main::ai_route($field->baseName, $x, $y);
    
    return 1;
}

# Use a skill
sub doUseSkill {
    my ($self, $args) = @_;
    
    my $skillName = $args->{skill_name};
    return 0 unless $skillName;
    
    my $targetID = $args->{target_id};
    my $level = $args->{level} || 1;
    
    # Find skill by name
    my $skill;
    if ($char && $char->{skills}) {
        foreach my $handle (keys %{$char->{skills}}) {
            my $s = Skill->new(handle => $handle);
            if ($s && lc($s->getName()) eq lc($skillName)) {
                $skill = $s;
                last;
            }
        }
    }
    
    if (!$skill) {
        debug "[aiPlayer] Skill '$skillName' not found\n", "aiPlayer";
        return 0;
    }
    
    message "[aiPlayer] Using skill: $skillName\n", "aiPlayer";
    
    # Use the skill command
    my $skillLevel = $level || 1;
    if ($targetID) {
        Commands::run("ss $skillLevel $skill->{handle} $targetID");
    } else {
        Commands::run("ss $skillLevel $skill->{handle}");
    }
    
    return 1;
}

# Use an item
sub doUseItem {
    my ($self, $args) = @_;
    
    my $itemName = $args->{item_name};
    return 0 unless $itemName;
    
    # Find item in inventory
    my $item;
    if ($char && $char->inventory) {
        for my $i (@{$char->inventory->getItems()}) {
            if ($i && lc($i->{name}) =~ /\Q$itemName\E/i) {
                $item = $i;
                last;
            }
        }
    }
    
    if (!$item) {
        debug "[aiPlayer] Item '$itemName' not found in inventory\n", "aiPlayer";
        return 0;
    }
    
    message "[aiPlayer] Using item: $item->{name}\n", "aiPlayer";
    Commands::run("i use $item->{binID}");
    
    return 1;
}

# Talk to NPC
sub doTalkToNpc {
    my ($self, $args) = @_;
    
    my $npcID = $args->{npc_id};
    return 0 unless defined $npcID;
    
    # Find NPC by binID
    my $npc;
    for my $n (@$npcsList) {
        if ($n && $n->{binID} == $npcID) {
            $npc = $n;
            last;
        }
    }
    
    if (!$npc) {
        debug "[aiPlayer] NPC $npcID not found\n", "aiPlayer";
        return 0;
    }
    
    message "[aiPlayer] Talking to NPC: $npc->{name}\n", "aiPlayer";
    
    # Use sequence if provided, otherwise just talk
    my $sequence = $args->{sequence} || 'c';
    ai_talkNPC($npc->{pos}{x}, $npc->{pos}{y}, $sequence);
    
    return 1;
}

# Sit down
sub doSit {
    my ($self, $args) = @_;
    
    if ($char && !$char->{sitting}) {
        message "[aiPlayer] Sitting down\n", "aiPlayer";
        sit();
        return 1;
    }
    
    return 0;
}

# Stand up
sub doStand {
    my ($self, $args) = @_;
    
    if ($char && $char->{sitting}) {
        message "[aiPlayer] Standing up\n", "aiPlayer";
        stand();
        return 1;
    }
    
    return 0;
}

# Teleport
sub doTeleport {
    my ($self, $args) = @_;
    
    my $type = $args->{type} || 'random';
    
    if ($type eq 'savepoint') {
        message "[aiPlayer] Teleporting to save point\n", "aiPlayer";
        ai_useTeleport(2);
    } else {
        message "[aiPlayer] Random teleport\n", "aiPlayer";
        ai_useTeleport(1);
    }
    
    return 1;
}

# Wait / do nothing
sub doWait {
    my ($self, $args) = @_;
    
    my $reason = $args->{reason} || 'no action needed';
    debug "[aiPlayer] Waiting: $reason\n", "aiPlayer";
    
    return 1;
}

# === AUTONOMOUS LEVELING TOOLS ===

# Go to a different map
sub doGoToMap {
    my ($self, $args) = @_;
    
    my $mapName = $args->{map_name};
    return 0 unless $mapName;
    
    # Clean map name (remove .gat extension if present)
    $mapName =~ s/\.gat$//;
    
    message "[aiPlayer] Traveling to map: $mapName\n", "aiPlayer";
    
    # Use OpenKore's route command
    Commands::run("route $mapName");
    
    return 1;
}

# Use storage (store or retrieve items)
sub doUseStorage {
    my ($self, $args) = @_;
    
    my $action = $args->{action} || 'store_all';
    
    if ($action eq 'store_all') {
        message "[aiPlayer] Storing all items\n", "aiPlayer";
        Commands::run("storage add all");
    } elsif ($action eq 'get_item') {
        my $itemName = $args->{item_name};
        my $amount = $args->{amount} || 1;
        if ($itemName) {
            message "[aiPlayer] Getting $amount x $itemName from storage\n", "aiPlayer";
            Commands::run("storage get $itemName $amount");
        }
    }
    
    return 1;
}

# Buy items from shop
sub doBuyItems {
    my ($self, $args) = @_;
    
    my $itemName = $args->{item_name};
    my $amount = $args->{amount} || 1;
    
    return 0 unless $itemName;
    
    message "[aiPlayer] Buying $amount x $itemName\n", "aiPlayer";
    
    # Use autobuy - this requires the shop to be open
    # OpenKore's buy command: buy <item> <amount>
    Commands::run("buy $itemName $amount");
    
    return 1;
}

# Sell items
sub doSellItems {
    my ($self, $args) = @_;
    
    my $sellType = $args->{sell_type} || 'junk';
    
    message "[aiPlayer] Selling items ($sellType)\n", "aiPlayer";
    
    # Trigger OpenKore's auto-sell
    Commands::run("sell");
    
    return 1;
}

# Use Kafra warp service
sub doUseKafra {
    my ($self, $args) = @_;
    
    my $destination = $args->{destination};
    return 0 unless $destination;
    
    # Map destination to known Kafra warp points
    my %kafraWarps = (
        'prontera' => 'prt_in',
        'geffen' => 'geffen_in',
        'payon' => 'payon_in02',
        'morroc' => 'morocc_in',
        'alberta' => 'alberta_in',
        'aldebaran' => 'aldeba_in',
    );
    
    message "[aiPlayer] Using Kafra to warp to: $destination\n", "aiPlayer";
    
    # Route to the destination town
    Commands::run("route $destination");
    
    return 1;
}

# Change to appropriate leveling zone
sub doChangeLevelingZone {
    my ($self, $args) = @_;
    
    my $zoneType = $args->{zone_type} || 'optimal';
    
    # Get character level
    my $level = $char ? ($char->{lv} || 1) : 1;
    
    # Determine best leveling zone based on level and preference
    my $targetMap = getLevelingZone($level, $zoneType);
    
    message "[aiPlayer] Changing to leveling zone: $targetMap (Lv$level, $zoneType)\n", "aiPlayer";
    
    Commands::run("route $targetMap");
    
    return 1;
}

# Helper: Get leveling zone for level
sub getLevelingZone {
    my ($level, $type) = @_;
    
    # Level ranges and recommended maps
    my @zones = (
        { min => 1,  max => 10,  safe => 'prt_fild01', optimal => 'prt_fild02', aggressive => 'prt_fild03' },
        { min => 10, max => 20,  safe => 'prt_fild03', optimal => 'moc_fild02', aggressive => 'moc_fild07' },
        { min => 20, max => 30,  safe => 'moc_fild02', optimal => 'pay_fild04', aggressive => 'moc_fild07' },
        { min => 30, max => 40,  safe => 'pay_fild04', optimal => 'pay_dun00',  aggressive => 'orcsdun01' },
        { min => 40, max => 50,  safe => 'pay_dun00',  optimal => 'orcsdun01',  aggressive => 'orcsdun02' },
        { min => 50, max => 60,  safe => 'orcsdun01',  optimal => 'orcsdun02',  aggressive => 'pay_dun03' },
        { min => 60, max => 70,  safe => 'orcsdun02',  optimal => 'pay_dun03',  aggressive => 'alde_dun02' },
        { min => 70, max => 80,  safe => 'pay_dun03',  optimal => 'alde_dun02', aggressive => 'gld_dun01' },
        { min => 80, max => 99,  safe => 'alde_dun02', optimal => 'gld_dun01',  aggressive => 'gld_dun02' },
    );
    
    foreach my $zone (@zones) {
        if ($level >= $zone->{min} && $level < $zone->{max}) {
            return $zone->{$type} || $zone->{optimal};
        }
    }
    
    # Default for high levels
    return 'gld_dun01';
}

1;
