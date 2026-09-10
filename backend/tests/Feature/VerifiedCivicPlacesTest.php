<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class VerifiedCivicPlacesTest extends TestCase
{
    use RefreshDatabase;

    public function test_verified_plaza_and_churches_are_published_with_coordinate_provenance(): void
    {
        $expected = [
            'Tubigon Town Plaza' => [9.9512209, 123.9620116, 'OpenStreetMap way 143346516'],
            'Saint Isidore the Farmer Parish Church' => [9.9502983, 123.9629650, 'OpenStreetMap way 943081282'],
            'Saint John of the Cross Parish Church' => [9.9208119, 123.9308790, 'OpenStreetMap way 661954412'],
        ];

        foreach ($expected as $name => [$latitude, $longitude, $sourceId]) {
            $this->assertDatabaseHas('map_locations', [
                'name' => $name,
                'latitude' => $latitude,
                'longitude' => $longitude,
                'coordinate_source_id' => $sourceId,
                'verified' => true,
                'published' => true,
                'active' => true,
            ]);
        }

        $places = collect($this->getJson('/api/v1/map/locations')
            ->assertOk()
            ->assertJsonPath('status', 'success')
            ->json('data'));

        foreach (array_keys($expected) as $name) {
            $place = $places->firstWhere('name', $name);
            $this->assertNotNull($place, "$name was missing from the public map feed.");
            $this->assertSame('OpenStreetMap contributors', $place['coordinate_source']['name']);
            $this->assertSame('ODbL 1.0', $place['coordinate_source']['license']);
        }
    }

    public function test_unverified_holy_cross_coordinates_are_not_invented(): void
    {
        $this->assertDatabaseMissing('map_locations', [
            'name' => 'Holy Cross Parish',
        ]);
    }
}
