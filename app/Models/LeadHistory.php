<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class LeadHistory extends Model
{
    protected $table = 'lead_history';
    
    protected $fillable = [
        'lead_id', 'action', 'details'
    ];

    public function lead()
    {
        return $this->belongsTo(Lead::class);
    }
}
