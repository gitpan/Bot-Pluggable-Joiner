package Bot::Pluggable::Common::SQLite;
use strict;
use base qw(Bot::Pluggable::Common);

BEGIN { print STDERR __PACKAGE__ . " Loaded\n" }

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->{_DBH_} = DBI->connect("dbi:SQLite:dbname=$$self{dbfile}","","");
    $self->load_schema;
    return bless $self, $class;
}

sub load { }

sub save { }

sub load_schema { }

1;
__END__
