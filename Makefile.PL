use ExtUtils::MakeMaker;

WriteMakefile(
    NAME          => 'Bot::Pluggable::Joiner',
    VERSION_FROM  => 'lib/Bot/Pluggable/Joiner.pm',
    EXE_FILES     => [],
    PREREQ_PM => { Bot::Pluggable => 0.03 },
);


sub MY::libscan {
    package MY;
    my $self = shift;
    my ( $path ) = @_;
    return '' if /\.sw[a-z]$/;
    return '' unless length $self->SUPER::libscan( $path );
    return $path;
}
