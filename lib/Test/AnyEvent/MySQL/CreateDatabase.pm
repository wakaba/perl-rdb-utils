package Test::AnyEvent::MySQL::CreateDatabase;
use strict;
use warnings;
our $VERSION = '1.0';
use AnyEvent;
use AnyEvent::Util;
use Path::Class;
use File::Temp;

my $prepare_pl_script = file(__FILE__)->dir->parent->parent->parent->parent
    ->file('bin', 'prepare-db-set.pl')->stringify;

sub new {
    return bless {}, $_[0];
}

sub json_f {
    return $_[0]->{json_f} ||= file(File::Temp->new(SUFFIX => '.json')->filename);
}

sub onstdout {
    if (@_ > 1) {
        $_[0]->{onstdout} = $_[1];
    }
    return $_[0]->{onstdout};
}

sub onstderr {
    if (@_ > 1) {
        $_[0]->{onstderr} = $_[1];
    }
    return $_[0]->{onstderr};
}

sub prep_f_to_cv {
    my ($self, $prep_f) = @_;
    my $dsns_json_f = $self->json_f;

    local $ENV{PATH} = join ':', grep { not (m{/local/} and not m{^/usr/local/}) } split /:/, $ENV{PATH};
    local $ENV{PERL5LIB};
    my $db_cv = AE::cv;
    my $db_start_cv = run_cmd
        [
            'perl',
            $prepare_pl_script,
            '--preparation-file-name' => $prep_f,
            '--dsn-list' => $dsns_json_f,
        ],
        '>' => $self->onstdout || \*STDOUT,
        '2>' => $self->onstderr || \*STDERR,
    ;
    my $hoge = bless {
        count => 0,
        json_f => $dsns_json_f,
        json_file_name => $dsns_json_f->stringify,
        onstdout => $self->onstdout,
        onstderr => $self->onstderr,
    }, 'Test::AnyEvent::MySQL::CreateDatabase::Object';
    $db_start_cv->cb(sub { $db_cv->send($hoge); });
    return $db_cv;
}

package Test::AnyEvent::MySQL::CreateDatabase::Object;
use AnyEvent::Util;

sub json_f {
    return $_[0]->{json_f};
}

sub context_begin {
    $_[0]->{count}++;
    $_[1]->() if $_[1];
}

sub context_end {
    $_[0]->{count}--;
    if ($_[0]->{count}) {
        $_[1]->() if $_[1];
    } else {
        $_[0]->_end($_[1]);
    }
}

sub _end {
    local $?; # For Test::More

    if ($_[0]->{_end_invoked}) {
        $_[1]->();
        return;
    }
    $_[0]->{_end_invoked} = 1;

    local $ENV{PATH} = join ':', grep { not (m{/local/} and not m{^/usr/local/}) } split /:/, $ENV{PATH};
    local $ENV{PERL5LIB};
    my $json_file_name = $_[0]->{json_file_name};
    my $cv = run_cmd
        [
            'perl',
            $prepare_pl_script,
            '--dsn-list' => $json_file_name,
            '--stop',
        ],
        '>' => $_[0]->{onstdout} || \*STDOUT,
        '2>' => $_[0]->{onstderr} || \*STDERR,
    ;

    my $cb = $_[1];
    $cv->cb(sub {
        unlink $json_file_name;
        $cb->();
    });
}

sub DESTROY {
    $_[0]->_end(sub { });
}

1;
