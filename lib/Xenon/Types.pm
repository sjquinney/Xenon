package Xenon::Types; # -*- perl -*-
use strict;
use warnings;

use v5.10;

use Type::Library
    -base,
    -declare => qw(UID GID UnixMode
                   XenonResource XenonBackupStyle XenonURI
                   XenonFileManager XenonFileManagerList
                   XenonRegistry
                   XenonEnvHandler XenonEnvHandlerList
                   XenonAttributeManager XenonAttributeManagerList
                   XenonContentDecoder XenonContentDecoderList);

use Type::Utils -all;
use Types::Standard qw(ArrayRef HashRef Int ScalarRef Str Value);
use Types::Common::Numeric qw(PositiveOrZeroInt);

use Xenon::TypeUtils ();

class_type XenonURI, { class => 'URI' };
coerce XenonURI,
    from Str, via { require URI; URI->new($_) };

role_type XenonRegistry, { role => 'Xenon::Role::Registry' };

role_type XenonResource, { role => 'Xenon::Role::Resource' };

coerce XenonResource,
    from ScalarRef, via {
        require Xenon::Resource::Inline;
        Xenon::Resource::Inline->new( source => ${$_} );
    },
    from Str, via {
        if ( m{^/} ) {
            require Xenon::Resource::File;
            Xenon::Resource::File->new( source => $_ );
        } else {
            require Xenon::Resource::URI;
            Xenon::Resource::URI->new( source => $_ );
        }
};

role_type XenonEnvHandler, { role => 'Xenon::Role::EnvHandler' };

coerce XenonEnvHandler,
    from Str, via {
        my ( $modname, $modargs ) = split /\s*:\s*/, $_, 2;
        my $mod =
            Xenon::TypeUtils::load_role_module( $modname, 'Xenon::Env' );
        if ( defined $modargs ) {
            $mod->new_from_json(\$modargs);
        } else {
            $mod->new();
        }
    },
    from ArrayRef, via {
        my ( $modname, @modargs ) = @{$_};
        my $mod =
            Xenon::TypeUtils::load_role_module( $modname, 'Xenon::Env' );
        $mod->new(@modargs);
};

declare XenonEnvHandlerList,
    as ArrayRef[XenonEnvHandler],
    where { ArrayRef->check($_) &&
                !grep { !is_XenonEnvHandler($_) } @{$_} },
    message { 'Invalid list of environment managers' };

coerce XenonEnvHandlerList,
    from ArrayRef, via { [ map { to_XenonEnvHandler($_) } @{$_} ] },
    from Str, via { [ map { to_XenonEnvHandler($_) } split /\s*\|\s*/, $_ ] };

role_type XenonAttributeManager, { role => 'Xenon::Role::AttributeManager' };

coerce XenonAttributeManager,
    from Str, via {
        my ( $modname, $modargs ) = split /\s*:\s*/, $_, 2;
        my $mod =
            Xenon::TypeUtils::load_role_module( $modname, 'Xenon::Attributes' );
        if ( defined $modargs ) {
            $mod->new_from_json(\$modargs);
        } else {
            $mod->new();
        }
    },
    from ArrayRef, via {
        my ( $modname, @modargs ) = @{$_};
        my $mod =
            Xenon::TypeUtils::load_role_module( $modname, 'Xenon::Attributes' );
        $mod->new(@modargs);
};

declare XenonAttributeManagerList,
    as ArrayRef[XenonAttributeManager],
    where { ArrayRef->check($_) &&
                !grep { !is_XenonAttributeManager($_) } @{$_} },
    message { 'Invalid list of attribute managers' };

coerce XenonAttributeManagerList,
    from ArrayRef, via { [ map { to_XenonAttributeManager($_) } @{$_} ] },
    from Str, via { [ map { to_XenonAttributeManager($_) } split /\s*\|\s*/, $_ ] };

role_type XenonContentDecoder, { role => 'Xenon::Role::ContentDecoder' };

coerce XenonContentDecoder,
    from Str, via {
        my ( $modname, $modargs ) = split /\s*:\s*/, $_, 2;
        my $mod =
            Xenon::TypeUtils::load_role_module( $modname, 'Xenon::Encoding' );
        if ( defined $modargs ) {
            $mod->new_from_json(\$modargs);
        } else {
            $mod->new();
        }
    },
    from ArrayRef, via {
        my ( $modname, @modargs ) = @{$_};
        my $mod =
            Xenon::TypeUtils::load_role_module( $modname, 'Xenon::Encoding' );
        $mod->new(@modargs);
};

declare XenonContentDecoderList,
    as ArrayRef[XenonContentDecoder],
    where { ArrayRef->check($_) &&
                !grep { !is_XenonContentDecoder($_) } @{$_} },
    message { 'Invalid list of content decoders' };

coerce XenonContentDecoderList,
    from ArrayRef, via { [ map { to_XenonContentDecoder($_) } @{$_} ] },
    from Str, via { [ map { to_XenonContentDecoder($_) } split /\s*\|\s*/, $_ ] };

role_type XenonFileManager, { role => 'Xenon::Role::FileManager' };

coerce XenonFileManager, 
    from HashRef, via {
        my $type = delete $_->{type};
        if (defined $type) {
            my $fm = Xenon::TypeUtils::load_role_module( $type, 'Xenon::File' );
            $fm->new($_);
        }
};

declare XenonFileManagerList,
    as ArrayRef[XenonFileManager],
    where { ArrayRef->check($_) &&
            !grep { !XenonFileManager->check($_) } @{$_} },
    message { 'Invalid list of files' };

coerce XenonFileManagerList,
    from ArrayRef, via {
        [ map { to_XenonFileManager($_) } @{$_} ]
};

enum XenonBackupStyle, ['tilde','none','epochtime'];

declare UnixMode,
    as PositiveOrZeroInt,
    where   { !m/^0/ }, # forces coercion via oct()
    message { "$_ is not a valid unix file mode" };

coerce UnixMode,
    from Value, via { /^0\d+$/ ? oct $_ : $_ };

declare UID,
    as PositiveOrZeroInt,
    message { "$_ is not a valid UID" };

coerce UID,
    from Str, via { scalar getpwnam($_) };

declare GID,
    as PositiveOrZeroInt,
    message { "$_ is not a valid GID" };

coerce GID,
    from Str, via { scalar getgrnam($_) };

 __PACKAGE__->meta->make_immutable;

1;
