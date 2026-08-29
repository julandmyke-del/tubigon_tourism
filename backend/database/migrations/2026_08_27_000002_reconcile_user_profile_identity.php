<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('users') || ! Schema::hasTable('profiles')) {
            return;
        }

        DB::transaction(function (): void {
            DB::table('users')
                ->select([
                    'id',
                    'name',
                    'email',
                    'role_id',
                    'avatar_url',
                    'phone',
                    'bio',
                    'language',
                    'is_verified',
                    'created_at',
                    'updated_at',
                    'deleted_at',
                ])
                ->orderBy('id')
                ->chunk(100, function ($users): void {
                    foreach ($users as $user) {
                        DB::table('profiles')->insertOrIgnore([
                            'id' => $user->id,
                            'name' => $user->name,
                            'email' => $user->email,
                            'role_id' => $user->role_id,
                            'avatar_url' => $user->avatar_url,
                            'phone' => $user->phone,
                            'bio' => $user->bio,
                            'language' => $user->language ?: 'en',
                            'is_verified' => (bool) $user->is_verified,
                            'created_at' => $user->created_at,
                            'updated_at' => $user->updated_at,
                            'deleted_at' => $user->deleted_at,
                        ]);
                    }
                });
        });
    }

    public function down(): void
    {
        // Reconciled identity records may already own domain data and must not
        // be removed automatically during rollback.
    }
};
