package Bot::Pluggable::Common;
$VERSION = 0.01;
use strict;
use warnings;

=pod

=head1 package Bot::Pluggable::Trust

         Common and useful routines for writing Bot::Pluggable Bots

=cut

use POE;

sub new {
    my $class = shift;
    return bless {@_}, ref $class || $class;
}

sub init{
    my ($self, $bot) = @_;
	warn __PACKAGE__.'::init called';
    $self->{_BOT_} = $bot;
}

sub save {}

sub nick {
   my ($self, $nickstring) = @_;
   my ($nick, undef) = split(/!/, $nickstring, 2);
   return $nick;
}

sub tell {
    my ($self, $target, $message) = @_;
    $self->{_BOT_}->privmsg($target, $message) if $target and $message;
    return 1;
}

sub do {
    my ($self, $target, $message) = @_;
    $self->{_BOT_}->ctcp($target, "ACTION $message") if $target and $message;
    return 1;
}

sub names {
    my ($self, $channel) = @_;
    unless (time - ( $self->{_BOT_}{recent_names} || 0 ) < 10) {      # Unless we've asked for names recently....
        $self->{_BOT_}{recent_names} = time;
        $self->{_BOT_}->names($channel);                               # reset the names list
    }
}

sub channels {
    my ($self, $target) = @_;
    my $heap = $poe_kernel->get_active_session()->get_heap();
    $heap->{Channels} = {} unless exists $heap->{Channels};
    $heap->{Channels} = $target if (defined $target);
    return $heap->{Channels};
}

sub told {
    return 0
};

#
# EVENTS
#

sub irc_001 {
    my ($self, $bot, $kernel) = @_[OBJECT, SENDER, KERNEL];
         $self->init($bot);
         return 0;
}

sub irc_public {
    my ($self, $bot, $nickstring, $channels, $message) = @_[OBJECT, SENDER, ARG0, ARG1, ARG2];
    my $nick = $self->nick($nickstring);
    return $self->told($nick, $channels->[0], $1) if ($message =~ m/^\s*\Q$bot->{Nick}\E[\:\,\;\.]?\s*(.*)$/i);
}

sub irc_msg {
    my ($self, $bot, $nickstring, $recipients, $message) = @_[OBJECT, SENDER, ARG0, ARG1, ARG2];
    return $self->told($self->nick($nickstring), undef, $message);
}
