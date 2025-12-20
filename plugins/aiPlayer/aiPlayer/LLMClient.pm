# aiPlayer::LLMClient - LLM API Client with Tool Calling
#
# Handles communication with OpenAI-compatible APIs (OpenRouter, etc.)

package aiPlayer::LLMClient;

use strict;
use warnings;
use JSON;
use HTTP::Tiny;
use Log qw(message warning error debug);

sub new {
    my ($class, %args) = @_;
    
    my $self = {
        apiUrl => $args{apiUrl} || 'https://openrouter.ai/api/v1/chat/completions',
        apiKey => $args{apiKey} || '',
        model => $args{model} || 'google/gemini-3-flash-preview',
        maxTokens => $args{maxTokens} || 300,
        http => HTTP::Tiny->new(timeout => 30),
        lastCallTime => 0,
        minCallInterval => 1, # Minimum seconds between calls
    };
    
    bless $self, $class;
    return $self;
}

# Define available tools for the LLM
sub getTools {
    return [
        {
            type => "function",
            function => {
                name => "attack_monster",
                description => "Attack a specific monster by its ID",
                parameters => {
                    type => "object",
                    properties => {
                        monster_id => { type => "integer", description => "The monster's ID" },
                        reason => { type => "string", description => "Why attacking this monster" }
                    },
                    required => ["monster_id"]
                }
            }
        },
        {
            type => "function",
            function => {
                name => "move_to",
                description => "Move to specific coordinates on the current map",
                parameters => {
                    type => "object",
                    properties => {
                        x => { type => "integer", description => "X coordinate" },
                        y => { type => "integer", description => "Y coordinate" }
                    },
                    required => ["x", "y"]
                }
            }
        },
        {
            type => "function",
            function => {
                name => "use_skill",
                description => "Use a skill on a target or self",
                parameters => {
                    type => "object",
                    properties => {
                        skill_name => { type => "string", description => "Name of the skill" },
                        target_id => { type => "integer", description => "Target ID (0 for self)" },
                        level => { type => "integer", description => "Skill level to use" }
                    },
                    required => ["skill_name"]
                }
            }
        },
        {
            type => "function",
            function => {
                name => "use_item",
                description => "Use an item from inventory (like potions)",
                parameters => {
                    type => "object",
                    properties => {
                        item_name => { type => "string", description => "Name of the item to use" }
                    },
                    required => ["item_name"]
                }
            }
        },
        {
            type => "function",
            function => {
                name => "talk_to_npc",
                description => "Talk to an NPC to start a conversation or quest",
                parameters => {
                    type => "object",
                    properties => {
                        npc_id => { type => "integer", description => "The NPC's ID" },
                        sequence => { type => "string", description => "Dialog sequence (e.g., 'c r0 n')" }
                    },
                    required => ["npc_id"]
                }
            }
        },
        {
            type => "function",
            function => {
                name => "sit",
                description => "Sit down to rest and recover HP/SP",
                parameters => {
                    type => "object",
                    properties => {
                        reason => { type => "string", description => "Why sitting" }
                    }
                }
            }
        },
        {
            type => "function",
            function => {
                name => "stand",
                description => "Stand up from sitting",
                parameters => {
                    type => "object",
                    properties => {}
                }
            }
        },
        {
            type => "function",
            function => {
                name => "teleport",
                description => "Teleport to escape danger (random) or return to save point",
                parameters => {
                    type => "object",
                    properties => {
                        type => { type => "string", enum => ["random", "savepoint"], description => "Teleport type" }
                    },
                    required => ["type"]
                }
            }
        },
        {
            type => "function",
            function => {
                name => "wait",
                description => "Do nothing this decision cycle",
                parameters => {
                    type => "object",
                    properties => {
                        reason => { type => "string", description => "Why waiting" }
                    },
                    required => ["reason"]
                }
            }
        },
        # === AUTONOMOUS LEVELING TOOLS ===
        {
            type => "function",
            function => {
                name => "go_to_map",
                description => "Travel to a different map for leveling or other purposes",
                parameters => {
                    type => "object",
                    properties => {
                        map_name => { type => "string", description => "Target map name (e.g., 'prt_fild01', 'prontera')" },
                        reason => { type => "string", description => "Why going to this map" }
                    },
                    required => ["map_name"]
                }
            }
        },
        {
            type => "function",
            function => {
                name => "use_storage",
                description => "Store items or retrieve items from storage (Kafra/storage NPC)",
                parameters => {
                    type => "object",
                    properties => {
                        action => { type => "string", enum => ["store_all", "get_item"], description => "Store items or get item" },
                        item_name => { type => "string", description => "Item name (for get_item)" },
                        amount => { type => "integer", description => "Amount to get" }
                    },
                    required => ["action"]
                }
            }
        },
        {
            type => "function",
            function => {
                name => "buy_items",
                description => "Buy items from an NPC shop (potions, supplies, etc.)",
                parameters => {
                    type => "object",
                    properties => {
                        item_name => { type => "string", description => "Item to buy (e.g., 'Red Potion')" },
                        amount => { type => "integer", description => "How many to buy" }
                    },
                    required => ["item_name", "amount"]
                }
            }
        },
        {
            type => "function",
            function => {
                name => "sell_items",
                description => "Sell items to clear inventory weight",
                parameters => {
                    type => "object",
                    properties => {
                        sell_type => { type => "string", enum => ["junk", "all_excess"], description => "What to sell" }
                    },
                    required => ["sell_type"]
                }
            }
        },
        {
            type => "function",
            function => {
                name => "use_kafra",
                description => "Use Kafra services for warping to towns",
                parameters => {
                    type => "object",
                    properties => {
                        destination => { type => "string", description => "Town name (prontera, geffen, payon, morroc, alberta)" },
                    },
                    required => ["destination"]
                }
            }
        },
        {
            type => "function",
            function => {
                name => "change_leveling_zone",
                description => "Move to an appropriate leveling zone based on current level",
                parameters => {
                    type => "object",
                    properties => {
                        zone_type => { type => "string", enum => ["optimal", "safe", "aggressive"], description => "Zone difficulty preference" }
                    },
                    required => ["zone_type"]
                }
            }
        }
    ];
}

