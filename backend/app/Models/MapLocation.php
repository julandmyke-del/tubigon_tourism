<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class MapLocation extends Model
{
    use HasUuids, SoftDeletes;

    protected $fillable = [
        'name',
        'slug',
        'seed_key',
        'description',
        'category_id',
        'subcategory_id',
        'entity_type',
        'entity_id',
        'address',
        'barangay',
        'municipality',
        'province',
        'latitude',
        'longitude',
        'coordinate_source_name',
        'coordinate_source_url',
        'coordinate_source_id',
        'coordinate_source_license',
        'coordinate_verified_at',
        'marker_icon',
        'image_url',
        'is_featured',
        'view_count',
        'verified',
        'published',
        'active',
        'created_by',
        'updated_by',
        'verified_by',
        'verified_at',
    ];

    protected $casts = [
        'latitude' => 'float',
        'longitude' => 'float',
        'is_featured' => 'boolean',
        'view_count' => 'integer',
        'verified' => 'boolean',
        'published' => 'boolean',
        'active' => 'boolean',
        'verified_at' => 'datetime',
        'coordinate_verified_at' => 'datetime',
    ];

    public function category()
    {
        return $this->belongsTo(MapLocationCategory::class, 'category_id');
    }

    public function subcategory()
    {
        return $this->belongsTo(MapLocationCategory::class, 'subcategory_id');
    }

    public function verifier()
    {
        return $this->belongsTo(User::class, 'verified_by');
    }

    public function linkedEntity(): TouristSpot|Msme|EmergencyContact|null
    {
        return match ($this->entity_type) {
            'tourist_spot' => TouristSpot::find($this->entity_id),
            'msme' => Msme::find($this->entity_id),
            'emergency_contact' => EmergencyContact::find($this->entity_id),
            default => null,
        };
    }

    /** One representation shared by Explore and Smart Map. */
    public function toPlaceArray(): array
    {
        $entity = $this->linkedEntity();
        $entityType = $this->entity_type;
        $sourceId = $entity?->id ?? $this->id;
        $images = $this->image_url ? [$this->image_url] : [];
        $rating = null;
        $reviewCount = null;
        $integerId = null;
        $operatingHours = null;
        $contact = null;
        $isBookable = false;
        $bookingEnabled = false;
        $bookingUnavailableReasonCode = null;
        $bookingUnavailableReason = null;
        $isFeatured = $this->is_featured;
        $isPreapproved = false;
        $aliases = [];
        $name = $this->name;
        $description = $this->description ?? '';
        $address = $this->address;
        $latitude = $this->latitude;
        $longitude = $this->longitude;

        if ($entity instanceof TouristSpot) {
            $name = $entity->name;
            $description = filled($entity->short_description)
                ? $entity->short_description
                : (filled($entity->description) ? $entity->description : $description);
            $address = filled($entity->address) ? $entity->address : $address;
            $images = $images ?: ($entity->images ?? []);
            $rating = $entity->average_rating;
            $reviewCount = $entity->review_count;
            $integerId = $entity->integer_id;
            $operatingHours = $entity->opening_hours;
            $isBookable = (bool) $entity->is_bookable;
            $bookingEnabled = (bool) $entity->booking_enabled;
            $bookingUnavailableReasonCode = $entity->booking_unavailable_reason_code;
            $bookingUnavailableReason = $entity->booking_unavailable_reason;
            $isFeatured = (bool) $entity->is_featured;
            $isPreapproved = (bool) $entity->is_preapproved;
            $aliases = $entity->aliases ?? [];
        } elseif ($entity instanceof Msme) {
            $name = $entity->name;
            $description = filled($entity->description) ? $entity->description : $description;
            $address = filled($entity->address) ? $entity->address : $address;
            $rating = $entity->rating;
            $reviewCount = $entity->review_count;
            $integerId = $entity->integer_id;
            $operatingHours = $entity->business_hours;
            $contact = $entity->phone;
            $images = $images ?: ($entity->images ?? []);
            // A linked map-management record must not become a second source
            // of MSME coordinates. The business record remains authoritative.
            $latitude = $entity->latitude;
            $longitude = $entity->longitude;
        } elseif ($entity instanceof EmergencyContact) {
            // The managed facility remains the map/favorite/itinerary entity.
            // Contact details are public only after the independent emergency
            // contact verification workflow approves them.
            $sourceId = $this->id;
            if ($entity->is_active && $entity->is_verified) {
                $contact = $entity->phone;
                $operatingHours = $entity->operating_hours;
            }
        }

        $category = $this->category;
        $displayCategory = $this->subcategory ?? $category;
        $keys = array_values(array_unique(array_filter([
            $category?->slug,
            $this->subcategory?->slug,
            $entityType === 'tourist_spot' ? 'tourist-spots' : null,
            $entityType === 'msme' ? 'msmes' : null,
        ])));

        return [
            'id' => "map_location:{$this->id}",
            'map_location_id' => (string) $this->id,
            'source_id' => (string) $sourceId,
            'source_integer_id' => $integerId,
            'type' => $entity instanceof EmergencyContact ? 'map_location' : ($entityType ?: 'map_location'),
            'name' => $name,
            'category' => $displayCategory?->name ?? 'Important Place',
            'category_id' => $category?->id,
            'category_slug' => $displayCategory?->slug ?? 'important-places',
            'category_keys' => $keys,
            'category_icon' => $this->marker_icon ?: ($displayCategory?->icon ?? 'place'),
            'marker_color' => $displayCategory?->marker_color ?? '#F59E0B',
            'category_sort_order' => $displayCategory?->sort_order ?? 999,
            'subcategory' => $this->subcategory?->name,
            'description' => $description,
            'aliases' => $aliases,
            'address' => $address,
            'barangay' => $this->barangay,
            'municipality' => $this->municipality,
            'province' => $this->province,
            'latitude' => $latitude,
            'longitude' => $longitude,
            'coordinate_source' => $this->coordinate_source_name ? [
                'name' => $this->coordinate_source_name,
                'url' => $this->coordinate_source_url,
                'external_id' => $this->coordinate_source_id,
                'license' => $this->coordinate_source_license,
                'verified_at' => $this->coordinate_verified_at?->toISOString(),
            ] : null,
            'images' => $images,
            'rating' => $rating,
            'review_count' => $reviewCount,
            'operating_hours' => $operatingHours,
            'contact' => $contact,
            'emergency_contact_id' => $entity instanceof EmergencyContact ? (string) $entity->id : null,
            'is_featured' => $isFeatured,
            'is_preapproved' => $isPreapproved,
            'is_bookable' => $isBookable,
            'booking_enabled' => $bookingEnabled,
            'booking_unavailable_reason_code' => $bookingUnavailableReasonCode,
            'booking_unavailable_reason' => $bookingUnavailableReason,
            'view_count' => $this->view_count,
            'is_verified' => $this->verified,
            'is_published' => $this->published,
            'is_owned' => false,
            'created_at' => $this->created_at?->toISOString(),
        ];
    }
}
