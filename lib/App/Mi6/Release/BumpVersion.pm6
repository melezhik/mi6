use v6.c;
unit class App::Mi6::Release::BumpVersion;

use App::Mi6::Util;
use File::Find;

my $PACKAGE-LINE = rx/
    ^
    $<before>=(
        \s* 'unit'? \s*
        ['module'|'class']
        \s+
        [ <[a..zA..Z0..9_]> | '::' ]+
        .*
        ':ver' ['('|'<']
        [\'|\"]?
    )
    $<version>=(
        v? [<[0..9]> | '.']+
    )
    $<after>=(
        [\'|\"]?
        [')'|'>']
        .*
    )
/;

has @.line;

method run(*%opt) {
    self.scan(%opt<dir>);
    my $current-version = self.current-version;
    my $next-version = self!exists-git-tag($current-version) ?? self.next-version !! $current-version;
    my $message = "Next release version? [$next-version]:";
    my $answer = prompt($message, default => $next-version);
    $next-version = $answer;
    self.bump($next-version);

    my %result = :$current-version, :$next-version;
    %result;
}

method !exists-git-tag($tag) {
    my @line = run(<git tag -l>, $tag, :out).out.lines(:close);
    +@line > 0;
}

method scan($dir) {
    @!line = gather for find(dir => $dir, name => /\.pm6?$/) -> $file {
        for $file.lines(:!chomp).kv -> $num, $line {
            next if $line ~~ /'# No BumpVersion'/;
            if $line ~~ $PACKAGE-LINE {
                take %(
                    version => $/<version>.Str,
                    before => $/<before>.Str,
                    after => $/<after>.Str,
                    file => $file.Str,
                    num => $num,
                );
            }
        }
    }
}

method current-version {
    @!line.map(*<version>).sort({ Version.new($^b) <=> Version.new($^a) }).first;
}

method next-version($version? is copy) {
    $version //= self.current-version;
    my @p = Version.new($version).parts;
    @p[*-1]++;
    @p.join(".");
}

method bump($version) {
    for @!line -> %line {
        self!bump(|%line, version => $version);
    }
}

method !bump(:$after, :$before, :$file, :$num, :$version) {
    my @new = gather for $file.IO.lines(:!chomp).kv -> $n, $line {
        if $n == $num {
            take $before ~ $version ~ $after;
        } else {
            take $line;
        }
    }
    $file.IO.spurt(@new.join(""));
}