# Main chat function with tool calling
sub chat {
    my ($self, $systemPrompt, $userMessage) = @_;
    
    # Rate limiting
    my $now = time();
    if (($now - $self->{lastCallTime}) < $self->{minCallInterval}) {
        return undef;
    }
    $self->{lastCallTime} = $now;
    
    # Build request payload
    my $payload = {
        model => $self->{model},
        messages => [
            { role => "system", content => $systemPrompt },
            { role => "user", content => $userMessage }
        ],
        tools => $self->getTools(),
        tool_choice => "auto",
        max_tokens => $self->{maxTokens},
    };
    
    # Make API request
    my $response = $self->makeRequest($payload);
    
    return $response;
}

# Make HTTP request to API
sub makeRequest {
    my ($self, $payload) = @_;
    
    my $json = JSON->new->utf8;
    my $body = $json->encode($payload);
    
    my $headers = {
        'Content-Type' => 'application/json',
        'Authorization' => 'Bearer ' . $self->{apiKey},
        'HTTP-Referer' => 'https://github.com/openkore',
        'X-Title' => 'OpenKore aiPlayer Plugin',
    };
    
    my $response = $self->{http}->post($self->{apiUrl}, {
        headers => $headers,
        content => $body,
    });
    
    if (!$response->{success}) {
        my $status = $response->{status};
        my $reason = $response->{reason};
        warning "[aiPlayer] API request failed: $status $reason\n";
        return undef;
    }
    
    my $result;
    eval {
        $result = $json->decode($response->{content});
    };
    if ($@) {
        warning "[aiPlayer] Failed to parse API response: $@\n";
        return undef;
    }
    
    # Extract message from response
    if ($result->{choices} && @{$result->{choices}}) {
        return $result->{choices}[0]{message};
    }
    
    return undef;
}

1;
