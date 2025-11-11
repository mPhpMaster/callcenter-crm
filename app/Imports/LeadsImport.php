<?php

namespace App\Imports;

use App\Models\Lead;
use App\Models\LeadHistory;
use Maatwebsite\Excel\Concerns\ToModel;
use Maatwebsite\Excel\Concerns\WithHeadingRow;

class LeadsImport implements ToModel, WithHeadingRow
{
    public function model(array $row)
    {
        $lead = Lead::create([
            'name' => $row['name'] ?? '',
            'email' => $row['email'] ?? null,
            'phone' => $row['phone'] ?? null,
            'company' => $row['company'] ?? null,
            'notes' => $row['notes'] ?? null,
            'status' => 'lead'
        ]);

        LeadHistory::create([
            'lead_id' => $lead->id,
            'action' => 'Lead Imported',
            'details' => 'Imported from Excel'
        ]);

        return $lead;
    }
}
