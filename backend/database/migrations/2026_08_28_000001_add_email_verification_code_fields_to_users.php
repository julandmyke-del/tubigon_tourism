<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            if (! Schema::hasColumn('users', 'email_verified_at')) {
                $table->timestamp('email_verified_at')->nullable();
            }
            if (! Schema::hasColumn('users', 'email_verification_code_hash')) {
                $table->string('email_verification_code_hash')->nullable();
            }
            if (! Schema::hasColumn('users', 'email_verification_code_expires_at')) {
                $table->timestamp('email_verification_code_expires_at')->nullable();
            }
            if (! Schema::hasColumn('users', 'email_verification_attempts')) {
                $table->unsignedSmallInteger('email_verification_attempts')->default(0);
            }
        });

        // Preserve the meaning of accounts already verified by the existing
        // application without marking any unverified development account.
        DB::table('users')
            ->where('is_verified', true)
            ->whereNull('email_verified_at')
            ->update(['email_verified_at' => now()]);
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $columns = [
                'email_verified_at',
                'email_verification_code_hash',
                'email_verification_code_expires_at',
                'email_verification_attempts',
            ];

            foreach ($columns as $column) {
                if (Schema::hasColumn('users', $column)) {
                    $table->dropColumn($column);
                }
            }
        });
    }
};
