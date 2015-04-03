package Xenon::File::LCFG; # -*- perl -*-
use strict;
use warnings;

use v5.10;

use Moo;
use Types::Path::Tiny qw(AbsPath);
use Try::Tiny;

with 'Xenon::Role::FileContentManager';

use namespace::clean;

use Readonly;
Readonly my $LEFT  => '<%';           # Left bracket  
Readonly my $RIGHT => '%>';           # Right bracket

sub _default_options {
    return {};
}

sub build_data {
    my ( $self, $input, @reslist ) = @_;

    # Filename only used for error messages
    my $tmplfile = $self->source;

    my $data = $self->Transform( $input, $tmplfile, 1, @reslist );

    if ( $@ || !defined $data ) {
        die "Failed to process template '$tmplfile': $@\n";
    }

    return $data;
}

# The following code is rather peculiar, it was taken from
# LCFG::Template and cleaned/tidied to make it easier to read. The
# "skipfiles" feature is completely disabled as it is fundamentally
# broken.

sub Transform {
    my ( $self, $input, $f, $skipping, @reslist ) = @_;

    # Scan

    my ( $tokens, $rest, $term, $linenum, $errs ) =
        $self->Scan( $input, $f );

    if ($term) {
        push @{$errs}, "unexpected '$RIGHT' at $f:$linenum";
    }

    if (@{$errs}) {
        $@ = join "\n",@{$errs};
        return;
    }

    # Parse

    ( $tokens, $term, $errs ) = $self->Parse( $tokens, $f );

    if ($term) {
        push @{$errs}, 'unexpected ' . $term->{TOKEN} . " at $f:" . $term->{LINE};
    }

    if (@{$errs}) {
        $@ = join "\n",@{$errs};
        return;
    }

    my $tmplvars = {}; # anything set in a template

    # Eval

    my $data = $self->Eval( $tokens, $f, $errs, 0, $tmplvars, @reslist );

    if (@{$errs}) {
        $@ = join "\n",@{$errs};
        return;
    }

    return $data;

}

