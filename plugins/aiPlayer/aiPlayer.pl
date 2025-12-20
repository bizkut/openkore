# aiPlayer - AI-Driven OpenKore Plugin
# Uses LLM (Gemini/GPT) to make strategic game decisions
#
# This software is open source, licensed under the GNU General Public
# License, version 2.

package aiPlayer;

use strict;
use warnings;
use Plugins;
use Globals qw($char $field $net %config $accountID $questList $monstersList $npcsList $playersList);
use Log qw(message warning error debug);
use Misc;
use Utils;
use Commands;
use Time::HiRes qw(time);

use lib $Plugins::current_plugin_folder;
use aiPlayer::LLMClient;
use aiPlayer::ContextBuilder;
use aiPlayer::ToolExecutor;
use aiPlayer::GameKnowledge;

our $VERSION = '1.0.0';

# Plugin registration
Plugins::register('aiPlayer', 'AI-driven player using LLM', \&onUnload, \&onReload);

# Plugin state
my $hooks;
my $lastDecisionTime = 0;
my $llmClient;
my $contextBuilder;
my $toolExecutor;
my $gameKnowledge;
my $enabled = 0;

# Configuration defaults
our %config_defaults = (
    aiPlayer_enabled => 1,
    aiPlayer_apiUrl => 'https://openrouter.ai/api/v1/chat/completions',
    aiPlayer_apiKey => '',
    aiPlayer_model => 'google/gemini-3-flash-preview',
    aiPlayer_decisionInterval => 3,
    aiPlayer_maxTokens => 300,
    aiPlayer_maxLevelDiff => 10,
    aiPlayer_minHpToAttack => 30,
    aiPlayer_handleQuests => 1,
    aiPlayer_handleCombat => 1,
    aiPlayer_handleSocial => 0,
    aiPlayer_debug => 0,
);

# Initialize plugin
sub initPlugin {
    message "[aiPlayer] Initializing AI Player v$VERSION...\n", "aiPlayer";
    
    # Load configuration
    loadConfig();
    
    # Check if API key is configured
    if (!$config{aiPlayer_apiKey}) {
        warning "[aiPlayer] No API key configured! Set aiPlayer_apiKey in config.txt\n";
        return 0;
    }
    
    # Initialize components
    $gameKnowledge = aiPlayer::GameKnowledge->new();
    $contextBuilder = aiPlayer::ContextBuilder->new($gameKnowledge);
    $toolExecutor = aiPlayer::ToolExecutor->new();
    $llmClient = aiPlayer::LLMClient->new(
        apiUrl => $config{aiPlayer_apiUrl},
        apiKey => $config{aiPlayer_apiKey},
        model => $config{aiPlayer_model},
        maxTokens => $config{aiPlayer_maxTokens},
    );
    
    $enabled = $config{aiPlayer_enabled};
    
    message "[aiPlayer] Plugin initialized successfully!\n", "aiPlayer";
    return 1;
}

# Load configuration with defaults
sub loadConfig {
    foreach my $key (keys %config_defaults) {
        if (!defined $config{$key}) {
            $config{$key} = $config_defaults{$key};
        }
    }
}

# Hook setup
$hooks = Plugins::addHooks(
    ['start3', \&onStart],
    ['AI_pre', \&onAI_pre],
    ['packet_privMsg', \&onPrivateMessage],
    ['packet_pubMsg', \&onPublicMessage],
    ['quest_added', \&onQuestAdded],
    ['quest_updated', \&onQuestUpdated],
);

# Register commands
Commands::register(
    ['aiplayer', 'AI Player control', \&cmdAIPlayer],
);

# Called when OpenKore starts
sub onStart {
    initPlugin();
}

# Main AI hook - called every AI cycle
sub onAI_pre {
    return unless $enabled;
    return unless $char;
    return unless $net && $net->getState() == Network::IN_GAME;
    
    # Don't interfere if OpenKore is already doing something
    return if AI::is('attack', 'move', 'route', 'storageAuto', 'sellAuto', 'buyAuto', 'deal');
    
    # Check decision interval
    my $now = time();
    my $interval = $config{aiPlayer_decisionInterval} || 3;
    return if ($now - $lastDecisionTime) < $interval;
    
    # === INTERNAL HANDLING (No LLM needed) ===
    
    # 1. Let OpenKore handle potions via useSelf_item config
    # 2. Let OpenKore handle basic attacking via attackAuto config  
    # 3. Let OpenKore handle sitting via sitAuto config
    
    # Only call LLM if we need strategic decisions:
    # - No monsters nearby and need to find a zone
    # - Overweight and need to decide what to do
    # - Quest decisions
    # - Map navigation

    my $needsLLM = checkIfLLMNeeded();
    
    if ($needsLLM) {
        makeDecision();
    } else {
        debug "[aiPlayer] No LLM needed - OpenKore handling\n", "aiPlayer" if $config{aiPlayer_debug};
    }
    
    $lastDecisionTime = $now;
}

