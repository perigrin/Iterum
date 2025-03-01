use 5.40.0;

package Iterum::ECS;
our $VERSION = '0.01';    # Initial version

use experimental 'class';

my sub uuid() {

    # 16 random bytes (4 * 4)
    my $uuid = join '', map { pack( 'I', int( rand( 2**32 ) ) ) } ( 1 .. 4 );

    # current timestamp in ms
    my $timestamp = int( Time::HiRes::time() * 1000 );

    # timestamp
    substr( $uuid, 0, 1, chr( ( $timestamp >> 40 ) & 0xFF ) );
    substr( $uuid, 1, 1, chr( ( $timestamp >> 32 ) & 0xFF ) );
    substr( $uuid, 2, 1, chr( ( $timestamp >> 24 ) & 0xFF ) );
    substr( $uuid, 3, 1, chr( ( $timestamp >> 16 ) & 0xFF ) );
    substr( $uuid, 4, 1, chr( ( $timestamp >> 8 ) & 0xFF ) );
    substr( $uuid, 5, 1, chr( $timestamp & 0xFF ) );

    # version and variant
    substr( $uuid, 6, 1,
        chr( ( ord( substr( $uuid, 6, 1 ) ) & 0x0F ) | 0x70 ) );
    substr( $uuid, 8, 1,
        chr( ( ord( substr( $uuid, 8, 1 ) ) & 0x3F ) | 0x80 ) );

    return unpack( "H*", $uuid );
}

class Iterum::ECS {
    use DBI;
    use JSON::MaybeXS qw(encode_json decode_json);
    use Time::HiRes;

    field $dsn :param = 'dbi:SQLite:dbname=:memory:';
    field $dbh :param = DBI->connect(
        $dsn, '', '',
        {
            PrintError                       => 0,
            RaiseError                       => 1,
            AutoCommit                       => 1,
            sqlite_allow_multiple_statements => 1,
        }
    );

    field $schema_sql :param = <<~'END_SQL';
        CREATE TABLE IF NOT EXISTS assemblages (
            id TEXT PRIMARY KEY,
            label TEXT UNIQUE NOT NULL,
            description TEXT
        );
        CREATE TABLE IF NOT EXISTS assemblage_components (
            assemblage_id TEXT,
            component_id TEXT,
            PRIMARY KEY (assemblage_id, component_id)
        );
        CREATE TABLE IF NOT EXISTS components (
            id TEXT PRIMARY KEY,
            label TEXT UNIQUE NOT NULL,
            description TEXT
        );
        CREATE TABLE IF NOT EXISTS entities (
            id TEXT PRIMARY KEY,
            label TEXT
        );
        CREATE TABLE IF NOT EXISTS entity_components (
            entity_id TEXT,
            component_id TEXT,
            component_data JSON,
            PRIMARY KEY (entity_id, component_id)
        );
    END_SQL

    field @systems;

    ADJUST {
        $dbh->do($schema_sql) unless $dbh->tables > 2;
    }

    use constant NEW_ENTITY_SQL => <<~'END_SQL';
      INSERT OR IGNORE INTO entities (id, label) VALUES(?, ?)
    END_SQL

    method new_entity($label) {
        my $uuid = uuid();
        $dbh->prepare_cached(NEW_ENTITY_SQL)->execute( $uuid, $label );
        return $uuid;
    }

    use constant DESTROY_ENTITY_COMPONENTS_SQL => <<~'END_SQL';
      DELETE FROM entity_components WHERE entity_id = ?
    END_SQL

    use constant DESTROY_ENTITY_SQL => <<~'END_SQL';
      DELETE FROM entities WHERE id = ?
    END_SQL

    method destroy_entity($entity) {
        $dbh->prepare_cached(DESTROY_ENTITY_COMPONENTS_SQL)->execute($entity);
        $dbh->prepare_cached(DESTROY_ENTITY_SQL)->execute($entity);
    }

    use constant NEW_COMPONENT_TYPE_SQL => <<~'END_SQL';
      INSERT OR IGNORE INTO components (id, label, description)
      VALUES(?, ?, ?)
    END_SQL

    method new_component_type( $label, $description, $ ) {
        my $uuid = uuid();
        $dbh->prepare_cached(NEW_COMPONENT_TYPE_SQL)
          ->execute( $uuid, $label, $description );
        return $uuid;
    }

    use constant GET_ID_FOR_COMPONENT_TYPE_SQL => <<~'END_SQL';
        SELECT id FROM components WHERE label = ?
    END_SQL

    method get_id_for_component_type($type) {
        my $sth = $dbh->prepare_cached(GET_ID_FOR_COMPONENT_TYPE_SQL);
        return $dbh->selectcol_arrayref( $sth, {}, $type )->[0];
    }

    use constant ADD_COMPONENT_TO_ENTITY_SQL => <<~'END_SQL';
        INSERT INTO entity_components (entity_id, component_id, component_data)
        VALUES(?, ?, ?)
        ON CONFLICT
        DO UPDATE SET component_data = excluded.component_data
    END_SQL

    method add_component( $entity, $type, $data = {} ) {
        my $id = $self->get_id_for_component_type($type);
        $dbh->prepare_cached(ADD_COMPONENT_TO_ENTITY_SQL)
          ->execute( $entity, $id, encode_json($data) );
    }

    use constant COMPONENTS_FOR_ENTITY_SQL => <<~'END_SQL';
        SELECT ec.component_data 'data', c.label
        FROM entity_components ec
        INNER JOIN components c ON c.id = ec.component_id
    END_SQL

    my sub placeholders($data) {
        \join ',', map '?', 0 .. ( ref $data ? @$data - 1 : 0 );
    }

    method get_components( $entity, @types ) {
        my $WHERE = "WHERE entity_id in (${placeholders($entity)})";
        $WHERE .= " AND c.label in (${placeholders(\@types)})";
        my $sth = $dbh->prepare( COMPONENTS_FOR_ENTITY_SQL . $WHERE );
        $sth->execute( ref $entity ? @$entity : $entity, @types );
        my %components = map { $_->{label} => decode_json( $_->{data} ) }
          $sth->fetchall_arrayref( {} )->@*;
        return @components{@types};
    }

    use constant REMOVE_COMPONENT_FROM_ENTITY_SQL => <<~'END_SQL';
        DELETE FROM entity_components
        WHERE entity_id = ? AND component_id = ?
    END_SQL

    method remove_components( $entity, @types ) {
        for my $type (@types) {
            my $id = $self->get_id_for_component_type($type);
            $dbh->prepare_cached(REMOVE_COMPONENT_FROM_ENTITY_SQL)
              ->execute( $entity, $id );
        }
    }

    use constant ENTITIES_FOR_COMPONENTS_SQL => <<~'END_SQL';
        SELECT ec.entity_id
        FROM entity_components ec
        INNER JOIN components c ON c.id = ec.component_id
    END_SQL

    method entites_for_components(@types) {
        my $sql = join "\nINTERSECT\n",
          map { ENTITIES_FOR_COMPONENTS_SQL . " WHERE c.label = ?" } @types;
        my $sth = $dbh->prepare_cached($sql);
        return $dbh->selectcol_arrayref( $sth, {}, @types )->@*;
    }

    method add_system($system) { push @systems, $system; }

    method remove_system($system) {
        @systems = grep { $_ ne $system } @systems;
    }

    method update() {
        for my $system (@systems) {
            my @components = $system->components_required;
            my @e          = $self->entites_for_components(@components);
            $system->set_entities(@e);
            $system->update( [ $self->get_components( \@e, @components ) ] );
        }
    }
}

1;