#######################################################################
sub Lookup {
#######################################################################

# Lookup a variable
# Inputs are:
#  Variable name
#  Token ref (for reporting error line)
#  Filename (for error reporting)
#  Ref to error list
#  List of variable bindings

    my ( $self, $key, $t, $f, $errs, $tmplvars, @reslist ) = @_;
    $errs //= [];

    $key =~ s/^\s+//;
    $key =~ s/\s+$//;

    if ( $key !~ m/^(#?)([a-zA-Z_0-9]+)$/ ) {
        push @{$errs}, "invalid resource name ($key) at $f:" . $t->{LINE};
        return undef;
    }

    my ( $type, $k ) = ( $1, $2 );

    for my $res ( $tmplvars, @reslist ) {
        my $val = $res->{$k};
        if ( $type eq q{#} ) {
            if ( defined $val->{DERIVE} ) {
                return $val->{DERIVE};
            }
        } else {
            if ( defined $val->{VALUE} ) {
                return $val->{VALUE};
            }
        }
    }

    if ( $type eq q{#} ) {
        return q{};
    }

    push @{$errs}, "undefined resource ($k) at $f:" . $t->{LINE};

    return undef;
}

#######################################################################
sub Eval {
#######################################################################

# Evaluate template parse tree in LCFG resource context
#
# Input is:
#  Parse tree as genenerated by Parse
#  Filename (for error messages)
#  Ref to error message list
#  Output flag
#    COPY    = copying everything to output
#    SKIP    = not copying "skipped text"
#  List of variable binding hashes
#
# Output is:
#  Substituted template data

    my ( $self, $tokens, $f, $errs, $skipping, $tmplvars, @reslist ) = @_;
  
    my $data = q{};

    for my $t (@{$tokens}) {

        if ( $t->{TOKEN} eq 'TEXT' ) {
            $data .= $t->{DATA};
            next;
        }
    
        if ( $t->{TOKEN} eq 'PERL' ) {
            my $expr = $self->Eval( $t->{EXPR}, $f, $errs, $skipping,
                                    $tmplvars, @reslist );

            my $val = eval $expr; # urgh, string eval
            if ($@) {
                chomp $@;
                push @{$errs},
                "perl expression failed at $f:" . $t->{LINE} . "\n$expr\n$@";
            } else {
                $data .= $val;
            }

            next;
        }
    
        if ( $t->{TOKEN} eq 'SHELL' ) {
            my $cmd = $self->Eval( $t->{EXPR}, $f, $errs, $skipping,
                                   $tmplvars, @reslist );
            my $xcmd = $cmd;
            $xcmd =~ s/\`/\\\`/;

            my $val = `$xcmd`; # urgh, full shell
            if ( $? != 0 ) {
                push @{$errs},
                "shell command failed at $f:" . $t->{LINE} . "\n$cmd";
            } else {
                chomp $val;
                $data .= $val;
            }

            next;
        }
    
        if ( $t->{TOKEN} eq 'REF' ) {
            my $result = $self->Lookup(
                $self->Eval( $t->{EXPR}, $f, $errs, $skipping,
                             $tmplvars, @reslist ),
                $t, $f, $errs, $tmplvars, @reslist );

            if ( defined $result ) {
                $data .= $result;
            }

            next;
        }
    
        if ( $t->{TOKEN} eq 'IFDEF' ) {
            my $key = $self->Eval( $t->{EXPR}, $f, $errs, $skipping,
                                   $tmplvars, @reslist );

            $key =~ s/^\s+//;
            $key =~ s/\s+$//;

            my $val;
            for my $res ( $tmplvars, @reslist ) {
                my $v = $res->{$key};
                if ( defined( $val = $v->{VALUE} ) ) {
                    last;
                }
            }

            if ( defined $val ) {
                if ( $t->{BODY} ) {
                    $data .= $self->Eval( $t->{BODY}, $f, $errs, $skipping,
                                          $tmplvars, @reslist );
                }
            } else {
                if ( $t->{ELSE} ) {
                    $data .= $self->Eval( $t->{ELSE}, $f, $errs, $skipping,
                                          $tmplvars, @reslist );
                }
            }

            next;
        }
    
        if ( $t->{TOKEN} eq 'IF' ) {

            my $val = $self->Eval( $t->{EXPR}, $f, $errs, $skipping,
                                   $tmplvars, @reslist );

            $val =~ s/^\s+//;
            $val =~ s/\s+$//;

            if ( $val ne q{} ) {
                if ( $t->{BODY} ) {
                    $data .= $self->Eval( $t->{BODY}, $f, $errs, $skipping,
                                          $tmplvars, @reslist );
                }
            } else {
                if ( $t->{ELSE} ) {
                    $data .= $self->Eval( $t->{ELSE}, $f, $errs, $skipping,
                                          $tmplvars, @reslist );
                }
            }

            next;
        }
    
        if ( $t->{TOKEN} eq 'SET' ) {
            my $val = $self->Eval( $t->{EXPR}, $f, $errs, $skipping,
                                   $tmplvars, @reslist );
            $tmplvars->{$t->{VAR}} = { VALUE => $val };

            next;
        }
    
        if ( $t->{TOKEN} eq 'FOR' ) {
            my $var = $t->{VAR};
            if ( $var !~ m/^[a-zA-Z_]+$/ ) {
                push @{$errs},
                "invalid variable name ($var) at $f:" . $t->{LINE};
                next;
            }

            my $list = $self->Eval( $t->{EXPR}, $f, $errs, $skipping,
                                    $tmplvars, @reslist );

            $list =~ s/^\s+//;
            $list =~ s/\s+$//;

            for my $tag ( split /\s+/,$list ) {
                my $binding = { $var => { VALUE => $tag } };
                if ( $t->{BODY} ) {
                    $data .= $self->Eval( $t->{BODY}, $f, $errs, $skipping,
                                          $tmplvars, $binding, @reslist );
                }
            }

            next;
        }

        if ( $t->{TOKEN} eq 'INCLUDE' ) {
            my $fname = $self->Eval( $t->{EXPR}, $f, $errs, $skipping,
                                     $tmplvars, @reslist );

            my $inc_file = AbsPath->coerce($fname);
            if ( !$inc_file->is_file ) {
                push @{$errs}, "Failed to read $inc_file at $f:" . $t->{LINE};
                next;
            }

            my $incdata = $inc_file->slurp;
            if ( !defined $incdata ) {
                push @{$errs}, "Failed to read $inc_file at $f:" . $t->{LINE};
                next;
            }

            $incdata =
                $self->Transform( $incdata, $fname, $skipping, @reslist );
            if ( !defined $incdata || $@ ) {
                push @{$errs},$@;
                next;
            }

            $data .= $incdata;
            next;
        }
    
        if ( $t->{TOKEN} eq 'SKIP' ) {
            if (!$skipping) {
                $data .= $self->Eval( $t->{BODY}, $f, $errs, $skipping,
                                      $tmplvars, @reslist );
            }

            next;
        }
    
        if ( $t->{TOKEN} eq 'COMMENT' ) {
            next;
        }

    }

    return $data;
}

#######################################################################
sub Parse {
#######################################################################

# Parse token list into parse tree
#
# Input is:
#  Ref to token list as generated by Scan
#  (tokens are removed from here as parsed)
#  Filename (for error messages)
#  Optional pointer to error message list
#
# Output is:
#  Parse tree
#  Terminator token
#  Ref to error list

    my ( $self, $tokens, $f, $errs ) = @_;
    $errs //= [];

    my $newtokens = [];
  
    while (@{$tokens}) {
    
        my $t = shift @{$tokens};
        my $type = $t->{TOKEN};
        if ( !defined $type ) {
            $type = q{};
        }
    
        if ( $type eq 'TEXT' ) {
            push @{$newtokens}, $t;
            next;
        }
    
        if ( $type eq 'END'     || $type eq 'ELSE' ||
             $type eq 'ENDSKIP' || $type eq 'ENDCOMMENT' ) {
            return( $newtokens, $t, $errs );
        }

        if ( $type eq 'IF' || $type eq 'IFDEF' ) {

            my ( $body, $term, $errs ) = $self->Parse( $tokens, $f, $errs );
            $t->{BODY} = $body;

            if ( $term->{TOKEN} eq 'ELSE' ) {
                ( $body, $term, $errs ) = $self->Parse( $tokens, $f, $errs );
                $t->{ELSE} = $body;
            }

            if ( !defined $term->{TOKEN} || $term->{TOKEN} ne 'END' )  {
                push @{$errs},
                "missing END for " . $type . " statement at $f:" . $t->{LINE};
                next;
            }

            ( $body, $term, $errs ) = $self->Parse( $t->{EXPR}, $f, $errs );
            $t->{EXPR} = $body;

        } elsif ( $type eq 'FOR' ) {

            my ( $body, $term, $errs ) = $self->Parse( $tokens, $f, $errs );
            $t->{BODY} = $body;

            if ( !defined $term->{TOKEN} || $term->{TOKEN} ne 'END' )  {
                push @{$errs},
                "missing END for FOR statement at $f:" . $t->{LINE};
                next;
            }

            ( $body, $term, $errs ) = $self->Parse( $t->{EXPR}, $f, $errs );
            $t->{EXPR} = $body;

        } elsif ( $type eq 'COMMENT' ) {

            my ( $body, $term, $errs ) = $self->Parse( $tokens, $f, $errs );
            $t->{BODY} = $body;

            if ( !defined $term->{TOKEN} || $term->{TOKEN} ne 'ENDCOMMENT' )  {
                push @{$errs},
                "missing $LEFT*/$RIGHT for $LEFT*/$RIGHT at $f:" . $t->{LINE};
                next;
            }

        } elsif ( $type eq 'SKIP' ) {

            my ( $body, $term, $errs ) = $self->Parse( $tokens, $f, $errs );
            $t->{BODY} = $body;

            if ( !defined $term->{TOKEN} || $term->{TOKEN} ne 'ENDSKIP' )  {
                push @{$errs},
                "missing ENDSKIP for SKIP statement at $f:" . $t->{LINE};
                next;
            }
        }

        push @{$newtokens}, $t;
    }

    return( $newtokens, undef, $errs );
}

#######################################################################
sub Scan {
#######################################################################

# Scan template data into token list
#
# Input is:
#  Template data
#  Template filename (for error messages)
#  Optional array ref to append error messages
#  Optional starting line number
#
# Output is:
#  Ref to list of tokens
#  Remainder of unscanned data
#  Terminator symbol (undef = EOF)
#  New line number
#  Ref to error message list

    my ( $self, $data, $f, $errs, $line ) = @_;
    $errs //= [];
    $line //= 1;

    my $tokens = [];

    $self->logger->trace("$line: Scan\n$data\n------");

    while ( $data =~ m/^(.*?)((?:\Q$LEFT\E)|(?:\Q$RIGHT\E))(.*)$/so ) {
        my ( $text, $br, $rest ) = ( $1, $2, $3 );

        if ( defined $text && length $text > 0 ) {
            $self->logger->trace("$line: >> TEXT ($text)");

            push @{$tokens}, { TOKEN => 'TEXT', LINE => $line, DATA => $text };

            my $t = $text;
            $t =~ s/.//g;
            $line += length $t;

            $self->logger->trace("$line: << TEXT");
        }
    
        if ( $br =~ m/^\Q$RIGHT\E$/ ) {
            return ( $tokens, $rest, $br, $line, $errs ) ;
        }

        if ( $rest =~ m/^\s*\\\s*\Q$RIGHT\E\s*(.*)$/s ) {
            $data = $1;

        } elsif ( $rest =~ m/^\s*if\s*:\s*(.*)$/s ) {
            $self->logger->trace("$line: >> IF");

            my ( $expr, $more, $term, $xline, $errs ) =
                $self->Scan( $1, $f, $errs, $line );
            push @{$tokens}, { TOKEN => 'IF', LINE => $line, EXPR => $expr };

            $self->logger->trace("$xline: << IF");

            if ( $term !~ m/^\Q$RIGHT\E$/ ) {
                push @{$errs}, "missing '$RIGHT' for IF statement at $f:$line";
            }

            $data = $more;
            $line = $xline;

        } elsif ( $rest =~ m/^\s*ifdef\s*:\s*(.*)$/s ) {
            $self->logger->trace("$line: >> IFDEF");

            my ( $expr, $more, $term, $xline, $errs) =
                $self->Scan( $1, $f, $errs, $line );
            push @{$tokens}, { TOKEN => 'IFDEF', LINE => $line, EXPR => $expr };

            $self->logger->trace("$xline: << IFDEF");

            if ( $term !~ m/^\Q$RIGHT\E$/ ) {
                push @{$errs}, "missing '$RIGHT' for IFDEF statement at $f:$line";
            }

            $data = $more;
            $line = $xline;

        } elsif ( $rest =~ m/^\s*perl\s*:\s*(.*)$/s ) {
            $self->logger->trace("$line: >> PERL");

            my ( $expr, $more, $term, $xline, $errs ) =
                $self->Scan( $1, $f, $errs, $line );
            push @{$tokens}, { TOKEN => 'PERL', LINE => $line, EXPR => $expr };

            $self->logger->trace("$xline: << PERL");

            if ( $term !~ m/^\Q$RIGHT\E$/ ) {
                push @{$errs}, "missing '$RIGHT' for PERL statement at $f:$line";
            }

            $data = $more;
            $line = $xline;

        } elsif ( $rest =~ m/^\s*shell\s*:\s*(.*)$/s ) {
            $self->logger->trace("$line: >> SHELL");

            my ( $expr, $more, $term, $xline, $errs ) =
                $self->Scan( $1, $f, $errs, $line );
            push @{$tokens}, { TOKEN => 'SHELL', LINE => $line, EXPR => $expr };

            $self->logger->trace("$xline: << SHELL");

            if ( $term !~ m/^\Q$RIGHT\E$/ ) {
                push @{$errs}, "missing '$RIGHT' for SHELL statement at $f:$line";
            }

            $data = $more;
            $line = $xline;

        } elsif ( $rest =~ m/^\s*for\s*:\s*([^ \t=]+)\s*=\s*(.*)$/s ) {
            $self->logger->trace("$line: >> FOR");

            my $var = $1;
            my( $expr, $more, $term, $xline, $errs ) =
                $self->Scan( $2, $f, $errs, $line );
            push @{$tokens}, { TOKEN => 'FOR', VAR  => $var, 
                               EXPR  => $expr, LINE => $line };

            $self->logger->trace("$xline: << FOR");

            if ( $term !~ m/^\Q$RIGHT\E$/ ) {
                push @{$errs}, "missing '$RIGHT' for FOR statement at $f:$line";
            }

            $data = $more;
            $line = $xline;

        } elsif ( $rest =~ m/^\s*set\s*:\s*(\S+)\s*=\s*(.*)$/s ) {
            $self->logger->trace("$line: >> SET");

            my $var = $1;
            my( $expr, $more, $term, $xline, $errs ) =
                $self->Scan( $2, $f, $errs, $line );
            push @{$tokens}, { TOKEN => 'SET', VAR  => $var, 
                               EXPR  => $expr, LINE => $line };

            $self->logger->trace("$xline: << SET");

            if ( $term !~ m/^\Q$RIGHT\E$/ ) {
                push @{$errs}, "missing '$RIGHT' for SET statement at $f:$line";
            }

            $data = $more;
            $line = $xline;

        } elsif ( $rest =~ m/^\s*include\s*:\s*(.*)$/s ) {
            $self->logger->trace("$line: >> INCLUDE");

            my ( $expr, $more, $term, $xline, $errs ) =
                $self->Scan( $1, $f, $errs, $line );
            push @{$tokens}, { TOKEN => 'INCLUDE', EXPR => $expr,
                               LINE  => $line };

            $self->logger->trace("$xline: << INCLUDE");
            if ( $term !~ m/^\Q$RIGHT\E$/ ) {
                push @{$errs}, "missing '$RIGHT' for INCLUDE statement at $f:$line";
            }

            $data = $more;
            $line = $xline;

        } elsif ( $rest =~ m/^\s*\{\s*\Q$RIGHT\E(.*)$/s ) {
            $data = $1;
            push @{$tokens}, { TOKEN => 'SKIP', LINE => $line };

            $self->logger->trace("$line: SKIP");

        } elsif ( $rest =~ m/^\s*\}\s*\Q$RIGHT\E(.*)$/s ) {
            $data = $1;
            push @{$tokens}, { TOKEN => 'ENDSKIP', LINE => $line };

            $self->logger->trace("$line: ENDSKIP");

        } elsif ( $rest =~ m/^\s*\/\*\s*\Q$RIGHT\E(.*)$/s ) {
            $data = $1;
            push @{$tokens}, { TOKEN => 'COMMENT', LINE => $line };

            $self->logger->trace("$line: COMMENT");

        } elsif ( $rest =~ m/^\s*\*\/\s*\Q$RIGHT\E(.*)$/s ) {
            $data = $1;
            push @{$tokens}, { TOKEN => 'ENDCOMMENT', LINE => $line };

            $self->logger->trace("$line: ENDCOMMENT");

        } elsif ( $rest =~ m/^\s*else\s*:\s*\Q$RIGHT\E(.*)$/s ) {
            $data = $1;
            push @{$tokens}, { TOKEN => 'ELSE', LINE => $line };

            $self->logger->trace("$line: ELSE");

        } elsif ( $rest =~ m/^\s*end\s*:\s*\Q$RIGHT\E(.*)$/s ) {
            $data = $1;
            push @{$tokens}, { TOKEN => 'END', LINE => $line };

            $self->logger->trace("$line: END");

        } else {
            $self->logger->trace("$line: >> REF");

            my ( $expr, $more, $term, $xline, $errs ) =
                $self->Scan( $rest, $f, $errs, $line );
            push @{$tokens}, { TOKEN => 'REF', EXPR => $expr, LINE => $line };

            $self->logger->trace("$xline: << REF");

            if ( $term !~ m/^\Q$RIGHT\E$/ ) {
                push @{$errs}, "missing '$RIGHT' at $f:$line";
            }

            $data = $more;
            $line = $xline;
        }
    }

    if ($data) {
        push @{$tokens}, { TOKEN => 'TEXT', DATA => $data, LINE => $line };
    }

    $self->logger->trace("$line: TEXT");
    map { ++$line } split /\n/,$data;

    return ( $tokens, q{}, undef, $line, $errs );
}

1;
