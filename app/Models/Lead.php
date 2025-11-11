<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Lead extends Model
{
    protected $fillable = [
        'name', 'email', 'phone', 'company', 'notes', 'status', 'converted_at'
    ];

    protected $casts = [
        'converted_at' => 'datetime',
    ];

    public function history()
    {
        return $this->hasMany(LeadHistory::class);
    }

    public function scopeLeads($query)
    {
        return $query->where('status', 'lead');
    }

    public function scopeClients($query)
    {
        return $query->where('status', 'client');
    }
}