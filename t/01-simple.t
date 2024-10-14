#!/bin/env perl
use 5.40.0;
use lib          qw(lib);
use experimental qw(class defer);

use Test::More;
defer { done_testing };

use ECS;

class System {
    field @entities;
    method entities            { @entities }
    method set_entities(@ids)  { @entities = @ids }
    method components_required { }
    method update($data)       { }
}

class Locator :isa(System) {
    method components_required { 'Position' }
}

class Damager :isa(System) {
    field $entities_seen_last_update = -1;
    method components_required { 'Health' }
}

class HealthBarRenderer :isa(System) {
    method components_required { qw(Position Health) }
}

my $ecs = ECS->new();

class Destroyer :isa(System) {
    method components_required { 'Health' }

    method update ($) {
        $ecs->destroy_entity($_) for $self->entities;
    }
}

{
    $ecs->new_component_type( 'Position',
        'location on the map' => { x => 0, y => 0 } );
    $ecs->new_component_type( 'Health',
        'current health' => { max => 0, current => 0 } );

    my $e1 = $ecs->new_entity('E1');
    my $p1 = { x => 5, y => 5 };
    $ecs->add_component( $e1, 'Position', $p1 );

    my $gotP = $ecs->get_components( $e1, 'Position' );
    ok $gotP->{x} == 5 && $gotP->{y} == 5, 'component retrieval';
    $ecs->remove_components( $e1, 'Position' );
    ok !$ecs->get_components( $e1, 'Position' ), 'component deletion';

    my $locator = Locator->new();
    $ecs->add_system($locator);
    $ecs->update();
    is $locator->entities(), 0, "system doesn't track w/o match";

    $ecs->add_component( $e1, 'Position', $p1 );
    $ecs->update();
    is $locator->entities(), 1, "system does track w/ match";

    $ecs->remove_components( $e1, 'Position' );
    $ecs->update();
    is $locator->entities(), 0, "system removes tracking w/o match";

    my $h1 = { max => 10, current => 10 };
    $ecs->add_component( $e1, 'Position', $p1 );
    $ecs->add_component( $e1, 'Health',   $h1 );
    $ecs->update();

    is $locator->entities(), 1, "system does track w/ superset";

    my $damager = Damager->new();
    $ecs->add_system($damager);
    my $healthBarRenderer = HealthBarRenderer->new();
    $ecs->add_system($healthBarRenderer);
    my $e2 = $ecs->new_entity('E2');
    my $h2 = { max => 2, current => 2 };
    $ecs->add_component( $e2, Health => $h2 );

    $ecs->update();
    is $locator->entities(),           1, 'Locator tracking 1 entity';
    is $damager->entities(),           2, 'Damager tracking 2 entities';
    is $healthBarRenderer->entities(), 1, 'HealthBarRenderer tracking 1 entity';

    $ecs->remove_system($locator);
    $ecs->remove_system($damager);
    $ecs->remove_system($healthBarRenderer);

    my $destroyer = Destroyer->new();
    $ecs->add_system($destroyer);
    $ecs->add_system($locator);
    $ecs->add_system($damager);
    $ecs->add_system($healthBarRenderer);
    $ecs->update();

    is $locator->entities(),           0, 'locator: entities gone';
    is $damager->entities(),           0, 'damager: entities gone';
    is $healthBarRenderer->entities(), 0, 'healthBarRenderer: entities gone';
}

