package Bot::Pluggable::Joiner::SQLite;
use strict;
use base qw(Bot::Pluggable::Common::SQLite);

use POE;

BEGIN { print STDERR __PACKAGE__ . " Loaded\n" }

sub init {
    my $self = shift;
    $self->SUPER::init(@_);
    for my $event qw(re_join) {
        $self->{_BOT_}->add_event($event);
    }
	$self->load();
}

sub load {
    my ($self) = @_;
    $self->load_channels;
}

sub save {
    my $self = shift;
    $self->save_channels;
}


sub load_schema {
    my ($self) = @_;
    my $query = qq{ SELECT name FROM sqlite_master
                    WHERE type='table'
                    AND name = 'channel'
                    ORDER BY name
                  };
    return if defined @{ $self->{_DBH_}->selectall_arrayref($query) }[0];
    my @new_tables = (
        qq{CREATE TABLE channel (
            name TEXT UNIQUE
        )},
    );
    for my $query (@new_tables) {
        $self->{_DBH_}->do($query) or die "Can't Create Table: $query";
    }
    return;
}

sub load_channels {
    my $self = shift;
    my $channels = {};
    my $query = qq{ SELECT name FROM channel };
    my $targets = $self->{_DBH_}->selectall_arrayref($query);
        if ($DBI::errstr){ die "$DBI::errstr - $query"}
    for my $target (@$targets) {
        my $channel = $$target[0];
        print STDERR "Loading $channel\n" if $self->{DEBUG};
        $channels->{$channel} = {};
    }
    $self->channels($channels);
}

sub save_channels {
    my ($self) = @_;
    for my $channel (keys %{ $self->channels  }) {
        print STDERR "Saving $channel\n" if $self->{DEBUG};
        my $query = qq{ REPLACE INTO channel(name) VALUES('$channel') };
        die "$query" unless $self->{_DBH_}->do($query);
    }
}

sub join_channel {
    my ($self, $target) = @_;
    print STDERR "join_channel $target\n" if $self->{DEBUG};
    $self->{_BOT_}->join($target);
    my $channels = $self->channels();
    $channels->{$target} = {};
    $self->channels($channels);
    $self->save();
}

sub leave_channel {
    my ($self, $channel) = @_;
    for my $query (
         qq{DELETE FROM channel WHERE name = '$channel'},
         qq{DELETE FROM ops WHERE channel = '$channel'},
         qq{DELETE FROM voice WHERE channel = '$channel'},
     ) {
         print "Removing channel $channel";
         $self->{_DBH_}->do($query);
     }
    $self->{_BOT_}->part($channel);
    my $channels = $self->channels();
    delete $channels->{$channel};
    $self->channels($channels);
    $self->save;
}

sub told_join {
    my ($self, $channel, $nick) = @_;
    # TODO this is bad, we should make sure we sucessfully join the channel, really.
    eval {
        print STDERR "Told to join $channel by '$nick'\n" if $self->{DEBUG};
        $self->join_channel($channel);
    };
    if ($@) {
        warn "there was a problem: $@";
        return "I seem to be having trouble doing that";
    }
    return "Joining $channel. I'll remember this.";
}

sub told_part {
  my ($self, $channel, $target, $nick) = @_;
  eval {
        print STDERR "Told to leave $channel by $nick\n" if $self->{DEBUG};
        $self->leave_channel($channel);
  };
  if ($@) {
        warn "there was a problem: $@";
        return "I seem to be having trouble doing that";
  }
  return "Ok, $nick, bye. I'll remember this.";
}

sub quit {
    my ($self) = @_;
    print STDERR "Told Quit" if $self->{DEBUG};
    $self->save();
    $self->{_BOT_}->shutdown("quitting");
    exit;
}

sub told {
    my ($self, $nick, $channel, $message) = @_;

    my $sender = $channel || $nick;

    my $PUNC_RX = qr([?.!]?);
    my $NICK_RX = qr([][a-z0-9^`{}_|\][a-z0-9^`{}_|\-]*)i;

    # Join
    if ($message =~ /^join\s+(.*)$/i) {
         my $target = $1;
         my $res = $self->told_join($target, $nick);
         return $self->tell($sender, $res);
    }
    # Leave
    elsif ($message =~ /^(?:leave|part)\s+(.*)$/i) {
         my $target = $1;
         my $res = $self->leave_channel($channel, $target, $nick);
         return $self->tell($sender, $res);
    }

    elsif ($message =~ m/^quit$/i) {
            return $self->quit();
    }
}


#
# EVENTS
#

sub irc_001 {
    my ($self, $bot, $kernel) = @_[OBJECT, SENDER, KERNEL];
    $self->init($bot);
    my @channels = keys %{ $self->channels };
    $self->join_channel($_) for @channels;
    return 0;
}

sub re_join {
    my ($self, $bot, $channel) = @_[SENDER, OBJECT, ARG0];
    print STDERR "Attempting to rejoin $channel\n" if $self->{DEBUG};
    $self->join_channel($channel);
}

sub irc_invite {
    my ($self, $bot, $nickstring, $channel) = @_[OBJECT, SENDER, ARG0, ARG1];
    my $nick = $self->nick($nickstring);
    $self->join_channel($channel);
    return 0;
}

sub irc_kick {
    my ($self, $kernel, $nickstring, $channel, $kicked, $reason) = @_[OBJECT, KERNEL, ARG0, ARG1, ARG2, ARG3];
    if ($kicked eq $self->{_BOT_}->{Nick}) {
        print STDERR "Kicked from $channel by $nickstring ($reason)\n" if $self->{DEBUG};
        $kernel->delay_set("re_join", $$self{delay} || 10, $channel);
    }
    return 0;
}

1;
__END__