# Check if we actually need the LLM for a decision
sub checkIfLLMNeeded {
    return 0 unless $char;
    
    # If OpenKore is doing its job (attacking, moving), no LLM needed
    return 0 if AI::action() && AI::action() ne 'idle';
    
    # Check conditions that NEED LLM decision
    my $hp_percent = $char->{hp_max} ? int($char->{hp} / $char->{hp_max} * 100) : 100;
    my $weight_percent = $char->{weight_max} ? int($char->{weight} / $char->{weight_max} * 100) : 0;
    
    # 1. Critically low HP and no potions working - need escape decision
    if ($hp_percent < 20) {
        return 1; # LLM should decide: teleport or potion?
    }
    
    # 2. Overweight - need to decide: store or sell?
    if ($weight_percent > 70) {
        return 1;
    }
    
    # 3. No monsters nearby - need zone change decision
    my $nearbyMonsters = 0;
    if ($monstersList) {
        for my $m (@$monstersList) {
            $nearbyMonsters++ if $m && !$m->{dead};
        }
    }
    if ($nearbyMonsters == 0) {
        return 1; # Need to find new hunting grounds
    }
    
    # 4. Active quests that might need NPC interaction
    if ($questList && %$questList) {
        return 1;
    }
    
    # 5. Idle for too long - something's wrong
    if (AI::action() eq 'idle' || !AI::action()) {
        return 1;
    }
    
    return 0;
}

# Make an LLM decision
sub makeDecision {
    return unless $llmClient && $contextBuilder && $toolExecutor;
    
    # Build game context
    my $context = $contextBuilder->buildContext();
    
    # Build system prompt
    my $systemPrompt = buildSystemPrompt($context);
    
    # Build user message with current situation
    my $userMessage = buildUserMessage($context);
    
    debug "[aiPlayer] Requesting decision...\n", "aiPlayer" if $config{aiPlayer_debug};
    
    # Call LLM
    my $response = $llmClient->chat($systemPrompt, $userMessage);
    
    if (!$response) {
        debug "[aiPlayer] No response from LLM\n", "aiPlayer";
        return;
    }
    
    # Process tool calls
    if ($response->{tool_calls} && @{$response->{tool_calls}}) {
        foreach my $toolCall (@{$response->{tool_calls}}) {
            my $toolName = $toolCall->{function}{name};
            my $toolArgs = $toolCall->{function}{arguments};
            
            message "[aiPlayer] Decision: $toolName\n", "aiPlayer";
            debug "[aiPlayer] Args: $toolArgs\n", "aiPlayer" if $config{aiPlayer_debug};
            
            # Execute the tool
            $toolExecutor->execute($toolName, $toolArgs);
        }
    } elsif ($response->{content}) {
        debug "[aiPlayer] Text response (no action): $response->{content}\n", "aiPlayer";
    }
}

# Build system prompt with character context
sub buildSystemPrompt {
    my ($context) = @_;
    
    my $class = $context->{character}{class} || 'Adventurer';
    my $name = $context->{character}{name} || 'Unknown';
    my $level = $context->{character}{level} || 1;
    my $hp_percent = $context->{character}{hp_percent} || 100;
    my $sp_percent = $context->{character}{sp_percent} || 100;
    my $map = $context->{character}{map} || 'unknown';
    my $x = $context->{character}{x} || 0;
    my $y = $context->{character}{y} || 0;
    my $weight_percent = $context->{character}{weight_percent} || 0;
    my $maxLevelDiff = $config{aiPlayer_maxLevelDiff} || 10;
    
    return qq{You are an AI controlling a $class character named "$name" in Ragnarok Online.

ROLE: You are an autonomous adventurer leveling to max level. Make decisions that are efficient and safe.

CURRENT STATUS:
- Level: $level | HP: $hp_percent% | SP: $sp_percent%
- Map: $map | Position: ($x, $y)
- Weight: $weight_percent%

AUTONOMOUS LEVELING RULES:
1. SURVIVAL: If HP < 30%, use potion or teleport before doing anything else
2. WEIGHT: If weight > 70%, go to town to store items or sell junk
3. SUPPLIES: If potions < 10, go buy more at town
4. ZONE: If no monsters around, use change_leveling_zone to find a good spot
5. COMBAT: Attack monsters within $maxLevelDiff levels of you
6. QUESTS: Complete any active kill quests on the way

PRIORITY ORDER:
1. Stay alive (heal/flee if needed)
2. Manage inventory (store/sell if overweight)  
3. Restock supplies (buy potions if low)
4. Level efficiently (fight appropriate monsters)
5. Complete quests

RESPOND ONLY WITH TOOL CALLS - no explanations needed.};
}

