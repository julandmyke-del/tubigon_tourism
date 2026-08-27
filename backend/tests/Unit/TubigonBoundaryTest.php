<?php

namespace Tests\Unit;

use App\Support\TubigonBoundary;
use Tests\TestCase;

class TubigonBoundaryTest extends TestCase
{
    public function test_it_accepts_the_tubigon_municipal_center(): void
    {
        $boundary = app(TubigonBoundary::class);

        $this->assertTrue($boundary->contains(9.9515287, 123.9618897));
    }

    public function test_it_accepts_a_tubigon_municipal_island_polygon(): void
    {
        $boundary = app(TubigonBoundary::class);

        $this->assertTrue($boundary->contains(9.9840, 123.9945));
    }

    public function test_it_rejects_coordinates_outside_tubigon(): void
    {
        $boundary = app(TubigonBoundary::class);

        $this->assertFalse($boundary->contains(9.6500, 123.8500));
    }
}
