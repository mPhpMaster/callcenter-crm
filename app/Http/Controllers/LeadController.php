<?php

namespace App\Http\Controllers;

use App\Models\Lead;
use App\Models\LeadHistory;
use Illuminate\Http\Request;
use Maatwebsite\Excel\Facades\Excel;
use App\Imports\LeadsImport;

class LeadController extends Controller
{
    public function index(Request $request)
    {
        $query = Lead::with('history')->leads();
        
        if ($request->has('search')) {
            $search = $request->search;
            $query->where(function($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                  ->orWhere('email', 'like', "%{$search}%")
                  ->orWhere('phone', 'like', "%{$search}%")
                  ->orWhere('company', 'like', "%{$search}%");
            });
        }

        return response()->json($query->latest()->get());
    }

    public function clients(Request $request)
    {
        $query = Lead::with('history')->clients();
        
        if ($request->has('search')) {
            $search = $request->search;
            $query->where(function($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                  ->orWhere('email', 'like', "%{$search}%")
                  ->orWhere('phone', 'like', "%{$search}%")
                  ->orWhere('company', 'like', "%{$search}%");
            });
        }

        return response()->json($query->latest()->get());
    }

    public function import(Request $request)
    {
        $request->validate([
            'file' => 'required|mimes:xlsx,xls,csv'
        ]);

        try {
            Excel::import(new LeadsImport, $request->file('file'));
            return response()->json(['message' => 'Leads imported successfully']);
        } catch (\Exception $e) {
            return response()->json(['error' => $e->getMessage()], 500);
        }
    }

    public function convert(Request $request, $id)
    {
        $request->validate([
            'note' => 'required|string'
        ]);

        $lead = Lead::findOrFail($id);
        $lead->status = 'client';
        $lead->converted_at = now();
        $lead->save();

        LeadHistory::create([
            'lead_id' => $lead->id,
            'action' => 'Converted to Client',
            'details' => $request->note
        ]);

        return response()->json([
            'message' => 'Lead converted to client successfully',
            'client' => $lead->load('history')
        ]);
    }

    public function addNote(Request $request, $id)
    {
        $request->validate([
            'note' => 'required|string'
        ]);

        $lead = Lead::findOrFail($id);

        LeadHistory::create([
            'lead_id' => $lead->id,
            'action' => 'Note Added',
            'details' => $request->note
        ]);

        return response()->json([
            'message' => 'Note added successfully',
            'lead' => $lead->load('history')
        ]);
    }

    public function show($id)
    {
        $lead = Lead::with('history')->findOrFail($id);
        return response()->json($lead);
    }
}