# Build user message with current situation
sub buildUserMessage {
    my ($context) = @_;
    
    my @parts;
    
    # Nearby monsters
    if ($context->{nearby_monsters} && @{$context->{nearby_monsters}}) {
        push @parts, "NEARBY MONSTERS:";
        foreach my $m (@{$context->{nearby_monsters}}) {
            push @parts, "- $m->{name} (ID:$m->{id}, Lv:$m->{level}, Dist:$m->{distance})";
        }
    } else {
        push @parts, "NEARBY MONSTERS: None";
    }
    
    # Active quests
    if ($context->{quests} && @{$context->{quests}}) {
        push @parts, "\nACTIVE QUESTS:";
        foreach my $q (@{$context->{quests}}) {
            if ($q->{type} eq 'kill') {
                push @parts, "- Kill $q->{target}: $q->{current}/$q->{required}";
            } else {
                push @parts, "- $q->{name}";
            }
        }
    }
    
    # Nearby NPCs
    if ($context->{nearby_npcs} && @{$context->{nearby_npcs}}) {
        push @parts, "\nNEARBY NPCs:";
        foreach my $n (@{$context->{nearby_npcs}}) {
            push @parts, "- $n->{name} (ID:$n->{id}, Dist:$n->{distance})";
        }
    }
    
    # Inventory summary
    if ($context->{inventory}) {
        my $potions = $context->{inventory}{potions} || 0;
        push @parts, "\nINVENTORY: $potions healing items";
    }
    
    push @parts, "\nWhat action should you take?";
    
    return join("\n", @parts);
}

# Event handlers
sub onPrivateMessage {
    my (undef, $args) = @_;
    return unless $enabled && $config{aiPlayer_handleSocial};
    # Could use LLM to respond to PMs
}

sub onPublicMessage {
    my (undef, $args) = @_;
    return unless $enabled && $config{aiPlayer_handleSocial};
    # Could use LLM to participate in chat
}

sub onQuestAdded {
    my (undef, $args) = @_;
    debug "[aiPlayer] Quest added: $args->{questID}\n", "aiPlayer" if $config{aiPlayer_debug};
}

sub onQuestUpdated {
    my (undef, $args) = @_;
    debug "[aiPlayer] Quest updated: $args->{questID}\n", "aiPlayer" if $config{aiPlayer_debug};
}

# Command handler
sub cmdAIPlayer {
    my (undef, $args) = @_;
    my @args = split(/\s+/, $args);
    my $cmd = $args[0] || 'status';
    
    if ($cmd eq 'on') {
        $enabled = 1;
        $config{aiPlayer_enabled} = 1;
        message "[aiPlayer] AI Player enabled\n";
    } elsif ($cmd eq 'off') {
        $enabled = 0;
        $config{aiPlayer_enabled} = 0;
        message "[aiPlayer] AI Player disabled\n";
    } elsif ($cmd eq 'status') {
        message "[aiPlayer] Status: " . ($enabled ? "ENABLED" : "DISABLED") . "\n";
        message "[aiPlayer] Model: $config{aiPlayer_model}\n";
        message "[aiPlayer] Decision interval: $config{aiPlayer_decisionInterval}s\n";
    } elsif ($cmd eq 'decide') {
        message "[aiPlayer] Forcing decision...\n";
        makeDecision();
    } else {
        message "Usage: aiplayer [on|off|status|decide]\n";
    }
}

# Cleanup handlers
sub onUnload {
    message "[aiPlayer] Plugin unloading...\n", "aiPlayer";
    Plugins::delHooks($hooks);
}

sub onReload {
    message "[aiPlayer] Plugin reloading...\n", "aiPlayer";
    Plugins::delHooks($hooks);
    initPlugin();
}

1;

__END__

=head1 NAME

aiPlayer - AI-driven OpenKore plugin using LLM

=head1 DESCRIPTION

This plugin uses an LLM (like Gemini or GPT) to make strategic
game decisions, handling quests, combat, and human-like gameplay.

=head1 CONFIGURATION

Add to config.txt:

    aiPlayer_enabled 1
    aiPlayer_apiKey YOUR_API_KEY
    aiPlayer_model google/gemini-3-flash-preview

=head1 COMMANDS

=over 4

=item aiplayer on

Enable AI player

=item aiplayer off

Disable AI player

=item aiplayer status

Show current status

=item aiplayer decide

Force an immediate decision

=back

=cut
